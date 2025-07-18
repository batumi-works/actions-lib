#!/usr/bin/env bash
# GitHub-specific mock functions for testing

# Mock GitHub Script action
mock_github_script() {
    local operation="$1"
    local response_file="$2"
    
    cat > "$BATS_TEST_TMPDIR/mock_github_script" << EOF
#!/usr/bin/env bash
# Mock GitHub Script implementation

# Log the call
echo "github-script called with: \$*" >> "$BATS_TEST_TMPDIR/mock_github_script_calls"

# Parse the operation from the script content
if [[ "\$*" == *"create-pr"* ]]; then
    cat << 'RESPONSE'
{
  "data": {
    "number": 123,
    "html_url": "https://github.com/test-org/test-repo/pull/123",
    "id": 12345
  }
}
RESPONSE
elif [[ "\$*" == *"comment-issue"* ]]; then
    cat << 'RESPONSE'
{
  "data": {
    "id": 456,
    "html_url": "https://github.com/test-org/test-repo/issues/1#issuecomment-456"
  }
}
RESPONSE
elif [[ "\$*" == *"check-bot-status"* ]]; then
    cat << 'RESPONSE'
{
  "data": [
    {
      "id": 789,
      "user": {
        "login": "other-user"
      },
      "body": "Some comment",
      "created_at": "2024-01-01T00:00:00Z"
    }
  ]
}
RESPONSE
else
    echo "Unknown operation in mock github-script"
    exit 1
fi
EOF
    
    chmod +x "$BATS_TEST_TMPDIR/mock_github_script"
    export PATH="$BATS_TEST_TMPDIR:$PATH"
}

# Mock GitHub API responses
setup_github_api_mocks() {
    # Create mock responses directory
    mkdir -p "$BATS_TEST_TMPDIR/mock_responses"
    
    # Mock PR creation response
    cat > "$BATS_TEST_TMPDIR/mock_responses/create_pr.json" << 'EOF'
{
  "data": {
    "number": 123,
    "html_url": "https://github.com/test-org/test-repo/pull/123",
    "id": 12345,
    "title": "Test PR",
    "body": "Test PR body",
    "head": {
      "ref": "feature/test"
    },
    "base": {
      "ref": "main"
    }
  }
}
EOF
    
    # Mock issue comment response
    cat > "$BATS_TEST_TMPDIR/mock_responses/create_comment.json" << 'EOF'
{
  "data": {
    "id": 456,
    "html_url": "https://github.com/test-org/test-repo/issues/1#issuecomment-456",
    "body": "Test comment",
    "user": {
      "login": "test-user"
    }
  }
}
EOF
    
    # Mock issue comments list response
    cat > "$BATS_TEST_TMPDIR/mock_responses/list_comments.json" << 'EOF'
{
  "data": [
    {
      "id": 789,
      "user": {
        "login": "other-user"
      },
      "body": "Some comment",
      "created_at": "2024-01-01T00:00:00Z"
    },
    {
      "id": 790,
      "user": {
        "login": "Claude AI Bot"
      },
      "body": "Bot comment",
      "created_at": "2024-01-02T00:00:00Z"
    }
  ]
}
EOF
    
    # Mock issue details response
    cat > "$BATS_TEST_TMPDIR/mock_responses/get_issue.json" << 'EOF'
{
  "data": {
    "number": 123,
    "title": "Test Issue",
    "body": "Test issue body",
    "user": {
      "login": "test-user"
    },
    "created_at": "2024-01-01T00:00:00Z"
  }
}
EOF
}

# Mock GitHub CLI (gh) commands
mock_github_cli() {
    cat > "$BATS_TEST_TMPDIR/mock_gh" << 'EOF'
#!/usr/bin/env bash
# Mock GitHub CLI implementation

# Log the call
echo "gh called with: $*" >> "$BATS_TEST_TMPDIR/mock_gh_calls"

case "$1" in
    "pr")
        case "$2" in
            "create")
                echo "https://github.com/test-org/test-repo/pull/123"
                ;;
            "list")
                echo "123	Test PR	feature/test	OPEN"
                ;;
        esac
        ;;
    "issue")
        case "$2" in
            "comment")
                echo "https://github.com/test-org/test-repo/issues/1#issuecomment-456"
                ;;
            "list")
                echo "123	Test Issue	OPEN"
                ;;
        esac
        ;;
    "api")
        # Mock API responses based on endpoint
        if [[ "$*" == *"pulls"* ]]; then
            cat "$BATS_TEST_TMPDIR/mock_responses/create_pr.json"
        elif [[ "$*" == *"issues/comments"* ]]; then
            cat "$BATS_TEST_TMPDIR/mock_responses/list_comments.json"
        elif [[ "$*" == *"issues"* ]]; then
            cat "$BATS_TEST_TMPDIR/mock_responses/get_issue.json"
        fi
        ;;
    *)
        echo "Unknown gh command: $*"
        exit 1
        ;;
esac
EOF
    
    chmod +x "$BATS_TEST_TMPDIR/mock_gh"
    export PATH="$BATS_TEST_TMPDIR:$PATH"
}

# Set up GitHub Actions environment variables
setup_github_actions_env() {
    export GITHUB_ACTIONS=true
    export GITHUB_WORKSPACE="$BATS_TEST_TMPDIR/workspace"
    export GITHUB_OUTPUT="$BATS_TEST_TMPDIR/github_output"
    export GITHUB_STEP_SUMMARY="$BATS_TEST_TMPDIR/step_summary"
    export GITHUB_ENV="$BATS_TEST_TMPDIR/github_env"
    export GITHUB_PATH="$BATS_TEST_TMPDIR/github_path"
    
    # Create workspace directory
    mkdir -p "$GITHUB_WORKSPACE"
    
    # Initialize output files
    touch "$GITHUB_OUTPUT"
    touch "$GITHUB_STEP_SUMMARY"
    touch "$GITHUB_ENV"
    touch "$GITHUB_PATH"
}

# Mock GitHub Actions core functions
mock_github_actions_core() {
    cat > "$BATS_TEST_TMPDIR/mock_core" << 'EOF'
#!/usr/bin/env bash
# Mock GitHub Actions core functions

case "$1" in
    "setOutput")
        echo "$2" >> "$GITHUB_OUTPUT"
        ;;
    "setFailed")
        echo "::error::$2"
        exit 1
        ;;
    "notice")
        echo "::notice::$2"
        ;;
    "warning")
        echo "::warning::$2"
        ;;
    "error")
        echo "::error::$2"
        ;;
    *)
        echo "Unknown core function: $1"
        ;;
esac
EOF
    
    chmod +x "$BATS_TEST_TMPDIR/mock_core"
    export PATH="$BATS_TEST_TMPDIR:$PATH"
}

# Verify GitHub output was set correctly
verify_github_output() {
    local key="$1"
    local expected_value="$2"
    local output_file="${GITHUB_OUTPUT:-$BATS_TEST_TMPDIR/github_output}"
    
    if ! grep -q "^${key}=" "$output_file"; then
        echo "GitHub output key '$key' not found"
        return 1
    fi
    
    local actual_value
    actual_value=$(grep "^${key}=" "$output_file" | cut -d'=' -f2-)
    
    if [[ "$actual_value" != "$expected_value" ]]; then
        echo "Expected '$expected_value', got '$actual_value'"
        return 1
    fi
}

# Clean up GitHub-specific mocks
cleanup_github_mocks() {
    rm -f "$BATS_TEST_TMPDIR"/mock_gh*
    rm -f "$BATS_TEST_TMPDIR"/mock_core
    rm -rf "$BATS_TEST_TMPDIR/mock_responses"
}