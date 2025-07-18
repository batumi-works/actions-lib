# Solutions for GitHub Actions Library Issues 7-13

This document provides detailed solutions for issues 7-13 identified in PR #3, including explanations, code fixes, best practices, and testing approaches.

## Issue 7: Token Validation Placeholder

### Problem
The `validate_token.sh` script contains a placeholder function `test_token_connectivity` that doesn't actually test API connectivity. This means tokens could be invalid but pass validation.

### Solution
Implement actual API connectivity testing for both Claude and GitHub tokens with proper error handling and retry logic.

**Key improvements:**
- Real API calls to validate tokens
- Proper HTTP status code handling
- Retry mechanism for transient failures
- Detailed error messages for different failure modes
- Support for custom API endpoints via environment variables

**Before:**
```bash
test_token_connectivity() {
    local claude_oauth_token="$1"
    
    # This is a placeholder for actual connectivity testing
    echo "::notice::Token connectivity test skipped (placeholder)"
}
```

**After:**
```bash
test_claude_api_connectivity() {
    local claude_oauth_token="$1"
    local api_endpoint="${CLAUDE_API_ENDPOINT:-https://api.anthropic.com/v1/complete}"
    
    # Make actual API call with minimal request
    response=$(curl -s -w "\n%{http_code}" \
        -H "x-api-key: $claude_oauth_token" \
        -H "anthropic-version: 2023-06-01" \
        -X POST \
        -d '{"model":"claude-3-haiku-20240307","prompt":"\n\nHuman: Hello\n\nAssistant:","max_tokens_to_sample":1}' \
        "$api_endpoint")
    
    # Handle different response codes appropriately
    case "$http_status" in
        200) echo "::notice::Claude API connectivity test successful" ;;
        401) echo "::error::Invalid token" ;;
        429) echo "::warning::Rate limited but token is valid" ;;
        # ... more status codes
    esac
}
```

### Best Practices
- Always test API connectivity in CI/CD pipelines
- Use minimal API calls to avoid unnecessary costs
- Implement proper timeout handling
- Consider rate limiting implications
- Log detailed errors for debugging

### Testing Approach
```bash
# Test with valid token
./validate_token.sh "$VALID_TOKEN" "$GITHUB_TOKEN" true

# Test with invalid token
./validate_token.sh "invalid-token" "$GITHUB_TOKEN" true

# Test network failure scenarios
# Mock network failure with iptables or tc
```

---

## Issue 8: Git Command Availability Check

### Problem
The `configure_git.sh` script uses git commands without checking if git is installed, potentially causing cryptic errors.

### Solution
Add comprehensive command existence checks and permission validation before using git.

**Key improvements:**
- Check git availability at script start
- Verify git version compatibility
- Test write permissions for global config
- Platform-specific handling
- Graceful degradation with helpful error messages

**Before:**
```bash
# Directly uses git without checking
git config --global user.name "$git_user_name"
```

**After:**
```bash
# Check if git is available first
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

check_git_availability() {
    if ! command_exists git; then
        echo "::error::Git is not installed or not in PATH"
        exit 1
    fi
    
    # Check version compatibility
    local git_version=$(git --version | cut -d' ' -f3)
    local major_version=$(echo "$git_version" | cut -d'.' -f1)
    
    if [[ "$major_version" -lt 2 ]]; then
        echo "::warning::Git version $git_version is old. Version 2.0.0+ recommended"
    fi
}
```

### Best Practices
- Always check for required commands before use
- Provide clear error messages with installation hints
- Check both existence and permissions
- Consider minimum version requirements
- Handle platform differences gracefully

### Testing Approach
```bash
# Test without git installed
docker run --rm ubuntu:22.04 bash -c "apt-get remove git -y && ./configure_git.sh"

# Test with old git version
docker run --rm centos:7 ./configure_git.sh

# Test permission issues
chmod 000 ~/.gitconfig && ./configure_git.sh
```

---

## Issue 9: Docker File Exclusions Too Broad

### Problem
The `.dockerignore` file excludes all `Dockerfile*` and `docker-compose*.yml` files, which could prevent necessary Docker configurations from being included in builds.

### Solution
Use targeted exclusions that only exclude test/development specific files while preserving production configurations.

**Key improvements:**
- Exclude only test-specific Docker files
- Preserve production Dockerfile and docker-compose.yml
- Add comments explaining exclusion rationale
- Group related exclusions together
- Consider multi-stage build requirements

**Before:**
```
# Docker
Dockerfile*
docker-compose*.yml
.dockerignore
```

**After:**
```
# Docker - More targeted exclusions
# Only exclude test-specific Docker files
Dockerfile.test
Dockerfile.dev
docker-compose.test.yml
docker-compose.dev.yml
.dockerignore

# Do NOT exclude production Docker files:
# - Dockerfile (main production file)
# - docker-compose.yml (main compose file)
# - docker-compose.prod.yml (production overrides)
```

### Best Practices
- Be specific with exclusions
- Document why files are excluded
- Consider build context requirements
- Review exclusions regularly
- Test builds with different contexts

### Testing Approach
```bash
# Verify production files are included
docker build -t test-image .
docker run --rm test-image ls -la | grep -E "(Dockerfile|docker-compose.yml)"

# Verify test files are excluded
docker run --rm test-image ls -la | grep -v "Dockerfile.test"
```

---

## Issue 10: Hardcoded BATS Library Path

### Problem
The BATS library path is hardcoded to `/usr/lib/bats`, which doesn't exist on all systems (e.g., macOS, custom installations).

### Solution
Implement dynamic BATS library path detection with multiple fallback locations.

**Key improvements:**
- Auto-detect BATS installation location
- Support multiple common paths
- Allow environment variable override
- Platform-specific handling
- NPM global installation support

**Before:**
```bash
export BATS_LIB_PATH="/usr/lib/bats"
```

**After:**
```bash
find_bats_lib_path() {
    local possible_paths=(
        "/usr/lib/bats"
        "/usr/local/lib/bats"
        "/opt/homebrew/lib/bats"  # macOS Homebrew
        "${HOME}/.local/lib/bats"  # User installation
        # ... more paths
    )
    
    # Check npm global installation
    if command -v npm >/dev/null; then
        local npm_prefix=$(npm config get prefix)
        possible_paths+=("${npm_prefix}/lib/node_modules/bats/lib")
    fi
    
    # Find first existing path
    for path in "${possible_paths[@]}"; do
        [[ -d "$path" ]] && echo "$path" && return 0
    done
}

# Auto-detect if not set
export BATS_LIB_PATH="${BATS_LIB_PATH:-$(find_bats_lib_path)}"
```

### Best Practices
- Support multiple installation methods
- Check standard locations first
- Allow user override via environment
- Provide helpful error messages
- Document supported installation methods

### Testing Approach
```bash
# Test on different platforms
for platform in ubuntu:22.04 debian:11 alpine:latest; do
    docker run --rm -v "$PWD:/app" "$platform" /app/tests/bats.config
done

# Test with custom installation
BATS_LIB_PATH=/custom/path ./run-tests.sh
```

---

## Issue 11: Platform Hardcoding

### Problem
The `.actrc` file hardcodes `--platform linux/amd64`, preventing testing on ARM architectures.

### Solution
Remove hardcoded platform and implement automatic platform detection with override capability.

**Key improvements:**
- Auto-detect system architecture
- Support environment variable override
- Provide wrapper script for platform detection
- Support multi-architecture images
- Document platform options clearly

**Before:**
```
# Set default platform
--platform linux/amd64
```

**After:**
```bash
# act-wrapper.sh - Auto-detect platform
detect_platform() {
    local arch=$(uname -m)
    case "$arch" in
        x86_64|amd64) echo "linux/amd64" ;;
        aarch64|arm64) echo "linux/arm64" ;;
        armv7l) echo "linux/arm/v7" ;;
        *) echo "linux/amd64" ;;  # Fallback
    esac
}

# Use detected platform if not specified
if [[ -z "$ACT_PLATFORM" ]]; then
    act --platform "$(detect_platform)" "$@"
else
    act "$@"
fi
```

### Best Practices
- Support multiple architectures
- Auto-detect when possible
- Allow explicit override
- Document supported platforms
- Test on multiple architectures

### Testing Approach
```bash
# Test auto-detection
./act-wrapper.sh

# Test with override
ACT_PLATFORM=linux/arm64 ./act-wrapper.sh

# Test on different architectures
docker run --rm --platform linux/arm64 -v "$PWD:/app" ubuntu:22.04 /app/act-wrapper.sh
```

---

## Issue 12: Docker Layer Caching

### Problem
The Dockerfile uses a single large RUN command for all package installations, preventing efficient layer caching and causing slow rebuilds.

### Solution
Split installations into logical layers based on change frequency and dependencies.

**Key improvements:**
- Separate system packages from language packages
- Install external tools in dedicated layers
- Order layers by change frequency
- Group related packages logically
- Minimize layer size

**Before:**
```dockerfile
RUN apt-get update && apt-get install -y \
    bats \
    shellcheck \
    python3 \
    python3-pip \
    curl \
    wget \
    git \
    make \
    jq \
    docker.io \
    gh \
    # ... 20 more packages
    && rm -rf /var/lib/apt/lists/*
```

**After:**
```dockerfile
# Essential packages (rarely change)
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl wget gnupg \
    && rm -rf /var/lib/apt/lists/*

# Core development tools (occasional changes)
RUN apt-get update && apt-get install -y --no-install-recommends \
    git make build-essential \
    && rm -rf /var/lib/apt/lists/*

# Testing tools (might change with versions)
RUN apt-get update && apt-get install -y --no-install-recommends \
    bats shellcheck \
    && rm -rf /var/lib/apt/lists/*

# Language runtimes (separate for each)
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 python3-pip \
    && rm -rf /var/lib/apt/lists/*

# External tools (version-specific installs)
RUN curl -L "https://github.com/nektos/act/..." | tar -xz \
    && mv act /usr/local/bin/
```

### Best Practices
- Order layers by change frequency
- Use --no-install-recommends
- Clean up in the same layer
- Combine related packages
- Document layer purpose

### Testing Approach
```bash
# Build and measure time
time docker build -t test:before -f Dockerfile.test.old .
time docker build -t test:after -f Dockerfile.test .

# Make a small change and rebuild
echo "# comment" >> README.md
time docker build -t test:after-change -f Dockerfile.test .

# Compare layer sizes
docker history test:after
```

---

## Issue 13: Missing Version Pinning

### Problem
External tools and packages are installed without version constraints, leading to non-reproducible builds and potential breaking changes.

### Solution
Pin all external dependencies to specific versions with clear upgrade strategy.

**Key improvements:**
- Define versions as ARG for easy updates
- Pin system packages where possible
- Install specific tool versions
- Create version manifest
- Document version requirements

**Before:**
```dockerfile
RUN gem install bashcov simplecov
RUN curl -L https://github.com/nektos/act/releases/latest/download/...
RUN pip3 install pyyaml jinja2
```

**After:**
```dockerfile
# Version definitions
ARG ACT_VERSION=0.2.54
ARG BASHCOV_VERSION=3.1.2
ARG PYYAML_VERSION=6.0.1

# Install with specific versions
RUN gem install bashcov:${BASHCOV_VERSION} simplecov:${SIMPLECOV_VERSION}

RUN curl -L "https://github.com/nektos/act/releases/download/v${ACT_VERSION}/..." 

RUN pip3 install --no-cache-dir \
    pyyaml==${PYYAML_VERSION} \
    jinja2==${JINJA2_VERSION}

# Create version manifest
RUN echo "Act: ${ACT_VERSION}" > /versions.txt && \
    echo "Bashcov: ${BASHCOV_VERSION}" >> /versions.txt
```

### Best Practices
- Pin to specific versions, not just major versions
- Use ARG for version definitions
- Create version manifest file
- Test version compatibility
- Document upgrade process
- Consider security updates

### Testing Approach
```bash
# Build with specific versions
docker build --build-arg ACT_VERSION=0.2.54 -t test:v1 .

# Verify versions
docker run --rm test:v1 act --version
docker run --rm test:v1 cat /versions.txt

# Test version compatibility
docker build --build-arg ACT_VERSION=0.2.53 -t test:older .
```

---

## Summary

These solutions address critical infrastructure issues that affect reliability, portability, and maintainability:

1. **Token Validation**: Implement real API connectivity testing
2. **Git Availability**: Add command existence and permission checks
3. **Docker Exclusions**: Use targeted, documented exclusions
4. **BATS Path**: Implement dynamic path detection
5. **Platform Support**: Enable multi-architecture testing
6. **Layer Caching**: Optimize Docker build performance
7. **Version Pinning**: Ensure reproducible builds

Each solution includes error handling, platform compatibility, and clear documentation to improve the overall robustness of the GitHub Actions testing infrastructure.