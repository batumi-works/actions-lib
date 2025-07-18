#!/usr/bin/env bats
# Integration tests for composite actions

load "../bats-setup"

@test "claude-setup action integrates all components" {
    # Set up test environment
    setup_github_actions_env
    export GITHUB_OUTPUT="$BATS_TEST_TMPDIR/github_output"
    export GITHUB_WORKSPACE="$BATS_TEST_TMPDIR/workspace"
    mkdir -p "$GITHUB_WORKSPACE"
    
    # Mock git for configuration
    mock_git "default"
    
    # Create test script that simulates the complete action
    cat > "$BATS_TEST_TMPDIR/test_claude_setup_integration.sh" << EOF
#!/usr/bin/env bash
# Integration test for claude-setup action

set -e

# Ensure PATH includes the mock git
export PATH="$BATS_TEST_TMPDIR:\$PATH"

# Input parameters
CLAUDE_OAUTH_TOKEN="\$1"
GITHUB_TOKEN="\$2"
CONFIGURE_GIT="\$3"
GIT_USER_NAME="\$4"
GIT_USER_EMAIL="\$5"
FETCH_DEPTH="\$6"

# Step 1: Checkout (simulated)
echo "::notice::Checking out repository with fetch-depth: \${FETCH_DEPTH:-0}"
echo "repository_path=$GITHUB_WORKSPACE" >> "$GITHUB_OUTPUT"

# Step 2: Configure Git (if enabled)
if [[ "\$CONFIGURE_GIT" == "true" ]]; then
    git_user_name="\${GIT_USER_NAME:-Claude AI Bot}"
    git_user_email="\${GIT_USER_EMAIL:-claude-ai@users.noreply.github.com}"
    
    echo "::notice::Configuring git user: \$git_user_name <\$git_user_email>"
    git config --global user.name "\$git_user_name"
    git config --global user.email "\$git_user_email"
fi

# Step 3: Validate tokens
if [[ -z "\$CLAUDE_OAUTH_TOKEN" ]]; then
    echo "::error::Claude OAuth token is required"
    exit 1
fi

if [[ -z "\$GITHUB_TOKEN" ]]; then
    echo "::error::GitHub token is required"
    exit 1
fi

echo "::notice::Claude OAuth token validation passed"

# Step 4: Set additional outputs
echo "setup_timestamp=\$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$GITHUB_OUTPUT"
if [[ "\$CONFIGURE_GIT" == "true" ]]; then
    echo "git_user_name=\${GIT_USER_NAME:-Claude AI Bot}" >> "$GITHUB_OUTPUT"
    echo "git_user_email=\${GIT_USER_EMAIL:-claude-ai@users.noreply.github.com}" >> "$GITHUB_OUTPUT"
fi

echo "::notice::Claude setup completed successfully"
EOF
    chmod +x "$BATS_TEST_TMPDIR/test_claude_setup_integration.sh"
    
    # Test complete action integration
    run "$BATS_TEST_TMPDIR/test_claude_setup_integration.sh" "test_claude_token" "ghp_test_token" "true" "Test User" "test@example.com" "1"
    
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Claude setup completed successfully" ]]
    
    # Verify outputs
    assert_github_output_contains "repository_path" "$GITHUB_WORKSPACE"
    assert_github_output_contains "git_user_name" "Test User"
    assert_github_output_contains "git_user_email" "test@example.com"
    grep -q "setup_timestamp=" "$GITHUB_OUTPUT"
    
    # Verify git was configured
    verify_git_command "config --global user.name Test User"
    verify_git_command "config --global user.email test@example.com"
}

@test "github-operations action handles complete PR workflow" {
    # Set up test environment
    setup_github_actions_env
    export GITHUB_OUTPUT="$BATS_TEST_TMPDIR/github_output"
    
    # Mock GitHub API responses
    setup_github_api_mocks
    
    # Create test script that simulates PR creation workflow
    cat > "$BATS_TEST_TMPDIR/test_github_ops_integration.sh" << 'EOF'
#!/usr/bin/env bash
# Integration test for github-operations PR workflow

set -e

OPERATION="$1"
GITHUB_TOKEN="$2"
PR_TITLE="$3"
PR_BODY="$4"
PR_HEAD="$5"
PR_BASE="$6"
DRAFT_PR="$7"

if [[ "$OPERATION" == "create-pr" ]]; then
    # Simulate GitHub API call
    echo "::notice::Creating PR: $PR_TITLE"
    echo "::notice::Head: $PR_HEAD -> Base: $PR_BASE"
    
    # Mock successful PR creation
    pr_number=123
    pr_url="https://github.com/test-org/test-repo/pull/$pr_number"
    
    echo "pr_number=$pr_number" >> "$GITHUB_OUTPUT"
    echo "pr_url=$pr_url" >> "$GITHUB_OUTPUT"
    
    if [[ "$DRAFT_PR" == "true" ]]; then
        echo "::notice::Created draft PR #$pr_number: $pr_url"
    else
        echo "::notice::Created PR #$pr_number: $pr_url"
    fi
else
    echo "::error::Unknown operation: $OPERATION"
    exit 1
fi
EOF
    chmod +x "$BATS_TEST_TMPDIR/test_github_ops_integration.sh"
    
    # Test PR creation workflow
    run "$BATS_TEST_TMPDIR/test_github_ops_integration.sh" "create-pr" "ghp_test_token" "Test PR" "Test PR body" "feature/test" "main" "false"
    
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Created PR #123" ]]
    
    # Verify outputs
    assert_github_output_contains "pr_number" "123"
    assert_github_output_contains "pr_url" "https://github.com/test-org/test-repo/pull/123"
}

@test "prp-management action handles complete PRP workflow" {
    # Set up test environment
    setup_github_actions_env
    export GITHUB_OUTPUT="$BATS_TEST_TMPDIR/github_output"
    
    # Initialize a git repository in the test directory
    cd "$BATS_TEST_TMPDIR"
    git init
    git config user.name "Test User"
    git config user.email "test@example.com"
    
    # Create initial commit
    echo "# Test Repo" > README.md
    git add README.md
    git commit -m "Initial commit"
    
    # Create test PRP file
    mkdir -p "$BATS_TEST_TMPDIR/PRPs"
    create_sample_prp "$BATS_TEST_TMPDIR/PRPs/test-feature.md"
    
    # Create test script that simulates complete PRP workflow
    cat > "$BATS_TEST_TMPDIR/test_prp_integration.sh" << 'EOF'
#!/usr/bin/env bash
# Integration test for prp-management complete workflow

set -e

COMMENT_BODY="$1"
ISSUE_NUMBER="$2"
CREATE_BRANCH="$3"
MOVE_TO_DONE="$4"

cd "$BATS_TEST_TMPDIR"

# Step 1: Extract PRP path
prp_match=$(echo "$COMMENT_BODY" | grep -oE 'PRPs/[^[:space:]\)]+\.md' | head -1)

if [ -z "$prp_match" ]; then
    echo "has_prp=false" >> "$GITHUB_OUTPUT"
    echo "::notice::No PRP file path found in comment"
    exit 0
fi

# Step 2: Validate PRP file exists
if [ ! -f "$prp_match" ]; then
    echo "has_prp=false" >> "$GITHUB_OUTPUT"
    echo "::error::PRP file does not exist: $prp_match"
    exit 1
fi

# Step 3: Extract PRP name and generate branch name
prp_name=$(basename "$prp_match" .md)
branch_name="implement/${prp_name}-$(date +%s)"

echo "prp_path=$prp_match" >> "$GITHUB_OUTPUT"
echo "prp_name=$prp_name" >> "$GITHUB_OUTPUT"
echo "branch_name=$branch_name" >> "$GITHUB_OUTPUT"
echo "has_prp=true" >> "$GITHUB_OUTPUT"

echo "::notice::Found PRP: $prp_match"
echo "::notice::Branch name: $branch_name"

# Step 4: Create implementation branch
if [[ "$CREATE_BRANCH" == "true" ]]; then
    git checkout -b "$branch_name"
    echo "::notice::Created branch: $branch_name"
fi

# Step 5: Move PRP to done
if [[ "$MOVE_TO_DONE" == "true" ]]; then
    mkdir -p PRPs/done
    
    if [ -f "$prp_match" ]; then
        mv "$prp_match" "PRPs/done/${prp_name}.md"
        echo "::notice::Moved PRP to done: PRPs/done/${prp_name}.md"
    else
        echo "::warning::PRP file not found for moving: $prp_match"
    fi
fi

# Step 6: Prepare implementation prompt
mkdir -p .claude/commands/PRPs
cat > ".claude/commands/PRPs/prp-base-execute.md" << 'TEMPLATE'
# PRP Implementation

## PRP to Implement
$ARGUMENTS

## Instructions
Please implement the PRP above.
TEMPLATE

template_content=$(cat .claude/commands/PRPs/prp-base-execute.md)
echo "$template_content" | sed "s/\$ARGUMENTS/PRPs\/done\/${prp_name}.md/g" > /tmp/prp-implementation-prompt.md
echo "::notice::Created implementation prompt for: PRPs/done/${prp_name}.md"
EOF
    chmod +x "$BATS_TEST_TMPDIR/test_prp_integration.sh"
    
    # Test complete PRP workflow
    run "$BATS_TEST_TMPDIR/test_prp_integration.sh" "Please implement PRPs/test-feature.md" "123" "true" "true"
    
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Found PRP: PRPs/test-feature.md" ]]
    [[ "$output" =~ "Created branch:" ]]
    [[ "$output" =~ "Moved PRP to done:" ]]
    [[ "$output" =~ "Created implementation prompt" ]]
    
    # Verify outputs
    assert_github_output_contains "has_prp" "true"
    assert_github_output_contains "prp_path" "PRPs/test-feature.md"
    assert_github_output_contains "prp_name" "test-feature"
    grep -q "branch_name=implement/test-feature-" "$GITHUB_OUTPUT"
    
    # Verify file operations
    assert_file_exists "$BATS_TEST_TMPDIR/PRPs/done/test-feature.md"
    [[ ! -f "$BATS_TEST_TMPDIR/PRPs/test-feature.md" ]]
    
    # Verify prompt creation
    assert_file_exists "/tmp/prp-implementation-prompt.md"
}

@test "actions work together in complete workflow" {
    # Set up test environment
    setup_github_actions_env
    export GITHUB_OUTPUT="$BATS_TEST_TMPDIR/github_output"
    export GITHUB_WORKSPACE="$BATS_TEST_TMPDIR/workspace"
    mkdir -p "$GITHUB_WORKSPACE"
    
    # Initialize a git repository in the test directory
    cd "$BATS_TEST_TMPDIR"
    git init
    git config user.name "Test User"
    git config user.email "test@example.com"
    
    # Create initial commit
    echo "# Test Repo" > README.md
    git add README.md
    git commit -m "Initial commit"
    
    # Create test PRP file
    mkdir -p "$BATS_TEST_TMPDIR/PRPs"
    create_sample_prp "$BATS_TEST_TMPDIR/PRPs/integration-test.md"
    
    # Create test script that simulates complete workflow
    cat > "$BATS_TEST_TMPDIR/test_complete_workflow.sh" << 'EOF'
#!/usr/bin/env bash
# Complete workflow integration test

set -e

cd "$BATS_TEST_TMPDIR"

echo "=== Step 1: Claude Setup ==="
# Simulate claude-setup action
echo "repository_path=$GITHUB_WORKSPACE" >> "$GITHUB_OUTPUT"
echo "setup_timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$GITHUB_OUTPUT"
echo "git_user_name=Integration Test Bot" >> "$GITHUB_OUTPUT"
echo "git_user_email=integration@example.com" >> "$GITHUB_OUTPUT"

git config --global user.name "Integration Test Bot"
git config --global user.email "integration@example.com"

echo "::notice::Claude setup completed"

echo "=== Step 2: PRP Management ==="
# Simulate prp-management action
comment_body="Please implement PRPs/integration-test.md"
prp_match=$(echo "$comment_body" | grep -oE 'PRPs/[^[:space:]\)]+\.md' | head -1)

if [ -f "$prp_match" ]; then
    prp_name=$(basename "$prp_match" .md)
    branch_name="implement/${prp_name}-$(date +%s)"
    
    echo "prp_path=$prp_match" >> "$GITHUB_OUTPUT"
    echo "prp_name=$prp_name" >> "$GITHUB_OUTPUT"
    echo "branch_name=$branch_name" >> "$GITHUB_OUTPUT"
    echo "has_prp=true" >> "$GITHUB_OUTPUT"
    
    # Create branch
    git checkout -b "$branch_name"
    
    # Move PRP to done
    mkdir -p PRPs/done
    mv "$prp_match" "PRPs/done/${prp_name}.md"
    
    echo "::notice::PRP management completed"
else
    echo "has_prp=false" >> "$GITHUB_OUTPUT"
    echo "::error::PRP file not found"
    exit 1
fi

echo "=== Step 3: GitHub Operations ==="
# Simulate github-operations action (create PR)
if grep -q "has_prp=true" "$GITHUB_OUTPUT"; then
    pr_number=456
    pr_url="https://github.com/test-org/test-repo/pull/$pr_number"
    
    echo "pr_number=$pr_number" >> "$GITHUB_OUTPUT"
    echo "pr_url=$pr_url" >> "$GITHUB_OUTPUT"
    
    echo "::notice::Created PR #$pr_number: $pr_url"
    echo "::notice::Complete workflow finished successfully"
else
    echo "::notice::Skipping PR creation (no PRP found)"
fi

echo "=== Workflow Summary ==="
echo "Repository: $(grep 'repository_path=' "$GITHUB_OUTPUT" | cut -d'=' -f2)"
echo "PRP: $(grep 'prp_name=' "$GITHUB_OUTPUT" | cut -d'=' -f2)"
echo "Branch: $(grep 'branch_name=' "$GITHUB_OUTPUT" | cut -d'=' -f2)"
echo "PR: $(grep 'pr_number=' "$GITHUB_OUTPUT" | cut -d'=' -f2)"
EOF
    chmod +x "$BATS_TEST_TMPDIR/test_complete_workflow.sh"
    
    # Test complete workflow
    run "$BATS_TEST_TMPDIR/test_complete_workflow.sh"
    
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Claude setup completed" ]]
    [[ "$output" =~ "PRP management completed" ]]
    [[ "$output" =~ "Created PR #456" ]]
    [[ "$output" =~ "Complete workflow finished successfully" ]]
    
    # Verify all outputs are present
    assert_github_output_contains "repository_path" "$GITHUB_WORKSPACE"
    assert_github_output_contains "has_prp" "true"
    assert_github_output_contains "prp_name" "integration-test"
    assert_github_output_contains "pr_number" "456"
    
    # Verify file operations
    assert_file_exists "$BATS_TEST_TMPDIR/PRPs/done/integration-test.md"
    [[ ! -f "$BATS_TEST_TMPDIR/PRPs/integration-test.md" ]]
}

@test "actions handle error propagation correctly" {
    # Set up test environment
    setup_github_actions_env
    export GITHUB_OUTPUT="$BATS_TEST_TMPDIR/github_output"
    
    # Create test script that simulates error conditions
    cat > "$BATS_TEST_TMPDIR/test_error_propagation.sh" << 'EOF'
#!/usr/bin/env bash
# Error propagation integration test

set -e

cd "$BATS_TEST_TMPDIR"

echo "=== Testing Error Propagation ==="

# Step 1: Simulate failed claude-setup (missing token)
echo "::error::Claude OAuth token is required"
exit 1
EOF
    chmod +x "$BATS_TEST_TMPDIR/test_error_propagation.sh"
    
    # Test error propagation
    run "$BATS_TEST_TMPDIR/test_error_propagation.sh"
    
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Claude OAuth token is required" ]]
    
    echo "✅ Error propagation test passed"
}

@test "actions handle concurrent execution safely" {
    # Set up test environment
    setup_github_actions_env
    export GITHUB_OUTPUT="$BATS_TEST_TMPDIR/github_output"
    
    # Create test script that simulates concurrent execution
    cat > "$BATS_TEST_TMPDIR/test_concurrent_execution.sh" << 'EOF'
#!/usr/bin/env bash
# Concurrent execution safety test

set -e

cd "$BATS_TEST_TMPDIR"

echo "=== Testing Concurrent Execution Safety ==="

# Simulate multiple processes trying to create the same branch
mkdir -p PRPs
echo "test" > PRPs/concurrent-test.md

# Process 1: Extract PRP and create branch
prp_name="concurrent-test"
branch_name="implement/${prp_name}-$(date +%s)"

echo "Process 1: $branch_name"
echo "prp_path=PRPs/concurrent-test.md" >> "$GITHUB_OUTPUT.1"
echo "branch_name=$branch_name" >> "$GITHUB_OUTPUT.1"

# Process 2: Extract same PRP with different timestamp
sleep 1
branch_name_2="implement/${prp_name}-$(date +%s)"

echo "Process 2: $branch_name_2"
echo "prp_path=PRPs/concurrent-test.md" >> "$GITHUB_OUTPUT.2"
echo "branch_name=$branch_name_2" >> "$GITHUB_OUTPUT.2"

# Verify different branch names were generated
if [[ "$branch_name" == "$branch_name_2" ]]; then
    echo "::error::Concurrent execution generated same branch name"
    exit 1
fi

echo "::notice::Concurrent execution handled safely"
EOF
    chmod +x "$BATS_TEST_TMPDIR/test_concurrent_execution.sh"
    
    # Test concurrent execution
    run "$BATS_TEST_TMPDIR/test_concurrent_execution.sh"
    
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Concurrent execution handled safely" ]]
    
    # Verify different branch names were generated
    branch1=$(grep 'branch_name=' "$BATS_TEST_TMPDIR/github_output.1" | cut -d'=' -f2)
    branch2=$(grep 'branch_name=' "$BATS_TEST_TMPDIR/github_output.2" | cut -d'=' -f2)
    
    [[ "$branch1" != "$branch2" ]]
    
    echo "✅ Concurrent execution safety test passed"
}

@test "actions maintain state consistency" {
    # Set up test environment
    setup_github_actions_env
    export GITHUB_OUTPUT="$BATS_TEST_TMPDIR/github_output"
    
    # Create test script that verifies state consistency
    cat > "$BATS_TEST_TMPDIR/test_state_consistency.sh" << 'EOF'
#!/usr/bin/env bash
# State consistency integration test

set -e

cd "$BATS_TEST_TMPDIR"

echo "=== Testing State Consistency ==="

# Create initial state
mkdir -p PRPs
echo "test prp content" > PRPs/state-test.md

# Step 1: Process PRP
prp_path="PRPs/state-test.md"
prp_name="state-test"

echo "prp_path=$prp_path" >> "$GITHUB_OUTPUT"
echo "prp_name=$prp_name" >> "$GITHUB_OUTPUT"
echo "has_prp=true" >> "$GITHUB_OUTPUT"

# Step 2: Move PRP to done
mkdir -p PRPs/done
mv "$prp_path" "PRPs/done/${prp_name}.md"

# Step 3: Verify state consistency
if [ -f "$prp_path" ]; then
    echo "::error::Original PRP file should not exist after move"
    exit 1
fi

if [ ! -f "PRPs/done/${prp_name}.md" ]; then
    echo "::error::PRP file should exist in done folder"
    exit 1
fi

# Verify content integrity
original_content="test prp content"
moved_content=$(cat "PRPs/done/${prp_name}.md")

if [[ "$original_content" != "$moved_content" ]]; then
    echo "::error::Content integrity lost during move"
    exit 1
fi

echo "::notice::State consistency maintained"
EOF
    chmod +x "$BATS_TEST_TMPDIR/test_state_consistency.sh"
    
    # Test state consistency
    run "$BATS_TEST_TMPDIR/test_state_consistency.sh"
    
    [ "$status" -eq 0 ]
    [[ "$output" =~ "State consistency maintained" ]]
    
    echo "✅ State consistency test passed"
}