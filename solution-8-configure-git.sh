#!/usr/bin/env bash
# Git configuration script for claude-setup action with command availability checks

set -e

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check git availability and version
check_git_availability() {
    if ! command_exists git; then
        echo "::error::Git is not installed or not in PATH"
        echo "::error::Please install git before using this action"
        exit 1
    fi
    
    # Get git version
    local git_version
    git_version=$(git --version 2>/dev/null | cut -d' ' -f3)
    
    if [[ -z "$git_version" ]]; then
        echo "::error::Unable to determine git version"
        exit 1
    fi
    
    echo "::notice::Git version $git_version detected"
    
    # Check minimum version (git 2.0.0 or higher recommended)
    local major_version
    major_version=$(echo "$git_version" | cut -d'.' -f1)
    
    if [[ "$major_version" -lt 2 ]]; then
        echo "::warning::Git version $git_version is old. Version 2.0.0 or higher is recommended"
    fi
}

# Function to check git permissions
check_git_permissions() {
    # Try to read global git config
    if ! git config --global --list >/dev/null 2>&1; then
        echo "::warning::Unable to read global git configuration"
        echo "::notice::Attempting to initialize git config directory"
        
        # Create git config directory if it doesn't exist
        local git_config_dir="${HOME}/.config/git"
        if [[ ! -d "$git_config_dir" ]]; then
            mkdir -p "$git_config_dir" 2>/dev/null || {
                echo "::error::Failed to create git config directory"
                exit 1
            }
        fi
    fi
    
    # Test write permissions
    local test_key="test.permission.check"
    if ! git config --global "$test_key" "test" 2>/dev/null; then
        echo "::error::No write permissions for global git configuration"
        exit 1
    fi
    
    # Clean up test key
    git config --global --unset "$test_key" 2>/dev/null || true
    
    echo "::notice::Git configuration permissions verified"
}

# Function to configure git user
configure_git_user() {
    local git_user_name="$1"
    local git_user_email="$2"
    local configure_git="$3"
    
    # Check if git configuration is enabled
    if [[ "$configure_git" != "true" ]]; then
        echo "::notice::Git configuration skipped"
        return 0
    fi
    
    # Set defaults
    git_user_name="${git_user_name:-Claude AI Bot}"
    git_user_email="${git_user_email:-claude-ai@users.noreply.github.com}"
    
    echo "::notice::Configuring git user: $git_user_name <$git_user_email>"
    
    # Configure git user with error handling
    if ! git config --global user.name "$git_user_name"; then
        echo "::error::Failed to configure git user name"
        echo "::debug::Command: git config --global user.name \"$git_user_name\""
        exit 1
    fi
    
    if ! git config --global user.email "$git_user_email"; then
        echo "::error::Failed to configure git user email"
        echo "::debug::Command: git config --global user.email \"$git_user_email\""
        exit 1
    fi
    
    # Set additional recommended configurations
    echo "::notice::Setting additional git configurations"
    
    # Safe directory configuration for GitHub Actions
    if [[ -n "${GITHUB_WORKSPACE:-}" ]]; then
        git config --global --add safe.directory "$GITHUB_WORKSPACE" 2>/dev/null || {
            echo "::warning::Failed to add safe directory configuration"
        }
    fi
    
    # Set default branch name
    git config --global init.defaultBranch main 2>/dev/null || {
        echo "::warning::Failed to set default branch name"
    }
    
    # Set pull strategy to avoid warnings
    git config --global pull.rebase false 2>/dev/null || {
        echo "::warning::Failed to set pull strategy"
    }
    
    echo "::notice::Git user configured successfully"
}

# Function to validate git configuration
validate_git_config() {
    local user_name
    local user_email
    
    user_name=$(git config --global user.name 2>/dev/null || echo "")
    user_email=$(git config --global user.email 2>/dev/null || echo "")
    
    if [[ -n "$user_name" && -n "$user_email" ]]; then
        echo "::notice::Git user: $user_name <$user_email>"
        
        # Show other relevant configurations
        local default_branch
        default_branch=$(git config --global init.defaultBranch 2>/dev/null || echo "")
        if [[ -n "$default_branch" ]]; then
            echo "::notice::Default branch: $default_branch"
        fi
        
        return 0
    else
        echo "::warning::Git user not configured"
        return 1
    fi
}

# Function to display git configuration summary
display_git_config_summary() {
    echo "::group::Git Configuration Summary"
    
    # Display relevant git configurations
    echo "User Configuration:"
    git config --global user.name 2>/dev/null || echo "  user.name: (not set)"
    git config --global user.email 2>/dev/null || echo "  user.email: (not set)"
    
    echo ""
    echo "Repository Configuration:"
    git config --global init.defaultBranch 2>/dev/null || echo "  init.defaultBranch: (not set)"
    git config --global pull.rebase 2>/dev/null || echo "  pull.rebase: (not set)"
    
    echo ""
    echo "Safe Directories:"
    git config --global --get-all safe.directory 2>/dev/null || echo "  (none configured)"
    
    echo "::endgroup::"
}

# Main execution
main() {
    local git_user_name="$1"
    local git_user_email="$2"
    local configure_git="$3"
    
    # Always check git availability first
    check_git_availability
    
    # Check permissions if we're going to configure
    if [[ "$configure_git" == "true" ]]; then
        check_git_permissions
    fi
    
    # Configure git user
    configure_git_user "$git_user_name" "$git_user_email" "$configure_git"
    
    # Validate configuration if it was supposed to be set
    if [[ "$configure_git" == "true" ]]; then
        if validate_git_config; then
            display_git_config_summary
        else
            echo "::error::Git configuration validation failed"
            exit 1
        fi
    fi
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi