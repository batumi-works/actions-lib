#!/usr/bin/env bash
# Wrapper script for act with automatic platform detection

set -e

# Function to detect system architecture
detect_platform() {
    local arch=$(uname -m)
    local os=$(uname -s | tr '[:upper:]' '[:lower:]')
    
    case "$arch" in
        x86_64|amd64)
            echo "${os}/amd64"
            ;;
        aarch64|arm64)
            echo "${os}/arm64"
            ;;
        armv7l|armhf)
            echo "${os}/arm/v7"
            ;;
        i386|i686)
            echo "${os}/386"
            ;;
        *)
            echo "Warning: Unknown architecture: $arch" >&2
            echo "${os}/amd64" # Default fallback
            ;;
    esac
}

# Check if platform is already specified
platform_specified=false
for arg in "$@"; do
    if [[ "$arg" == "--platform" ]] || [[ "$arg" == -P* ]]; then
        platform_specified=true
        break
    fi
done

# Build act command
act_cmd=(act)

# Add platform if not specified and not set via environment
if [[ "$platform_specified" == "false" ]] && [[ -z "${ACT_PLATFORM}" ]]; then
    detected_platform=$(detect_platform)
    echo "Auto-detected platform: $detected_platform" >&2
    act_cmd+=(--platform "$detected_platform")
fi

# Add all passed arguments
act_cmd+=("$@")

# Execute act with the built command
exec "${act_cmd[@]}"