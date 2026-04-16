#!/bin/bash

#############################################################################
# Terraform Checker Script for Linux & macOS
# Runs formatting, validation, linting, and security checks for Terraform code
# Usage: ./terraform-checker.sh [terraform_directory] [--skip-docker] [--config config.ini]
# Compatible with: Linux, macOS
#############################################################################

set -o pipefail

#############################################################################
# INI Configuration Parser (KEY=VALUE format)
#############################################################################
get_config() {
    local key="$1"
    local file="$2"
    local default="$3"
    local val
    val=$(grep "^${key}=" "$file" 2>/dev/null | tail -1 | cut -d'=' -f2- | tr -d '\r')
    echo "${val:-$default}"
}

# Detect macOS and handle differences
if [[ "$OSTYPE" == "darwin"* ]]; then
    IS_MACOS=true
    # macOS compatibility
    if ! command -v gdate &> /dev/null; then
        # Fallback to standard date if gdate not available
        DATE_CMD="date"
    else
        DATE_CMD="gdate"
    fi
else
    IS_MACOS=false
    DATE_CMD="date"
fi

# Configuration
TERRAFORM_DIR="."
REPORT_FILE=""
ISSUES_FOUND=false
SKIP_DOCKER=false
CONFIG_FILE=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --skip-docker)
            SKIP_DOCKER=true
            shift
            ;;
        --config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        -*)
            shift
            ;;
        *)
            TERRAFORM_DIR="$1"
            shift
            ;;
    esac
done

REPORT_FILE="$TERRAFORM_DIR/terraform-quality-report.md"

# Find config file if not specified
if [ -z "$CONFIG_FILE" ]; then
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    if [ -f "${SCRIPT_DIR}/terraform-checker.ini" ]; then
        CONFIG_FILE="${SCRIPT_DIR}/terraform-checker.ini"
    elif [ -f "${TERRAFORM_DIR}/terraform-checker.ini" ]; then
        CONFIG_FILE="${TERRAFORM_DIR}/terraform-checker.ini"
    fi
fi

# Load configuration values
if [ -n "$CONFIG_FILE" ] && [ -f "$CONFIG_FILE" ]; then
    echo -e "\033[36m[INFO] Loading configuration from: $CONFIG_FILE\033[0m"
    CHECK_FMT=$(get_config "CHECK_FMT" "$CONFIG_FILE" "true")
    CHECK_INIT=$(get_config "CHECK_INIT" "$CONFIG_FILE" "true")
    CHECK_VALIDATE=$(get_config "CHECK_VALIDATE" "$CONFIG_FILE" "true")
    CHECK_TFLINT=$(get_config "CHECK_TFLINT" "$CONFIG_FILE" "true")
    CHECK_TFSEC=$(get_config "CHECK_TFSEC" "$CONFIG_FILE" "true")
    TFLINT_REGISTRY=$(get_config "TFLINT_REGISTRY" "$CONFIG_FILE" "ghcr.io")
    TFLINT_IMAGE=$(get_config "TFLINT_IMAGE" "$CONFIG_FILE" "terraform-linters/tflint")
    TFLINT_TAG=$(get_config "TFLINT_TAG" "$CONFIG_FILE" "latest")
    TFSEC_REGISTRY=$(get_config "TFSEC_REGISTRY" "$CONFIG_FILE" "docker.io")
    TFSEC_IMAGE=$(get_config "TFSEC_IMAGE" "$CONFIG_FILE" "aquasec/tfsec")
    TFSEC_TAG=$(get_config "TFSEC_TAG" "$CONFIG_FILE" "latest")
    # CLI --skip-docker overrides config
    if [ "$SKIP_DOCKER" = false ]; then
        CONFIG_DOCKER_SKIP=$(get_config "DOCKER_SKIP" "$CONFIG_FILE" "false")
        [ "$CONFIG_DOCKER_SKIP" = "true" ] && SKIP_DOCKER=true
    fi
else
    # Use defaults
    CHECK_FMT="true"
    CHECK_INIT="true"
    CHECK_VALIDATE="true"
    CHECK_TFLINT="true"
    CHECK_TFSEC="true"
    TFLINT_REGISTRY="ghcr.io"
    TFLINT_IMAGE="terraform-linters/tflint"
    TFLINT_TAG="latest"
    TFSEC_REGISTRY="docker.io"
    TFSEC_IMAGE="aquasec/tfsec"
    TFSEC_TAG="latest"
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Initialize report
echo "# Terraform Quality Report" > "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "Generated: $($DATE_CMD)" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

echo -e "${YELLOW}Starting Terraform quality checks for: $TERRAFORM_DIR${NC}"
echo ""

# Array to store findings
declare -a FINDINGS

# Per-check outputs for markdown report
FMT_REPORT_OUTPUT=""
INIT_REPORT_OUTPUT=""
VALIDATE_REPORT_OUTPUT=""
TFLINT_REPORT_OUTPUT=""
TFSEC_REPORT_OUTPUT=""

#############################################################################
# 1. Terraform Format Check
#############################################################################
echo -e "${YELLOW}[1/5] Running terraform fmt check...${NC}"
if [ "$CHECK_FMT" = "true" ]; then
    FMT_OUTPUT=$(terraform -chdir="$TERRAFORM_DIR" fmt -no-color -check -recursive 2>&1)
    if [ $? -ne 0 ]; then
        ISSUES_FOUND=true
        echo -e "${RED}✗ Formatting issues found${NC}"
        FINDINGS+=("formatting" "$FMT_OUTPUT")
        FMT_REPORT_OUTPUT="$FMT_OUTPUT"
    else
        echo -e "${GREEN}✓ Formatting check passed${NC}"
        FMT_REPORT_OUTPUT="format check passed"
    fi
else
    echo -e "${YELLOW}⊘ Format check skipped (disabled in config)${NC}"
    FMT_REPORT_OUTPUT="Skipped (disabled in configuration)"
fi
echo ""

#############################################################################
# 2. Terraform Init
#############################################################################
echo -e "${YELLOW}[2/5] Initializing Terraform...${NC}"
INIT_SUCCESS=false
if [ "$CHECK_INIT" = "true" ]; then
    INIT_OUTPUT=$(terraform -chdir="$TERRAFORM_DIR" init -no-color -backend=false -input=false 2>&1)
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Terraform initialized${NC}"
        if [ -n "$INIT_OUTPUT" ]; then
            INIT_REPORT_OUTPUT="$INIT_OUTPUT"
        else
            INIT_REPORT_OUTPUT="init passed"
        fi
        INIT_SUCCESS=true
    else
        echo -e "${RED}✗ Terraform init failed${NC}"
        ISSUES_FOUND=true
        if [ -n "$INIT_OUTPUT" ]; then
            FINDINGS+=("init" "$INIT_OUTPUT")
            INIT_REPORT_OUTPUT="$INIT_OUTPUT"
        else
            FINDINGS+=("init" "Failed to initialize Terraform providers")
            INIT_REPORT_OUTPUT="Failed to initialize Terraform providers"
        fi
    fi
else
    echo -e "${YELLOW}⊘ Init skipped (disabled in config)${NC}"
    INIT_REPORT_OUTPUT="Skipped (disabled in configuration)"
    INIT_SUCCESS=true
fi
echo ""

#############################################################################
# 3. Terraform Validate
#############################################################################
echo -e "${YELLOW}[3/5] Running terraform validate...${NC}"
if [ "$CHECK_VALIDATE" = "true" ]; then
    if [ "$INIT_SUCCESS" = true ]; then
        VALIDATE_OUTPUT=$(terraform -chdir="$TERRAFORM_DIR" validate -no-color 2>&1)
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ Validation passed${NC}"
            if [ -n "$VALIDATE_OUTPUT" ]; then
                VALIDATE_REPORT_OUTPUT="$VALIDATE_OUTPUT"
            else
                VALIDATE_REPORT_OUTPUT="validation passed"
            fi
        else
            ISSUES_FOUND=true
            echo -e "${RED}✗ Validation failed${NC}"
            FINDINGS+=("validate" "$VALIDATE_OUTPUT")
            VALIDATE_REPORT_OUTPUT="$VALIDATE_OUTPUT"
        fi
    else
        ISSUES_FOUND=true
        VALIDATE_REPORT_OUTPUT="Skipped because terraform init failed."
        FINDINGS+=("validate" "$VALIDATE_REPORT_OUTPUT")
        echo -e "${RED}✗ Validation skipped${NC}"
    fi
else
    echo -e "${YELLOW}⊘ Validate check skipped (disabled in config)${NC}"
    VALIDATE_REPORT_OUTPUT="Skipped (disabled in configuration)"
fi
echo ""

#############################################################################
# 4. TFLint Check
#############################################################################
echo -e "${YELLOW}[4/5] Running TFLint...${NC}"
if [ "$CHECK_TFLINT" = "true" ]; then
    if [ "$SKIP_DOCKER" = false ]; then
        if command -v docker &> /dev/null; then
            TFLINT_IMAGE_FULL="$TFLINT_REGISTRY/$TFLINT_IMAGE:$TFLINT_TAG"
            TFLINT_INIT=$(docker run --rm -v "$TERRAFORM_DIR:/workspace" -w /workspace "$TFLINT_IMAGE_FULL" --init --no-color 2>&1)
            TFLINT_OUTPUT=$(docker run --rm -v "$TERRAFORM_DIR:/workspace" -w /workspace "$TFLINT_IMAGE_FULL" -f compact --no-color 2>&1)
            
            if [ $? -ne 0 ] && [ -n "$TFLINT_OUTPUT" ]; then
                ISSUES_FOUND=true
                echo -e "${RED}✗ TFLint issues found${NC}"
                FINDINGS+=("tflint" "$TFLINT_OUTPUT")
                TFLINT_REPORT_OUTPUT="$TFLINT_OUTPUT"
            else
                echo -e "${GREEN}✓ TFLint passed${NC}"
                if [ -n "$TFLINT_OUTPUT" ]; then
                    TFLINT_REPORT_OUTPUT="$TFLINT_OUTPUT"
                else
                    TFLINT_REPORT_OUTPUT="tflint passed"
                fi
            fi
        else
            echo -e "${RED}✗ Docker not found${NC}"
            ISSUES_FOUND=true
            TFLINT_REPORT_OUTPUT="Docker is not installed or not in PATH. Install Docker and ensure 'docker' is available."
            FINDINGS+=("tflint" "$TFLINT_REPORT_OUTPUT")
        fi
    else
        echo -e "${YELLOW}⊘ TFLint check skipped${NC}"
        TFLINT_REPORT_OUTPUT="TFLint check skipped"
    fi
else
    echo -e "${YELLOW}⊘ TFLint check skipped (disabled in config)${NC}"
    TFLINT_REPORT_OUTPUT="Skipped (disabled in configuration)"
fi
echo ""

#############################################################################
# 5. tfsec Check
#############################################################################
echo -e "${YELLOW}[5/5] Running tfsec...${NC}"
if [ "$CHECK_TFSEC" = "true" ]; then
    if [ "$SKIP_DOCKER" = false ]; then
        if command -v docker &> /dev/null; then
            TFSEC_IMAGE_FULL="$TFSEC_REGISTRY/$TFSEC_IMAGE:$TFSEC_TAG"
            TFSEC_OUTPUT=$(docker run --rm -v "$TERRAFORM_DIR:/workspace" "$TFSEC_IMAGE_FULL" /workspace --format lovely --no-color 2>&1)
            
            if [ $? -ne 0 ] && [ -n "$TFSEC_OUTPUT" ]; then
                ISSUES_FOUND=true
                echo -e "${RED}✗ tfsec issues found${NC}"
                FINDINGS+=("tfsec" "$TFSEC_OUTPUT")
                TFSEC_REPORT_OUTPUT="$TFSEC_OUTPUT"
            else
                echo -e "${GREEN}✓ tfsec passed${NC}"
                if [ -n "$TFSEC_OUTPUT" ]; then
                    TFSEC_REPORT_OUTPUT="$TFSEC_OUTPUT"
                else
                    TFSEC_REPORT_OUTPUT="tfsec passed"
                fi
            fi
        else
            ISSUES_FOUND=true
            TFSEC_REPORT_OUTPUT="Docker is not installed or not in PATH. Install Docker and ensure 'docker' is available."
            FINDINGS+=("tfsec" "$TFSEC_REPORT_OUTPUT")
        fi
    else
        echo -e "${YELLOW}⊘ tfsec check skipped${NC}"
        TFSEC_REPORT_OUTPUT="tfsec check skipped"
    fi
else
    echo -e "${YELLOW}⊘ tfsec check skipped (disabled in config)${NC}"
    TFSEC_REPORT_OUTPUT="Skipped (disabled in configuration)"
fi
echo ""

#############################################################################
# Generate Report
#############################################################################
echo "## Scan Summary" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

if [ "$ISSUES_FOUND" = true ]; then
    echo "**Status:** ⚠️ Issues found" >> "$REPORT_FILE"
else
    echo "**Status:** ✓ No issues found" >> "$REPORT_FILE"
fi

echo "" >> "$REPORT_FILE"
echo "## Tool Outputs" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

echo "### terraform fmt" >> "$REPORT_FILE"
echo '```shell' >> "$REPORT_FILE"
echo "$FMT_REPORT_OUTPUT" >> "$REPORT_FILE"
echo '```' >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

echo "### terraform init" >> "$REPORT_FILE"
echo '```shell' >> "$REPORT_FILE"
echo "$INIT_REPORT_OUTPUT" >> "$REPORT_FILE"
echo '```' >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

echo "### terraform validate" >> "$REPORT_FILE"
echo '```shell' >> "$REPORT_FILE"
echo "$VALIDATE_REPORT_OUTPUT" >> "$REPORT_FILE"
echo '```' >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

echo "### tflint" >> "$REPORT_FILE"
echo '```shell' >> "$REPORT_FILE"
if [ -n "$TFLINT_INIT" ]; then
    echo "$TFLINT_INIT" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
fi
echo "$TFLINT_REPORT_OUTPUT" >> "$REPORT_FILE"
echo '```' >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

echo "### tfsec" >> "$REPORT_FILE"
echo '```shell' >> "$REPORT_FILE"
echo "$TFSEC_REPORT_OUTPUT" >> "$REPORT_FILE"
echo '```' >> "$REPORT_FILE"

#############################################################################
# Output Results
#############################################################################
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
