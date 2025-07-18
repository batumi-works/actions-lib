#!/usr/bin/env bash
# Git configuration script for claude-setup action

set -e

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
    
    # Configure git user
    if ! git config --global user.name "$git_user_name"; then
        echo "::error::Failed to configure git user name"
        exit 1
    fi
    
    if ! git config --global user.email "$git_user_email"; then
        echo "::error::Failed to configure git user email"
        exit 1
    fi
    
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
        return 0
    else
        echo "::warning::Git user not configured"
        return 1
    fi
}

# Main execution
main() {
    local git_user_name="$1"
    local git_user_email="$2"
    local configure_git="$3"
    
    configure_git_user "$git_user_name" "$git_user_email" "$configure_git"
    
    # Validate configuration if it was supposed to be set
    if [[ "$configure_git" == "true" ]]; then
        validate_git_config
    fi
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi