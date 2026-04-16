#############################################################################
# Terraform Checker Script for Windows PowerShell
# Runs formatting, validation, linting, and security checks for Terraform code
# Usage: .\terraform-checker.ps1 [-TerraformDir .] [-SkipDocker] [-ConfigFile .]
#############################################################################

param(
    [string]$TerraformDir = ".",
    [switch]$SkipDocker = $false,
    [string]$ConfigFile = $null
)

$ErrorActionPreference = "Continue"
$script:InvocationPath = if ($PSCommandPath) { $PSCommandPath } else { $MyInvocation.MyCommand.Path }
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

#############################################################################
# Configuration Parsers
#############################################################################
function New-DefaultConfig {
    return @{
        CHECK_FMT       = $true
        CHECK_INIT      = $true
        CHECK_VALIDATE  = $true
        CHECK_TFLINT    = $true
        CHECK_TFSEC     = $true
        DOCKER_SKIP     = $false
        TFLINT_REGISTRY = "ghcr.io"
        TFLINT_IMAGE    = "terraform-linters/tflint"
        TFLINT_TAG      = "latest"
        TFSEC_REGISTRY  = "docker.io"
        TFSEC_IMAGE     = "aquasec/tfsec"
        TFSEC_TAG       = "latest"
    }
}

function Convert-ConfigValue {
    param([string]$Value)

    if ($null -eq $Value) {
        return $null
    }

    $trimmedValue = $Value.Trim()
    if ($trimmedValue.Length -ge 2) {
        $firstChar = $trimmedValue[0]
        $lastChar = $trimmedValue[$trimmedValue.Length - 1]
        if (($firstChar -eq '"' -and $lastChar -eq '"') -or ($firstChar -eq "'" -and $lastChar -eq "'")) {
            $trimmedValue = $trimmedValue.Substring(1, $trimmedValue.Length - 2)
        }
    }

    if ($trimmedValue -in @('true', 'false')) {
        return ($trimmedValue -eq 'true')
    }

    return $trimmedValue
}

function Read-IniConfig {
    param(
        [string]$Path,
        [hashtable]$Config
    )

    if (-not $Path -or -not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $Config
    }

    foreach ($line in (Get-Content -LiteralPath $Path)) {
        $line = $line.Trim()
        if ($line -match '^\s*#' -or $line -eq '') { continue }
        if ($line -match '^([A-Z_]+)=(.*)$') {
            $key = $Matches[1]
            $val = $Matches[2].Trim()
            if ($Config.ContainsKey($key)) {
                $Config[$key] = Convert-ConfigValue -Value $val
            }
        }
    }

    return $Config
}

function Read-Config {
    param([string]$Path)

    $config = New-DefaultConfig
    if (-not $Path -or -not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $config
    }

    return Read-IniConfig -Path $Path -Config $config
}

function Get-ScriptDirectory {
    if ($PSScriptRoot) {
        return $PSScriptRoot
    }

    if ($script:InvocationPath) {
        return (Split-Path -Parent $script:InvocationPath)
    }

    return (Get-Location).Path
}

function Find-ConfigFile {
    param(
        [string]$SpecifiedPath,
        [string]$TerraformDir
    )

    if ($SpecifiedPath) {
        if (Test-Path -LiteralPath $SpecifiedPath -PathType Leaf) {
            return (Resolve-Path -LiteralPath $SpecifiedPath).Path
        }
        return $SpecifiedPath
    }

    $scriptDir = Get-ScriptDirectory
    $searchDirectories = @($scriptDir, $TerraformDir, (Get-Location).Path)
    $configNames = @('terraform-checker.ini')
    $candidates = foreach ($directory in $searchDirectories) {
        foreach ($configName in $configNames) {
            Join-Path $directory $configName
        }
    }

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return $candidate
        }
    }

    return $null
}

function Write-Status {
    param(
        [string]$Message,
        [string]$Color = "White"
    )

    Write-Host $Message -ForegroundColor $Color
}

function Test-CommandAvailable {
    param([string]$CommandName)

    return $null -ne (Get-Command $CommandName -ErrorAction SilentlyContinue)
}

function Convert-OutputToText {
    param($Output)

    if ($null -eq $Output) {
        return ""
    }

    if ($Output -is [System.Array]) {
        return ($Output | ForEach-Object {
            if ($_ -is [System.Management.Automation.ErrorRecord]) {
                if ($_.TargetObject -is [string] -and -not [string]::IsNullOrWhiteSpace($_.TargetObject)) {
                    return [string]$_.TargetObject
                }

                if (-not [string]::IsNullOrWhiteSpace($_.Exception.Message)) {
                    return $_.Exception.Message
                }
            }

            return [string]$_
        }) -join "`n"
    }

    if ($Output -is [System.Management.Automation.ErrorRecord]) {
        if ($Output.TargetObject -is [string] -and -not [string]::IsNullOrWhiteSpace($Output.TargetObject)) {
            return [string]$Output.TargetObject
        }

        if (-not [string]::IsNullOrWhiteSpace($Output.Exception.Message)) {
            return $Output.Exception.Message
        }
    }

    return [string]$Output
}

function Add-Finding {
    param(
        [string]$Type,
        [string]$Output
    )

    $script:Findings += @{ Type = $Type; Output = $Output }
}

function Add-Limitation {
    param(
        [string]$Type,
        [string]$Output
    )

    $script:ExecutionLimitationsFound = $true
    Add-Finding -Type $Type -Output $Output
}

function Set-ToolOutput {
    param(
        [string]$Name,
        [string]$Value
    )

    Set-Variable -Name $Name -Value $Value -Scope Script
}

function Invoke-TerraformCommand {
    param(
        [string[]]$Arguments,
        [string]$ToolName,
        [string]$SuccessMessage,
        [string]$FailureMessage,
        [string]$OutputVariable,
        [string]$FindingType,
        [switch]$MarkIssuesFound
    )

    try {
        $output = & terraform @Arguments 2>&1
        $outputText = Convert-OutputToText $output

        if ($LASTEXITCODE -eq 0) {
            Write-Status $SuccessMessage "Green"
            if ([string]::IsNullOrWhiteSpace($outputText)) {
                $outputText = "$ToolName passed"
            }
            Set-ToolOutput -Name $OutputVariable -Value $outputText
            return $true
        }

        if ($MarkIssuesFound) {
            $script:IssuesFound = $true
        }

        Write-Status $FailureMessage "Red"
        if ([string]::IsNullOrWhiteSpace($outputText)) {
            $outputText = "$ToolName failed"
        }

        Add-Finding -Type $FindingType -Output $outputText
        Set-ToolOutput -Name $OutputVariable -Value $outputText
        return $false
    } catch {
        $script:IssuesFound = $true
        $message = "Error: $($_.Exception.Message)"
        Write-Status ("[ERROR] {0}: {1}" -f $ToolName, $_.Exception.Message) "Red"
        Add-Finding -Type $FindingType -Output $message
        Set-ToolOutput -Name $OutputVariable -Value $message
        return $false
    }
}

function Invoke-DockerTool {
    param(
        [string]$ToolName,
        [string[]]$InitArguments,
        [string[]]$RunArguments,
        [string]$SuccessMessage,
        [string]$FailureMessage,
        [string]$OutputVariable,
        [string]$FindingType
    )

    if ($Config.DOCKER_SKIP) {
        Write-Status ("[SKIP] {0} check skipped" -f $ToolName) "Yellow"
        Set-ToolOutput -Name $OutputVariable -Value ("{0} check skipped" -f $ToolName)
        return
    }

    if (-not (Test-CommandAvailable -CommandName "docker")) {
        $message = "Docker is not installed or not available in PATH."
        Write-Status ("[WARN] {0}: {1}" -f $ToolName, $message) "Yellow"
        Add-Limitation -Type $FindingType -Output $message
        Set-ToolOutput -Name $OutputVariable -Value $message
        return
    }

    try {
        $dockerCheck = & docker ps 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw (Convert-OutputToText $dockerCheck)
        }

        if ($InitArguments) {
            $null = & docker @InitArguments 2>&1
        }

        $toolOutput = & docker @RunArguments 2>&1
        $toolOutputText = Convert-OutputToText $toolOutput

        if ($LASTEXITCODE -eq 0) {
            Write-Status $SuccessMessage "Green"
            if ([string]::IsNullOrWhiteSpace($toolOutputText)) {
                $toolOutputText = ("{0} passed" -f $ToolName)
            }
            Set-ToolOutput -Name $OutputVariable -Value $toolOutputText
            return
        }

        $script:IssuesFound = $true
        Write-Status $FailureMessage "Red"
        if ([string]::IsNullOrWhiteSpace($toolOutputText)) {
            $toolOutputText = ("{0} failed" -f $ToolName)
        }

        Add-Finding -Type $FindingType -Output $toolOutputText
        Set-ToolOutput -Name $OutputVariable -Value $toolOutputText
    } catch {
        $message = $_.Exception.Message
        if ([string]::IsNullOrWhiteSpace($message)) {
            $message = "Docker daemon is not running."
        }

        Write-Status ("[WARN] {0}: {1}" -f $ToolName, $message) "Yellow"
        Add-Limitation -Type $FindingType -Output $message
        Set-ToolOutput -Name $OutputVariable -Value $message
    }
}

$Findings = @()
$IssuesFound = $false
$ExecutionLimitationsFound = $false
$FmtReportOutput = ""
$InitReportOutput = ""
$ValidateReportOutput = ""
$TflintReportOutput = ""
$TfsecReportOutput = ""

#############################################################################
# Load Configuration
#############################################################################
$ConfigPath = Find-ConfigFile -SpecifiedPath $ConfigFile -TerraformDir $TerraformDir
if ($ConfigPath) {
    Write-Status "[INFO] Loading configuration from: $ConfigPath" "Cyan"
}
$Config = Read-Config -Path $ConfigPath

# CLI parameter overrides config file
if ($SkipDocker) {
    $Config.DOCKER_SKIP = $true
}

$ResolvedTerraformDir = $null

if (Test-Path -LiteralPath $TerraformDir -PathType Container) {
    $ResolvedTerraformDir = (Resolve-Path -LiteralPath $TerraformDir).Path
}

$ReportDirectory = if ($ResolvedTerraformDir) { $ResolvedTerraformDir } else { $null }
$ReportFile = if ($ReportDirectory) { Join-Path $ReportDirectory "terraform-quality-report.md" } else { $null }

$ReportHeader = @(
    "# Terraform Quality Report",
    "",
    "Generated: $(Get-Date -Format 'o')",
    ""
)

Write-Status ("[INFO] Starting Terraform quality checks for: {0}" -f $TerraformDir) "Yellow"
Write-Host ""

if (-not $ResolvedTerraformDir) {
    $IssuesFound = $true
    $message = "Terraform directory not found: $TerraformDir"
    Write-Status ("[ERROR] {0}" -f $message) "Red"
    Add-Finding -Type "configuration" -Output $message
    $FmtReportOutput = $message
    $InitReportOutput = "Skipped because the Terraform directory does not exist."
    $ValidateReportOutput = "Skipped because the Terraform directory does not exist."
    $TflintReportOutput = "Skipped because the Terraform directory does not exist."
    $TfsecReportOutput = "Skipped because the Terraform directory does not exist."
} elseif (-not (Test-CommandAvailable -CommandName "terraform")) {
    $IssuesFound = $true
    $message = "Terraform CLI is not installed or not available in PATH."
    Write-Status ("[ERROR] {0}" -f $message) "Red"
    Add-Finding -Type "configuration" -Output $message
    $FmtReportOutput = $message
    $InitReportOutput = "Skipped because Terraform CLI is unavailable."
    $ValidateReportOutput = "Skipped because Terraform CLI is unavailable."
    $TflintReportOutput = "Skipped because Terraform CLI is unavailable."
    $TfsecReportOutput = "Skipped because Terraform CLI is unavailable."
} else {
    Write-Status "[1/5] Running terraform fmt check..." "Yellow"
    if ($Config.CHECK_FMT) {
        $null = Invoke-TerraformCommand `
            -Arguments @("-chdir=$ResolvedTerraformDir", "fmt", "-no-color", "-check", "-recursive") `
            -ToolName "terraform fmt" `
            -SuccessMessage "[OK] Formatting check passed" `
            -FailureMessage "[FAIL] Formatting issues found" `
            -OutputVariable "FmtReportOutput" `
            -FindingType "formatting" `
            -MarkIssuesFound
    } else {
        Write-Status "[SKIP] Formatting check skipped (disabled in config)" "Yellow"
        $FmtReportOutput = "Skipped (disabled in configuration)"
    }
    Write-Host ""

    Write-Status "[2/5] Initializing Terraform..." "Yellow"
    if ($Config.CHECK_INIT) {
        $initSucceeded = Invoke-TerraformCommand `
            -Arguments @("-chdir=$ResolvedTerraformDir", "init", "-no-color", "-backend=false", "-input=false") `
            -ToolName "terraform init" `
            -SuccessMessage "[OK] Terraform initialized" `
            -FailureMessage "[FAIL] Terraform init failed" `
            -OutputVariable "InitReportOutput" `
            -FindingType "init" `
            -MarkIssuesFound
    } else {
        Write-Status "[SKIP] Init skipped (disabled in config)" "Yellow"
        $InitReportOutput = "Skipped (disabled in configuration)"
        $initSucceeded = $false
    }
    Write-Host ""

    Write-Status "[3/5] Running terraform validate..." "Yellow"
    if ($Config.CHECK_VALIDATE) {
        if ($initSucceeded -or -not $Config.CHECK_INIT) {
            $null = Invoke-TerraformCommand `
                -Arguments @("-chdir=$ResolvedTerraformDir", "validate", "-no-color") `
                -ToolName "terraform validate" `
                -SuccessMessage "[OK] Validation passed" `
                -FailureMessage "[FAIL] Validation failed" `
                -OutputVariable "ValidateReportOutput" `
                -FindingType "validate" `
                -MarkIssuesFound
        } else {
            $IssuesFound = $true
            $ValidateReportOutput = "Skipped because terraform init failed."
            Add-Finding -Type "validate" -Output $ValidateReportOutput
            Write-Status "[FAIL] Validation skipped because terraform init failed" "Red"
        }
    } else {
        Write-Status "[SKIP] Validation skipped (disabled in config)" "Yellow"
        $ValidateReportOutput = "Skipped (disabled in configuration)"
    }
    Write-Host ""

    $dockerVolume = "{0}:/workspace" -f $ResolvedTerraformDir

    Write-Status "[4/5] Running TFLint..." "Yellow"
    if ($Config.CHECK_TFLINT) {
        $tflintImage = "{0}/{1}:{2}" -f $Config.TFLINT_REGISTRY, $Config.TFLINT_IMAGE, $Config.TFLINT_TAG
        $tflintInitArgs = @("run", "--rm", "-v", $dockerVolume, "-w", "/workspace", $tflintImage, "--init")
        $tflintRunArgs = @("run", "--rm", "-v", $dockerVolume, "-w", "/workspace", $tflintImage, "-f", "compact")

        Invoke-DockerTool `
            -ToolName "TFLint" `
            -InitArguments $tflintInitArgs `
            -RunArguments $tflintRunArgs `
            -SuccessMessage "[OK] TFLint passed" `
            -FailureMessage "[FAIL] TFLint issues found" `
            -OutputVariable "TflintReportOutput" `
            -FindingType "tflint"
    } else {
        Write-Status "[SKIP] TFLint skipped (disabled in config)" "Yellow"
        $TflintReportOutput = "Skipped (disabled in configuration)"
    }
    Write-Host ""

    Write-Status "[5/5] Running tfsec..." "Yellow"
    if ($Config.CHECK_TFSEC) {
        $tfsecImage = "{0}/{1}:{2}" -f $Config.TFSEC_REGISTRY, $Config.TFSEC_IMAGE, $Config.TFSEC_TAG
        $tfsecRunArgs = @("run", "--rm", "-v", $dockerVolume, $tfsecImage, "/workspace", "--format", "lovely", "--no-color")

        Invoke-DockerTool `
            -ToolName "tfsec" `
            -RunArguments $tfsecRunArgs `
            -SuccessMessage "[OK] tfsec passed" `
            -FailureMessage "[FAIL] tfsec issues found" `
            -OutputVariable "TfsecReportOutput" `
            -FindingType "tfsec"
    } else {
        Write-Status "[SKIP] tfsec skipped (disabled in config)" "Yellow"
        $TfsecReportOutput = "Skipped (disabled in configuration)"
    }
    Write-Host ""
}

$statusText = if ($IssuesFound) {
    "Issues found"
} elseif ($ExecutionLimitationsFound) {
    "Partial: some checks could not be executed"
} else {
    "No issues found"
}

$ReportContent = @(
    $ReportHeader + @(
    "## Scan Summary",
    "",
    "**Status:** $statusText",
    "",
    "## Tool Outputs",
    "",
    "### terraform fmt",
    "",
    '```shell',
    $FmtReportOutput,
    '```',
    "",
    "### terraform init",
    "",
    '```shell',
    $InitReportOutput,
    '```',
    "",
    "### terraform validate",
    "",
    '```shell',
    $ValidateReportOutput,
    '```',
    "",
    "### tflint",
    "",
    '```shell',
    $TflintReportOutput,
    '```',
    "",
    "### tfsec",
    "",
    '```shell',
    $TfsecReportOutput,
    '```',
    ""
    )
) -join "`n"

if ($ReportFile) {
    Set-Content -Path $ReportFile -Value $ReportContent -Encoding UTF8
}

Write-Host "----------------------------------------" -ForegroundColor Gray
if ($IssuesFound) {
    Write-Status "[FAIL] Issues found during scan" "Red"
    if ($ReportFile) {
        Write-Status ("Report saved to: {0}" -f $ReportFile) "Yellow"
    } else {
        Write-Status "[WARN] Report was not saved because the Terraform directory does not exist" "Yellow"
    }
    exit 1
}

if ($ExecutionLimitationsFound) {
    Write-Status "[WARN] Scan completed with execution limitations" "Yellow"
    if ($ReportFile) {
        Write-Status ("Report saved to: {0}" -f $ReportFile) "Yellow"
    } else {
        Write-Status "[WARN] Report was not saved because the Terraform directory does not exist" "Yellow"
    }
    exit 1
}

Write-Status "[OK] All checks passed successfully" "Green"
if ($ReportFile) {
    Write-Status ("Report saved to: {0}" -f $ReportFile) "Yellow"
}
exit 0
