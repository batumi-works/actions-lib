#!/usr/bin/env bash
# Output generation script for claude-setup action

set -e

# Function to set repository path output
set_repository_path() {
    local repository_path="${1:-$GITHUB_WORKSPACE}"
    
    # Validate path exists
    if [[ ! -d "$repository_path" ]]; then
        echo "::error::Repository path does not exist: $repository_path"
        exit 1
    fi
    
    # Set GitHub output
    echo "repository_path=$repository_path" >> "${GITHUB_OUTPUT}"
    echo "::notice::Repository path set to: $repository_path"
}

# Function to set additional outputs
set_additional_outputs() {
    local git_user_name="$1"
    local git_user_email="$2"
    
    # Set git configuration outputs (if available)
    if [[ -n "$git_user_name" ]]; then
        echo "git_user_name=$git_user_name" >> "${GITHUB_OUTPUT}"
    fi
    
    if [[ -n "$git_user_email" ]]; then
        echo "git_user_email=$git_user_email" >> "${GITHUB_OUTPUT}"
    fi
    
    # Set timestamp
    echo "setup_timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "${GITHUB_OUTPUT}"
}

# Main execution
main() {
    local repository_path="$1"
    local git_user_name="$2"
    local git_user_email="$3"
    
    set_repository_path "$repository_path"
    set_additional_outputs "$git_user_name" "$git_user_email"
    
    echo "::notice::All outputs set successfully"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi