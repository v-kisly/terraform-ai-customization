#!/bin/bash

#############################################################################
# Terraform Checker Script for Linux & macOS
# Runs configured quality tools for Terraform code from a YAML definition.
# Usage: ./terraform-checker.sh [terraform_directory]
# Compatible with: Linux, macOS
#############################################################################

set -o pipefail

CMD_SEP=$'\034'

# Detect macOS and handle differences
if [[ "$OSTYPE" == "darwin"* ]]; then
    if command -v gdate > /dev/null 2>&1; then
        DATE_CMD="gdate"
    else
        DATE_CMD="date"
    fi
else
    DATE_CMD="date"
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
TERRAFORM_DIR="."
REPORT_FILE=""
REPORT_BASENAME=""
ISSUES_FOUND=false
CONFIG_FILE=""
CONFIG_SOURCE=""
CONFIG_PARSER=""

# Tool configuration arrays (bash 3 compatible)
TOOL_KEYS=()
TOOL_ENABLED=()
TOOL_NAMES=()
TOOL_DESCRIPTIONS=()
TOOL_REQUIRES_DOCKER=()
TOOL_CONTINUE_ON_ERROR=()
TOOL_COMMANDS=()
TOOL_STATUSES=()
TOOL_OUTPUTS=()

trim() {
    local value="$1"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    printf '%s' "$value"
}

strip_quotes() {
    local value
    value=$(trim "$1")

    if [ ${#value} -ge 2 ] && [[ "$value" == \"*\" ]]; then
        value="${value:1:${#value}-2}"
    elif [ ${#value} -ge 2 ] && [[ "$value" == \'*\' ]]; then
        value="${value:1:${#value}-2}"
    fi

    printf '%s' "$value"
}

normalize_bool() {
    local value
    local default_value="$2"

    value=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
    case "$value" in
        true|yes|1|on)
            printf 'true'
            ;;
        false|no|0|off)
            printf 'false'
            ;;
        *)
            printf '%s' "$default_value"
            ;;
    esac
}

command_exists() {
    command -v "$1" > /dev/null 2>&1
}

append_tool() {
    TOOL_KEYS+=("$1")
    TOOL_ENABLED+=("true")
    TOOL_NAMES+=("$1")
    TOOL_DESCRIPTIONS+=("")
    TOOL_REQUIRES_DOCKER+=("false")
    TOOL_CONTINUE_ON_ERROR+=("false")
    TOOL_COMMANDS+=("")
    TOOL_STATUSES+=("pending")
    TOOL_OUTPUTS+=("")
}

append_tool_command() {
    local tool_index="$1"
    local command_text="$2"

    if [ -z "${TOOL_COMMANDS[$tool_index]}" ]; then
        TOOL_COMMANDS[$tool_index]="$command_text"
    else
        TOOL_COMMANDS[$tool_index]="${TOOL_COMMANDS[$tool_index]}${CMD_SEP}${command_text}"
    fi
}

append_tool_output() {
    local tool_index="$1"
    local text="$2"

    if [ -z "${TOOL_OUTPUTS[$tool_index]}" ]; then
        TOOL_OUTPUTS[$tool_index]="$text"
    else
        TOOL_OUTPUTS[$tool_index]="${TOOL_OUTPUTS[$tool_index]}
$text"
    fi
}

set_tool_property() {
    local tool_index="$1"
    local key="$2"
    local value="$3"

    case "$key" in
        enabled)
            TOOL_ENABLED[$tool_index]=$(normalize_bool "$value" "true")
            ;;
        name)
            TOOL_NAMES[$tool_index]=$(strip_quotes "$value")
            ;;
        description)
            TOOL_DESCRIPTIONS[$tool_index]=$(strip_quotes "$value")
            ;;
        requires_docker)
            TOOL_REQUIRES_DOCKER[$tool_index]=$(normalize_bool "$value" "false")
            ;;
        continue_on_error)
            TOOL_CONTINUE_ON_ERROR[$tool_index]=$(normalize_bool "$value" "false")
            ;;
    esac
}

load_config_with_yq() {
    local tool_key=""
    local tool_index=-1
    local tool_count=0
    local value=""
    local command_text=""

    CONFIG_PARSER="yq"
    REPORT_BASENAME=$(strip_quotes "$(yq eval '.settings.report_file // ""' "$CONFIG_FILE" 2>/dev/null)")

    while IFS= read -r tool_key; do
        [ -z "$tool_key" ] && continue
        append_tool "$tool_key"
        tool_index=$(( ${#TOOL_KEYS[@]} - 1 ))
        tool_count=$(( tool_count + 1 ))

        value=$(yq eval ".tools[\"$tool_key\"].enabled // true" "$CONFIG_FILE" 2>/dev/null)
        set_tool_property "$tool_index" "enabled" "$value"

        value=$(yq eval ".tools[\"$tool_key\"].name // \"$tool_key\"" "$CONFIG_FILE" 2>/dev/null)
        set_tool_property "$tool_index" "name" "$value"

        value=$(yq eval ".tools[\"$tool_key\"].description // \"\"" "$CONFIG_FILE" 2>/dev/null)
        set_tool_property "$tool_index" "description" "$value"

        value=$(yq eval ".tools[\"$tool_key\"].requires_docker // false" "$CONFIG_FILE" 2>/dev/null)
        set_tool_property "$tool_index" "requires_docker" "$value"

        value=$(yq eval ".tools[\"$tool_key\"].continue_on_error // false" "$CONFIG_FILE" 2>/dev/null)
        set_tool_property "$tool_index" "continue_on_error" "$value"

        while IFS= read -r command_text; do
            [ -z "$command_text" ] && continue
            append_tool_command "$tool_index" "$command_text"
        done < <(yq eval ".tools[\"$tool_key\"].commands[]?" "$CONFIG_FILE" 2>/dev/null)
    done < <(yq eval '.tools | to_entries | .[].key' "$CONFIG_FILE" 2>/dev/null)

    [ "$tool_count" -gt 0 ]
}

load_config_with_internal_parser() {
    local raw_line=""
    local line=""
    local trimmed_line=""
    local indent=0
    local leading_spaces=""
    local section=""
    local current_tool_index=-1
    local current_list=""
    local key=""
    local value=""

    CONFIG_PARSER="internal"

    while IFS= read -r raw_line || [ -n "$raw_line" ]; do
        line="${raw_line%$'\r'}"
        trimmed_line=$(trim "$line")

        if [ -z "$trimmed_line" ] || [[ "$trimmed_line" == \#* ]]; then
            continue
        fi

        leading_spaces="${line%%[^ ]*}"
        indent=${#leading_spaces}

        if [ "$indent" -eq 0 ]; then
            current_list=""
            current_tool_index=-1
            case "$trimmed_line" in
                settings:)
                    section="settings"
                    ;;
                tools:)
                    section="tools"
                    ;;
                *)
                    section=""
                    ;;
            esac
            continue
        fi

        if [ "$section" = "settings" ] && [ "$indent" -eq 2 ]; then
            if [[ "$trimmed_line" =~ ^([A-Za-z0-9_-]+):[[:space:]]*(.*)$ ]]; then
                key="${BASH_REMATCH[1]}"
                value=$(strip_quotes "${BASH_REMATCH[2]}")
                case "$key" in
                    report_file)
                        REPORT_BASENAME="$value"
                        ;;
                esac
            fi
            continue
        fi

        if [ "$section" = "tools" ] && [ "$indent" -eq 2 ]; then
            if [[ "$trimmed_line" =~ ^([A-Za-z0-9_-]+):[[:space:]]*$ ]]; then
                append_tool "${BASH_REMATCH[1]}"
                current_tool_index=$(( ${#TOOL_KEYS[@]} - 1 ))
                current_list=""
            fi
            continue
        fi

        if [ "$section" = "tools" ] && [ "$indent" -eq 4 ] && [ "$current_tool_index" -ge 0 ]; then
            if [[ "$trimmed_line" =~ ^([A-Za-z0-9_-]+):[[:space:]]*(.*)$ ]]; then
                key="${BASH_REMATCH[1]}"
                value="${BASH_REMATCH[2]}"
                if [ -z "$value" ] && [ "$key" = "commands" ]; then
                    current_list="commands"
                else
                    current_list=""
                    set_tool_property "$current_tool_index" "$key" "$value"
                fi
            fi
            continue
        fi

        if [ "$section" = "tools" ] && [ "$indent" -eq 6 ] && [ "$current_tool_index" -ge 0 ] && [ "$current_list" = "commands" ]; then
            if [[ "$trimmed_line" =~ ^-[[:space:]]+(.*)$ ]]; then
                append_tool_command "$current_tool_index" "$(strip_quotes "${BASH_REMATCH[1]}")"
            fi
        fi
    done < "$CONFIG_FILE"

    [ "${#TOOL_KEYS[@]}" -gt 0 ]
}

find_config_file() {
    local script_dir=""

    script_dir="$(cd "$(dirname "$0")" && pwd)"
    if [ -f "${script_dir}/terraform-checker.yaml" ]; then
        CONFIG_FILE="${script_dir}/terraform-checker.yaml"
    elif [ -f "${script_dir}/terraform-checker.yml" ]; then
        CONFIG_FILE="${script_dir}/terraform-checker.yml"
    fi
}

reset_loaded_config() {
    TOOL_KEYS=()
    TOOL_ENABLED=()
    TOOL_NAMES=()
    TOOL_DESCRIPTIONS=()
    TOOL_REQUIRES_DOCKER=()
    TOOL_CONTINUE_ON_ERROR=()
    TOOL_COMMANDS=()
    TOOL_STATUSES=()
    TOOL_OUTPUTS=()
    REPORT_BASENAME=""
}

fail() {
    echo -e "${RED}$1${NC}" >&2
    exit 1
}

validate_loaded_config() {
    local tool_index=0
    local enabled_tools=0

    [ -n "$REPORT_BASENAME" ] || fail "Configuration error: settings.report_file is required in $CONFIG_SOURCE"
    [ "${#TOOL_KEYS[@]}" -gt 0 ] || fail "Configuration error: tools section is empty in $CONFIG_SOURCE"

    for tool_index in "${!TOOL_KEYS[@]}"; do
        if [ "${TOOL_ENABLED[$tool_index]}" = "true" ]; then
            enabled_tools=$(( enabled_tools + 1 ))
            [ -n "${TOOL_COMMANDS[$tool_index]}" ] || fail "Configuration error: tool '${TOOL_KEYS[$tool_index]}' is enabled but has no commands"
        fi
    done

    [ "$enabled_tools" -gt 0 ] || fail "Configuration error: no enabled tools found in $CONFIG_SOURCE"
}

load_config() {
    find_config_file

    [ -n "$CONFIG_FILE" ] && [ -f "$CONFIG_FILE" ] || fail "Configuration file not found next to the script. Expected terraform-checker.yaml or terraform-checker.yml in the script directory."

    CONFIG_SOURCE="$CONFIG_FILE"
    echo -e "${CYAN}[INFO] Loading configuration from: $CONFIG_FILE${NC}"

    reset_loaded_config
    if command_exists yq; then
        if ! load_config_with_yq; then
            echo -e "${YELLOW}[WARN] yq could not read the config. Falling back to the internal YAML parser.${NC}"
            reset_loaded_config
            load_config_with_internal_parser || fail "Configuration error: unable to parse YAML config with either yq or the internal parser"
        fi
    else
        load_config_with_internal_parser || fail "Configuration error: unable to parse YAML config with the internal parser"
    fi

    validate_loaded_config

    if [[ "$REPORT_BASENAME" = /* ]]; then
        REPORT_FILE="$REPORT_BASENAME"
    else
        REPORT_FILE="$TERRAFORM_DIR/$REPORT_BASENAME"
    fi
}

run_tool_command() {
    local command_text="$1"

    (
        cd "$TERRAFORM_DIR" || exit 1
        eval "$command_text"
    ) 2>&1
}

validate_target_directory() {
    if [ ! -d "$TERRAFORM_DIR" ]; then
        echo -e "${RED}Target directory does not exist: $TERRAFORM_DIR${NC}"
        exit 1
    fi

    if ! find "$TERRAFORM_DIR" -type f -name "*.tf" -print -quit | grep -q .; then
        echo -e "${RED}No Terraform files found in: $TERRAFORM_DIR${NC}"
        exit 1
    fi
}

initialize_report() {
    echo "# Terraform Quality Report" > "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "Generated: $($DATE_CMD)" >> "$REPORT_FILE"
    echo "Config source: $CONFIG_SOURCE" >> "$REPORT_FILE"
    echo "Config parser: $CONFIG_PARSER" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
}

write_report() {
    local tool_index=0

    echo "## Scan Summary" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"

    if [ "$ISSUES_FOUND" = true ]; then
        echo "**Status:** Issues found" >> "$REPORT_FILE"
    else
        echo "**Status:** No issues found" >> "$REPORT_FILE"
    fi

    echo "" >> "$REPORT_FILE"
    echo "| Tool | Status | Description |" >> "$REPORT_FILE"
    echo "|------|--------|-------------|" >> "$REPORT_FILE"
    for tool_index in "${!TOOL_KEYS[@]}"; do
        printf '| %s | %s | %s |\n' \
            "${TOOL_NAMES[$tool_index]}" \
            "${TOOL_STATUSES[$tool_index]}" \
            "${TOOL_DESCRIPTIONS[$tool_index]}" >> "$REPORT_FILE"
    done

    echo "" >> "$REPORT_FILE"
    echo "## Tool Outputs" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"

    for tool_index in "${!TOOL_KEYS[@]}"; do
        echo "### ${TOOL_NAMES[$tool_index]}" >> "$REPORT_FILE"
        if [ -n "${TOOL_DESCRIPTIONS[$tool_index]}" ]; then
            echo "${TOOL_DESCRIPTIONS[$tool_index]}" >> "$REPORT_FILE"
            echo "" >> "$REPORT_FILE"
        fi
        echo '```shell' >> "$REPORT_FILE"
        if [ -n "${TOOL_OUTPUTS[$tool_index]}" ]; then
            printf '%s\n' "${TOOL_OUTPUTS[$tool_index]}" >> "$REPORT_FILE"
        else
            echo "No output captured." >> "$REPORT_FILE"
        fi
        echo '```' >> "$REPORT_FILE"
        echo "" >> "$REPORT_FILE"
    done
}

execute_tools() {
    local enabled_tool_count=0
    local current_step=0
    local tool_index=0
    local tool_name=""
    local tool_failed=false
    local command_text=""
    local command_output=""
    local command_exit_code=0
    local old_ifs="$IFS"
    local command_list=()

    for tool_index in "${!TOOL_KEYS[@]}"; do
        if [ "${TOOL_ENABLED[$tool_index]}" = "true" ]; then
            enabled_tool_count=$(( enabled_tool_count + 1 ))
        fi
    done

    for tool_index in "${!TOOL_KEYS[@]}"; do
        tool_name="${TOOL_NAMES[$tool_index]}"

        if [ "${TOOL_ENABLED[$tool_index]}" != "true" ]; then
            TOOL_STATUSES[$tool_index]="skipped"
            TOOL_OUTPUTS[$tool_index]="Skipped (disabled in configuration)."
            continue
        fi

        current_step=$(( current_step + 1 ))
        echo -e "${YELLOW}[${current_step}/${enabled_tool_count}] Running ${tool_name}...${NC}"

        if [ "${TOOL_REQUIRES_DOCKER[$tool_index]}" = "true" ] && ! command_exists docker; then
            TOOL_STATUSES[$tool_index]="failed"
            TOOL_OUTPUTS[$tool_index]="Docker is not installed or not in PATH."
            ISSUES_FOUND=true
            echo -e "${RED}✗ ${tool_name} failed${NC}"
            echo ""
            continue
        fi

        if [ -z "${TOOL_COMMANDS[$tool_index]}" ]; then
            TOOL_STATUSES[$tool_index]="failed"
            TOOL_OUTPUTS[$tool_index]="Tool is enabled but no commands are configured."
            ISSUES_FOUND=true
            echo -e "${RED}✗ ${tool_name} failed${NC}"
            echo ""
            continue
        fi

        tool_failed=false
        TOOL_OUTPUTS[$tool_index]=""

        IFS="$CMD_SEP" read -r -a command_list <<< "${TOOL_COMMANDS[$tool_index]}"
        IFS="$old_ifs"

        for command_text in "${command_list[@]}"; do
            [ -z "$command_text" ] && continue

            append_tool_output "$tool_index" "\$ $command_text"
            command_output=$(run_tool_command "$command_text")
            command_exit_code=$?

            if [ -n "$command_output" ]; then
                append_tool_output "$tool_index" "$command_output"
            else
                append_tool_output "$tool_index" "(no output)"
            fi

            if [ "$command_exit_code" -ne 0 ]; then
                tool_failed=true
                append_tool_output "$tool_index" "Command failed with exit code $command_exit_code."
                if [ "${TOOL_CONTINUE_ON_ERROR[$tool_index]}" != "true" ]; then
                    break
                fi
            fi
        done

        if [ "$tool_failed" = true ]; then
            TOOL_STATUSES[$tool_index]="failed"
            ISSUES_FOUND=true
            echo -e "${RED}✗ ${tool_name} failed${NC}"
        else
            TOOL_STATUSES[$tool_index]="passed"
            echo -e "${GREEN}✓ ${tool_name} passed${NC}"
        fi
        echo ""
    done
}

# Parse arguments
if [ "$#" -gt 1 ]; then
    fail "Usage: ./terraform-checker.sh [terraform_directory]"
fi

if [ "$#" -eq 1 ]; then
    if [[ "$1" == -* ]]; then
        fail "Flags are not supported. Usage: ./terraform-checker.sh [terraform_directory]"
    fi
    TERRAFORM_DIR="$1"
fi

validate_target_directory
load_config
initialize_report

echo -e "${YELLOW}Starting Terraform quality checks for: $TERRAFORM_DIR${NC}"
echo ""

execute_tools
write_report

echo -e "${YELLOW}────────────────────────────────────────${NC}"
if [ "$ISSUES_FOUND" = true ]; then
    echo -e "${RED}Issues found during scan${NC}"
    echo -e "Report saved to: ${YELLOW}$REPORT_FILE${NC}"
    exit 1
else
    echo -e "${GREEN}All checks passed successfully!${NC}"
    echo -e "Report saved to: ${YELLOW}$REPORT_FILE${NC}"
    exit 0
fi
