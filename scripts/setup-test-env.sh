#!/usr/bin/env bash
# Setup script for GitHub Actions test environment

set -e

echo "🔧 Setting up GitHub Actions test environment..."

# Detect OS
OS="$(uname -s)"
case "${OS}" in
    Linux*)     MACHINE=Linux;;
    Darwin*)    MACHINE=Mac;;
    CYGWIN*)    MACHINE=Cygwin;;
    MINGW*)     MACHINE=MinGw;;
    *)          MACHINE="UNKNOWN:${OS}"
esac

echo "📱 Detected OS: $MACHINE"

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to install on Ubuntu/Debian
install_ubuntu() {
    echo "📦 Installing dependencies for Ubuntu/Debian..."
    
    # Update package list
    sudo apt-get update
    
    # Install basic dependencies
    sudo apt-get install -y \
        bats \
        shellcheck \
        python3 \
        curl \
        git \
        docker.io \
        gh
    
    # Start Docker
    sudo systemctl start docker
    sudo usermod -aG docker $USER
    
    echo "⚠️  You may need to log out and back in for Docker permissions to take effect"
}

# Function to install on macOS
install_mac() {
    echo "📦 Installing dependencies for macOS..."
    
    # Check if Homebrew is installed
    if ! command_exists brew; then
        echo "🍺 Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    
    # Install dependencies
    brew install \
        bats-core \
        shellcheck \
        python3 \
        docker \
        gh \
        act
}

# Function to install act CLI
install_act() {
    if command_exists act; then
        echo "✅ act CLI already installed: $(act --version)"
        return
    fi
    
    echo "🎭 Installing act CLI..."
    
    case $MACHINE in
        Linux)
            curl -L https://github.com/nektos/act/releases/latest/download/act_Linux_x86_64.tar.gz | tar -xz
            sudo mv act /usr/local/bin/
            ;;
        Mac)
            if command_exists brew; then
                brew install act
            else
                echo "❌ Homebrew not found. Please install Homebrew first."
                exit 1
            fi
            ;;
        *)
            echo "❌ Unsupported OS for automatic act installation: $MACHINE"
            echo "Please install act manually from: https://github.com/nektos/act"
            exit 1
            ;;
    esac
}

# Function to setup Docker images for act
setup_act_images() {
    if ! command_exists docker; then
        echo "⚠️  Docker not available, skipping image setup"
        return
    fi
    
    echo "🐳 Setting up Docker images for act..."
    
    # Pull required images
    docker pull ghcr.io/catthehacker/ubuntu:act-latest || echo "⚠️  Failed to pull Docker image"
    docker pull ghcr.io/catthehacker/ubuntu:act-20.04 || echo "⚠️  Failed to pull Docker image"
}

# Function to install Ruby gems for coverage
install_coverage_tools() {
    echo "💎 Installing coverage tools..."
    
    if command_exists gem; then
        sudo gem install bashcov || echo "⚠️  Failed to install bashcov"
    else
        echo "⚠️  Ruby not found, skipping bashcov installation"
    fi
}

# Function to verify installation
verify_installation() {
    echo "✅ Verifying installation..."
    
    local errors=0
    
    # Check required commands
    required_commands=(
        "bats:BATS testing framework"
        "git:Git version control"
        "bash:Bash shell"
        "python3:Python 3"
        "curl:HTTP client"
        "docker:Docker container runtime"
        "act:GitHub Actions runner"
    )
    
    for cmd_desc in "${required_commands[@]}"; do
        cmd="${cmd_desc%%:*}"
        desc="${cmd_desc##*:}"
        
        if command_exists "$cmd"; then
            version=$($cmd --version 2>/dev/null | head -1 || echo "unknown")
            echo "  ✅ $desc: $version"
        else
            echo "  ❌ $desc: NOT FOUND"
            ((errors++))
        fi
    done
    
    # Check optional commands
    optional_commands=(
        "shellcheck:Shell script linter"
        "gh:GitHub CLI"
        "bashcov:Coverage tool"
    )
    
    echo ""
    echo "📋 Optional tools:"
    for cmd_desc in "${optional_commands[@]}"; do
        cmd="${cmd_desc%%:*}"
        desc="${cmd_desc##*:}"
        
        if command_exists "$cmd"; then
            version=$($cmd --version 2>/dev/null | head -1 || echo "unknown")
            echo "  ✅ $desc: $version"
        else
            echo "  ⚠️  $desc: NOT FOUND (optional)"
        fi
    done
    
    if [ $errors -eq 0 ]; then
        echo ""
        echo "🎉 All required dependencies are installed!"
        echo "🚀 You can now run: make test"
    else
        echo ""
        echo "❌ $errors required dependencies are missing"
        echo "Please install the missing dependencies and try again"
        exit 1
    fi
}

# Function to create test environment
create_test_env() {
    echo "📁 Creating test environment..."
    
    # Create necessary directories
    mkdir -p tests/{unit,integration,e2e,fixtures,mocks,utils}
    mkdir -p reports
    
    # Create test secrets file for act
    cat > .secrets << 'EOF'
# Test secrets for act CLI
# These are dummy values for testing purposes only
GITHUB_TOKEN=ghp_test_token_for_local_testing
CLAUDE_CODE_OAUTH_TOKEN=claude_test_token_for_local_testing
ANTHROPIC_AUTH_TOKEN=anthropic_test_token_for_local_testing
EOF
    
    echo "📝 Created .secrets file for act CLI testing"
    echo "⚠️  .secrets contains dummy values for testing only"
}

# Main execution
main() {
    echo "🧪 GitHub Actions Test Environment Setup"
    echo "======================================="
    
    # Install based on OS
    case $MACHINE in
        Linux)
            install_ubuntu
            ;;
        Mac)
            install_mac
            ;;
        *)
            echo "❌ Unsupported OS: $MACHINE"
            echo "Please install dependencies manually:"
            echo "  - bats"
            echo "  - act"
            echo "  - docker"
            echo "  - shellcheck"
            echo "  - python3"
            exit 1
            ;;
    esac
    
    # Install act CLI if not installed by package manager
    install_act
    
    # Setup Docker images
    setup_act_images
    
    # Install coverage tools
    install_coverage_tools
    
    # Create test environment
    create_test_env
    
    # Verify everything is working
    verify_installation
    
    echo ""
    echo "🎯 Next steps:"
    echo "  1. Run 'make test' to execute all tests"
    echo "  2. Run 'make test-unit' for unit tests only"
    echo "  3. Run 'act --dryrun' to test with act CLI"
    echo "  4. Check 'tests/README.md' for detailed documentation"
}

# Run main function
main "$@"