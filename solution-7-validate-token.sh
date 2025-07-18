#!/usr/bin/env bash
# Token validation script for claude-setup action with full connectivity testing

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

# Function to test Claude API connectivity
test_claude_api_connectivity() {
    local claude_oauth_token="$1"
    local api_endpoint="${CLAUDE_API_ENDPOINT:-https://api.anthropic.com/v1/complete}"
    local test_timeout="${CLAUDE_TEST_TIMEOUT:-10}"
    
    echo "::notice::Testing Claude API connectivity..."
    
    # Create a minimal test request
    local test_payload='{
        "model": "claude-3-haiku-20240307",
        "prompt": "\n\nHuman: Hello\n\nAssistant:",
        "max_tokens_to_sample": 1,
        "temperature": 0
    }'
    
    # Make API call with proper error handling
    local response
    local http_status
    
    # Use curl with write-out to capture HTTP status
    response=$(curl -s -w "\n%{http_code}" \
        --max-time "$test_timeout" \
        -H "Accept: application/json" \
        -H "Content-Type: application/json" \
        -H "x-api-key: $claude_oauth_token" \
        -H "anthropic-version: 2023-06-01" \
        -X POST \
        -d "$test_payload" \
        "$api_endpoint" 2>&1) || {
        echo "::error::Failed to connect to Claude API: Network error"
        return 1
    }
    
    # Extract HTTP status code (last line)
    http_status=$(echo "$response" | tail -n1)
    # Extract response body (all but last line)
    local response_body=$(echo "$response" | sed '$d')
    
    # Handle different response codes
    case "$http_status" in
        200)
            echo "::notice::Claude API connectivity test successful"
            return 0
            ;;
        401)
            echo "::error::Claude API authentication failed - invalid token"
            return 1
            ;;
        403)
            echo "::error::Claude API access forbidden - check token permissions"
            return 1
            ;;
        429)
            echo "::warning::Claude API rate limit exceeded - token is valid but rate limited"
            return 0
            ;;
        500|502|503|504)
            echo "::warning::Claude API server error ($http_status) - token may be valid"
            return 0
            ;;
        *)
            echo "::error::Claude API returned unexpected status: $http_status"
            echo "::debug::Response: $response_body"
            return 1
            ;;
    esac
}

# Function to test GitHub API connectivity
test_github_api_connectivity() {
    local github_token="$1"
    local api_endpoint="https://api.github.com/user"
    local test_timeout="${GITHUB_TEST_TIMEOUT:-10}"
    
    echo "::notice::Testing GitHub API connectivity..."
    
    # Make API call
    local response
    local http_status
    
    response=$(curl -s -w "\n%{http_code}" \
        --max-time "$test_timeout" \
        -H "Accept: application/vnd.github.v3+json" \
        -H "Authorization: Bearer $github_token" \
        "$api_endpoint" 2>&1) || {
        echo "::error::Failed to connect to GitHub API: Network error"
        return 1
    }
    
    # Extract HTTP status code
    http_status=$(echo "$response" | tail -n1)
    local response_body=$(echo "$response" | sed '$d')
    
    # Handle response codes
    case "$http_status" in
        200)
            # Extract username from response
            local username=$(echo "$response_body" | grep -o '"login":"[^"]*"' | cut -d'"' -f4)
            echo "::notice::GitHub API connectivity test successful (authenticated as: $username)"
            return 0
            ;;
        401)
            echo "::error::GitHub API authentication failed - invalid token"
            return 1
            ;;
        403)
            echo "::error::GitHub API access forbidden - check token scopes"
            return 1
            ;;
        *)
            echo "::error::GitHub API returned unexpected status: $http_status"
            return 1
            ;;
    esac
}

# Function to test token connectivity with retries
test_token_connectivity() {
    local claude_oauth_token="$1"
    local github_token="$2"
    local max_retries="${TOKEN_TEST_RETRIES:-3}"
    local retry_delay="${TOKEN_TEST_RETRY_DELAY:-2}"
    
    # Test Claude API connectivity with retries
    local retry_count=0
    while [[ $retry_count -lt $max_retries ]]; do
        if test_claude_api_connectivity "$claude_oauth_token"; then
            break
        fi
        
        retry_count=$((retry_count + 1))
        if [[ $retry_count -lt $max_retries ]]; then
            echo "::warning::Claude API test failed, retrying in ${retry_delay}s (attempt $retry_count/$max_retries)"
            sleep "$retry_delay"
        fi
    done
    
    if [[ $retry_count -eq $max_retries ]]; then
        echo "::error::Claude API connectivity test failed after $max_retries attempts"
        return 1
    fi
    
    # Test GitHub API connectivity with retries
    retry_count=0
    while [[ $retry_count -lt $max_retries ]]; do
        if test_github_api_connectivity "$github_token"; then
            break
        fi
        
        retry_count=$((retry_count + 1))
        if [[ $retry_count -lt $max_retries ]]; then
            echo "::warning::GitHub API test failed, retrying in ${retry_delay}s (attempt $retry_count/$max_retries)"
            sleep "$retry_delay"
        fi
    done
    
    if [[ $retry_count -eq $max_retries ]]; then
        echo "::error::GitHub API connectivity test failed after $max_retries attempts"
        return 1
    fi
    
    echo "::notice::All connectivity tests passed"
}

# Main execution
main() {
    local claude_oauth_token="$1"
    local github_token="$2"
    local test_connectivity="${3:-false}"
    
    validate_claude_token "$claude_oauth_token"
    validate_github_token "$github_token"
    
    if [[ "$test_connectivity" == "true" ]]; then
        test_token_connectivity "$claude_oauth_token" "$github_token"
    fi
    
    echo "::notice::All token validations passed"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi