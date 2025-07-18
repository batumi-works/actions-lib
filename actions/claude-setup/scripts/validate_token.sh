#!/usr/bin/env bash
# Token validation script for claude-setup action

set -e

# Function to validate Claude OAuth token
validate_claude_token() {
    local claude_oauth_token="$1"
    
    # Check if token is provided
    if [[ -z "$claude_oauth_token" ]]; then
        echo "::error::Claude OAuth token is required"
        exit 1
    fi
    
    # Check token format (basic validation)
    if [[ ! "$claude_oauth_token" =~ ^[A-Za-z0-9_-]+$ ]]; then
        echo "::error::Invalid Claude OAuth token format"
        exit 1
    fi
    
    # Check token length (tokens should be reasonably long)
    if [[ ${#claude_oauth_token} -lt 10 ]]; then
        echo "::error::Claude OAuth token appears to be too short"
        exit 1
    fi
    
    echo "::notice::Claude OAuth token validation passed"
}

# Function to validate GitHub token
validate_github_token() {
    local github_token="$1"
    
    # Check if token is provided
    if [[ -z "$github_token" ]]; then
        echo "::error::GitHub token is required"
        exit 1
    fi
    
    # Check token format (GitHub tokens start with specific prefixes)
    if [[ ! "$github_token" =~ ^(ghp_|gho_|ghu_|ghs_|ghr_) ]]; then
        echo "::warning::GitHub token format may be invalid"
    fi
    
    echo "::notice::GitHub token validation passed"
}

# Function to test token connectivity (optional)
test_token_connectivity() {
    local claude_oauth_token="$1"
    
    # This is a placeholder for actual connectivity testing
    # In a real implementation, you might make a test API call
    echo "::notice::Token connectivity test skipped (placeholder)"
}

# Main execution
main() {
    local claude_oauth_token="$1"
    local github_token="$2"
    local test_connectivity="${3:-false}"
    
    validate_claude_token "$claude_oauth_token"
    validate_github_token "$github_token"
    
    if [[ "$test_connectivity" == "true" ]]; then
        test_token_connectivity "$claude_oauth_token"
    fi
    
    echo "::notice::All token validations passed"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi