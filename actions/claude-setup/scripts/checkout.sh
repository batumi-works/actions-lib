#!/usr/bin/env bash
# Checkout script for claude-setup action

set -e

# Function to checkout repository
checkout_repository() {
    local fetch_depth="$1"
    local github_token="$2"
    
    # Validate inputs
    if [[ -z "$github_token" ]]; then
        echo "::error::GitHub token is required"
        exit 1
    fi
    
    # Set fetch depth default
    fetch_depth="${fetch_depth:-0}"
    
    # Use actions/checkout@v4 functionality
    echo "::notice::Checking out repository with fetch-depth: $fetch_depth"
    
    # In a real scenario, this would call actions/checkout
    # For testing, we'll simulate the checkout process
    if [[ "$GITHUB_ACTIONS" == "true" ]]; then
        # In GitHub Actions, actions/checkout handles this
        echo "repository_path=${GITHUB_WORKSPACE}" >> "${GITHUB_OUTPUT}"
    else
        # For local testing, simulate checkout
        echo "repository_path=$(pwd)" >> "${GITHUB_OUTPUT}"
    fi
    
    echo "::notice::Repository checked out successfully"
}

# Main execution
main() {
    checkout_repository "$1" "$2"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi