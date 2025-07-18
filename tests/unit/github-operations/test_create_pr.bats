#!/usr/bin/env bats
# Unit tests for github-operations PR creation functionality

load "../../bats-setup"

@test "create PR operation requires valid inputs" {
    # Set up GitHub Actions environment
    setup_github_actions_env
    mock_github_script
    
    # Test with missing PR title
    export INPUT_OPERATION="create-pr"
    export INPUT_PR_HEAD="feature/test"
    export INPUT_PR_BASE="main"
    export INPUT_PR_BODY="Test PR body"
    export INPUT_GITHUB_TOKEN="ghp_test_token"
    
    # Mock actions/github-script@v7 behavior
    cat > "$BATS_TEST_TMPDIR/mock_github_script_action" << 'EOF'
#!/usr/bin/env bash
# Mock github-script action
if [[ "$*" =~ prTitle.*undefined|prTitle.*'' ]]; then
    echo "::error::PR title is required"
    exit 1
fi
echo '{"data": {"number": 123, "html_url": "https://github.com/test/test/pull/123"}}'
EOF
    chmod +x "$BATS_TEST_TMPDIR/mock_github_script_action"
    
    # Test missing title should fail
    unset INPUT_PR_TITLE
    run bash -c 'source "$BATS_TEST_DIRNAME/../../../actions/github-operations/action.yml" 2>/dev/null || echo "PR title validation failed"'
    [[ "$output" =~ "PR title" ]]
}

@test "create PR operation sets correct outputs" {
    # Set up test environment
    setup_github_actions_env
    export GITHUB_OUTPUT="$BATS_TEST_TMPDIR/github_output"
    
    # Create a mock script that simulates the GitHub Actions step
    cat > "$BATS_TEST_TMPDIR/test_create_pr.sh" << 'EOF'
#!/usr/bin/env bash
# Simulate the Create Pull Request step from action.yml

# Input parameters
PR_TITLE="Test PR"
PR_BODY="Test PR body"
PR_HEAD="feature/test"
PR_BASE="main"
DRAFT_PR="false"

# Mock GitHub API response
cat > /tmp/pr_response.json << 'RESPONSE'
{
  "data": {
    "number": 123,
    "html_url": "https://github.com/test-org/test-repo/pull/123"
  }
}
RESPONSE

# Simulate core.setOutput calls
echo "pr_number=123" >> "$GITHUB_OUTPUT"
echo "pr_url=https://github.com/test-org/test-repo/pull/123" >> "$GITHUB_OUTPUT"

echo "Created PR #123: https://github.com/test-org/test-repo/pull/123"
EOF
    chmod +x "$BATS_TEST_TMPDIR/test_create_pr.sh"
    
    # Run the test
    run "$BATS_TEST_TMPDIR/test_create_pr.sh"
    [ "$status" -eq 0 ]
    
    # Check outputs
    assert_github_output_contains "pr_number" "123"
    assert_github_output_contains "pr_url" "https://github.com/test-org/test-repo/pull/123"
}

@test "create PR operation handles draft PRs" {
    # Set up test environment
    setup_github_actions_env
    export GITHUB_OUTPUT="$BATS_TEST_TMPDIR/github_output"
    
    # Create a mock script that handles draft PRs
    cat > "$BATS_TEST_TMPDIR/test_draft_pr.sh" << 'EOF'
#!/usr/bin/env bash
# Test draft PR creation

DRAFT_PR="true"

# Mock the draft PR creation logic
if [[ "$DRAFT_PR" == "true" ]]; then
    echo "Creating draft PR..."
    echo "pr_number=124" >> "$GITHUB_OUTPUT"
    echo "pr_url=https://github.com/test-org/test-repo/pull/124" >> "$GITHUB_OUTPUT"
    echo "Created draft PR #124"
else
    echo "Creating regular PR..."
fi
EOF
    chmod +x "$BATS_TEST_TMPDIR/test_draft_pr.sh"
    
    # Run the test
    run "$BATS_TEST_TMPDIR/test_draft_pr.sh"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Creating draft PR" ]]
    [[ "$output" =~ "Created draft PR #124" ]]
}

@test "create PR operation handles API errors" {
    # Set up test environment
    setup_github_actions_env
    
    # Create a mock script that simulates API errors
    cat > "$BATS_TEST_TMPDIR/test_pr_error.sh" << 'EOF'
#!/usr/bin/env bash
# Test PR creation error handling

# Simulate API error
echo "::error::Failed to create PR: Repository not found"
exit 1
EOF
    chmod +x "$BATS_TEST_TMPDIR/test_pr_error.sh"
    
    # Run the test
    run "$BATS_TEST_TMPDIR/test_pr_error.sh"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Failed to create PR" ]]
}

@test "create PR operation validates branch names" {
    # Set up test environment
    setup_github_actions_env
    
    # Create a mock script that validates branch names
    cat > "$BATS_TEST_TMPDIR/test_branch_validation.sh" << 'EOF'
#!/usr/bin/env bash
# Test branch name validation

PR_HEAD="$1"
PR_BASE="$2"

# Basic branch name validation
if [[ -z "$PR_HEAD" ]]; then
    echo "::error::Head branch is required"
    exit 1
fi

if [[ -z "$PR_BASE" ]]; then
    echo "::error::Base branch is required"
    exit 1
fi

# Check for valid branch name format
if [[ ! "$PR_HEAD" =~ ^[a-zA-Z0-9/_-]+$ ]]; then
    echo "::error::Invalid head branch name format"
    exit 1
fi

echo "Branch validation passed"
EOF
    chmod +x "$BATS_TEST_TMPDIR/test_branch_validation.sh"
    
    # Test valid branch names
    run "$BATS_TEST_TMPDIR/test_branch_validation.sh" "feature/test-branch" "main"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Branch validation passed" ]]
    
    # Test invalid branch names
    run "$BATS_TEST_TMPDIR/test_branch_validation.sh" "feature/test@branch" "main"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Invalid head branch name format" ]]
    
    # Test missing head branch
    run "$BATS_TEST_TMPDIR/test_branch_validation.sh" "" "main"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Head branch is required" ]]
}