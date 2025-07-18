#!/usr/bin/env bash
# Enhanced error handling utilities for testing scripts

# Error types
declare -A ERROR_CODES=(
    ["DOCKER_NOT_FOUND"]=1
    ["DOCKER_NOT_RUNNING"]=2
    ["COMPOSE_NOT_FOUND"]=3
    ["DISK_SPACE_LOW"]=4
    ["BUILD_FAILED"]=5
    ["TEST_FAILED"]=6
    ["NETWORK_ERROR"]=7
    ["PERMISSION_DENIED"]=8
    ["TIMEOUT"]=9
    ["INVALID_CONFIG"]=10
)

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Error context storage
ERROR_CONTEXT=""
ERROR_SUGGESTIONS=""

# Function to set error context
set_error_context() {
    ERROR_CONTEXT="$1"
    ERROR_SUGGESTIONS="$2"
}

# Function to handle errors with detailed information
handle_error() {
    local error_code="$1"
    local error_message="$2"
    local error_type="${3:-UNKNOWN}"
    
    echo -e "${RED}${BOLD}ERROR: $error_message${NC}" >&2
    echo -e "${RED}Error Code: $error_code${NC}" >&2
    echo -e "${RED}Error Type: $error_type${NC}" >&2
    
    if [[ -n "$ERROR_CONTEXT" ]]; then
        echo -e "${YELLOW}Context: $ERROR_CONTEXT${NC}" >&2
    fi
    
    # Provide specific suggestions based on error type
    case "$error_type" in
        "DOCKER_NOT_FOUND")
            echo -e "${BLUE}Suggestions:${NC}" >&2
            echo "  1. Install Docker: https://docs.docker.com/get-docker/" >&2
            echo "  2. Ensure Docker is in your PATH" >&2
            echo "  3. Try: which docker" >&2
            ;;
        "DOCKER_NOT_RUNNING")
            echo -e "${BLUE}Suggestions:${NC}" >&2
            echo "  1. Start Docker Desktop (macOS/Windows)" >&2
            echo "  2. Start Docker service: sudo systemctl start docker (Linux)" >&2
            echo "  3. Check Docker status: docker info" >&2
            ;;
        "COMPOSE_NOT_FOUND")
            echo -e "${BLUE}Suggestions:${NC}" >&2
            echo "  1. Install Docker Compose: https://docs.docker.com/compose/install/" >&2
            echo "  2. Verify installation: docker-compose --version" >&2
            echo "  3. Or use: docker compose (newer Docker versions)" >&2
            ;;
        "DISK_SPACE_LOW")
            echo -e "${BLUE}Suggestions:${NC}" >&2
            echo "  1. Clean Docker resources: docker system prune -a" >&2
            echo "  2. Remove unused volumes: docker volume prune" >&2
            echo "  3. Check disk usage: df -h" >&2
            ;;
        "BUILD_FAILED")
            echo -e "${BLUE}Suggestions:${NC}" >&2
            echo "  1. Check Dockerfile syntax" >&2
            echo "  2. Verify all required files exist" >&2
            echo "  3. Try building with --no-cache" >&2
            echo "  4. Check build logs above for specific errors" >&2
            ;;
        "TEST_FAILED")
            echo -e "${BLUE}Suggestions:${NC}" >&2
            echo "  1. Check test logs for specific failures" >&2
            echo "  2. Run tests individually to isolate issues" >&2
            echo "  3. Verify test dependencies are installed" >&2
            echo "  4. Check environment variables" >&2
            ;;
        "NETWORK_ERROR")
            echo -e "${BLUE}Suggestions:${NC}" >&2
            echo "  1. Check internet connectivity" >&2
            echo "  2. Verify proxy settings if behind firewall" >&2
            echo "  3. Try: docker pull ubuntu:22.04 (test connectivity)" >&2
            ;;
        "PERMISSION_DENIED")
            echo -e "${BLUE}Suggestions:${NC}" >&2
            echo "  1. Add user to docker group: sudo usermod -aG docker \$USER" >&2
            echo "  2. Log out and back in for group changes" >&2
            echo "  3. Or use sudo (not recommended)" >&2
            ;;
        "TIMEOUT")
            echo -e "${BLUE}Suggestions:${NC}" >&2
            echo "  1. Increase timeout values" >&2
            echo "  2. Check system resources (CPU/Memory)" >&2
            echo "  3. Run fewer tests in parallel" >&2
            ;;
        "INVALID_CONFIG")
            echo -e "${BLUE}Suggestions:${NC}" >&2
            echo "  1. Validate compose file: docker-compose -f file.yml config" >&2
            echo "  2. Check YAML syntax" >&2
            echo "  3. Verify all referenced files exist" >&2
            ;;
    esac
    
    if [[ -n "$ERROR_SUGGESTIONS" ]]; then
        echo -e "${BLUE}Additional suggestions:${NC}" >&2
        echo "$ERROR_SUGGESTIONS" >&2
    fi
    
    # Log error to file if LOG_FILE is set
    if [[ -n "$LOG_FILE" ]]; then
        {
            echo "=== ERROR LOG ==="
            echo "Timestamp: $(date)"
            echo "Error Code: $error_code"
            echo "Error Type: $error_type"
            echo "Error Message: $error_message"
            echo "Context: $ERROR_CONTEXT"
            echo "================="
        } >> "$LOG_FILE"
    fi
    
    return "$error_code"
}

# Function to check command availability with error handling
check_command() {
    local cmd="$1"
    local error_type="$2"
    local custom_message="$3"
    
    if ! command -v "$cmd" &> /dev/null; then
        handle_error "${ERROR_CODES[$error_type]}" \
            "${custom_message:-Command '$cmd' not found}" \
            "$error_type"
        return 1
    fi
    return 0
}

# Function to check disk space with error handling
check_disk_space() {
    local required_mb="$1"
    local path="${2:-/}"
    
    local available_kb=$(df "$path" | awk 'NR==2 {print $4}')
    local available_mb=$((available_kb / 1024))
    
    if [[ $available_mb -lt $required_mb ]]; then
        set_error_context "Required: ${required_mb}MB, Available: ${available_mb}MB"
        handle_error "${ERROR_CODES[DISK_SPACE_LOW]}" \
            "Insufficient disk space" \
            "DISK_SPACE_LOW"
        return 1
    fi
    return 0
}

# Function to run command with timeout and error handling
run_with_timeout() {
    local timeout="$1"
    shift
    local cmd="$*"
    
    if command -v timeout &> /dev/null; then
        if ! timeout "$timeout" bash -c "$cmd"; then
            local exit_code=$?
            if [[ $exit_code -eq 124 ]]; then
                handle_error "${ERROR_CODES[TIMEOUT]}" \
                    "Command timed out after ${timeout}s: $cmd" \
                    "TIMEOUT"
            else
                handle_error "$exit_code" \
                    "Command failed: $cmd" \
                    "COMMAND_FAILED"
            fi
            return $exit_code
        fi
    else
        # Fallback without timeout command
        eval "$cmd"
    fi
}

# Function to retry command with exponential backoff
retry_with_backoff() {
    local max_attempts="${1:-3}"
    local initial_delay="${2:-1}"
    shift 2
    local cmd="$*"
    
    local attempt=1
    local delay=$initial_delay
    
    while [[ $attempt -le $max_attempts ]]; do
        echo -e "${BLUE}Attempt $attempt/$max_attempts: $cmd${NC}" >&2
        
        if eval "$cmd"; then
            return 0
        fi
        
        if [[ $attempt -lt $max_attempts ]]; then
            echo -e "${YELLOW}Command failed, retrying in ${delay}s...${NC}" >&2
            sleep "$delay"
            delay=$((delay * 2))
        fi
        
        ((attempt++))
    done
    
    handle_error 1 \
        "Command failed after $max_attempts attempts: $cmd" \
        "RETRY_EXHAUSTED"
    return 1
}

# Export functions and variables
export -f handle_error
export -f set_error_context
export -f check_command
export -f check_disk_space
export -f run_with_timeout
export -f retry_with_backoff
export ERROR_CODES