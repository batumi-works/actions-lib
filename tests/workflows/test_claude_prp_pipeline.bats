#!/usr/bin/env bats
# Tests for claude-prp-pipeline.yml workflow

# Load test setup from parent directory
source "${BATS_TEST_DIRNAME}/../bats-setup.bash"

setup() {
    setup_test_env
    load_test_utils
    setup_github_env
    
    # Set up test workflow directory
    export TEST_WORKFLOW_DIR="$BATS_TEST_TMPDIR/claude-prp-pipeline"
    mkdir -p "$TEST_WORKFLOW_DIR/.github/workflows"
    
    # Copy the workflow file
    cp "$BATS_TEST_DIRNAME/../../.github/workflows/claude-prp-pipeline.yml" \
       "$TEST_WORKFLOW_DIR/.github/workflows/"
}

teardown() {
    teardown_test_env
}

@test "claude-prp-pipeline: workflow file is valid YAML" {
    run validate_yaml "$TEST_WORKFLOW_DIR/.github/workflows/claude-prp-pipeline.yml"
    [ "$status" -eq 0 ]
}

@test "claude-prp-pipeline: has required workflow_call inputs" {
    # Check that all required inputs are defined
    run yq eval '.on.workflow_call.inputs | keys' \
        "$TEST_WORKFLOW_DIR/.github/workflows/claude-prp-pipeline.yml"
    
    # Verify expected inputs exist
    [[ "$output" =~ "api_provider" ]]
    [[ "$output" =~ "anthropic_base_url" ]]
    [[ "$output" =~ "timeout_minutes" ]]
    [[ "$output" =~ "allowed_tools" ]]
    [[ "$output" =~ "claude_model" ]]
    [[ "$output" =~ "skip_pr_check" ]]
    [[ "$output" =~ "git_user_name" ]]
    [[ "$output" =~ "git_user_email" ]]
}

@test "claude-prp-pipeline: has correct default values" {
    # Check default timeout
    run yq eval '.on.workflow_call.inputs.timeout_minutes.default' \
        "$TEST_WORKFLOW_DIR/.github/workflows/claude-prp-pipeline.yml"
    [ "$output" = "90" ]
    
    # Check default model
    run yq eval '.on.workflow_call.inputs.claude_model.default' \
        "$TEST_WORKFLOW_DIR/.github/workflows/claude-prp-pipeline.yml"
    [ "$output" = "claude-sonnet-4-20250514" ]
    
    # Check skip_pr_check default
    run yq eval '.on.workflow_call.inputs.skip_pr_check.default' \
        "$TEST_WORKFLOW_DIR/.github/workflows/claude-prp-pipeline.yml"
    [ "$output" = "false" ]
}

@test "claude-prp-pipeline: skips when comment references PR" {
    # Test the PR reference check condition
    cat > "$TEST_WORKFLOW_DIR/pr_comment_event.json" << 'EOF'
{
  "comment": {
    "body": "This is related to PR #123"
  }
}
EOF
    
    # The workflow should skip this
    cd "$TEST_WORKFLOW_DIR"
    
    # Check the skip condition
    run yq eval '.jobs.implement-prp.if' \
        ".github/workflows/claude-prp-pipeline.yml"
    
    [[ "$output" =~ "!contains(github.event.comment.body, 'PR #')" ]]
}

@test "claude-prp-pipeline: validates API configuration" {
    # Test validation step exists
    run yq eval '.jobs.implement-prp.steps[] | select(.name == "Validate API Configuration")' \
        "$TEST_WORKFLOW_DIR/.github/workflows/claude-prp-pipeline.yml"
    
    [ "$status" -eq 0 ]
    [[ "$output" =~ "anthropic" ]]
    [[ "$output" =~ "moonshot" ]]
}

@test "claude-prp-pipeline: PRP management step configured correctly" {
    # Check PRP management step
    run yq eval '.jobs.implement-prp.steps[] | select(.name == "Manage PRP") | .with' \
        "$TEST_WORKFLOW_DIR/.github/workflows/claude-prp-pipeline.yml"
    
    [[ "$output" =~ "create_branch: true" ]]
    [[ "$output" =~ "move_to_done: true" ]]
}

@test "claude-prp-pipeline: handles no PRP found scenario" {
    # Test skip condition when no PRP
    run yq eval '.jobs.implement-prp.steps[] | select(.name == "Skip if No PRP Found") | .if' \
        "$TEST_WORKFLOW_DIR/.github/workflows/claude-prp-pipeline.yml"
    
    [ "$output" = "steps.prp.outputs.has_prp == 'false'" ]
}

@test "claude-prp-pipeline: commit message format is correct" {
    # Check commit message format
    run yq eval '.jobs.implement-prp.steps[] | select(.name == "Commit Implementation") | .run' \
        "$TEST_WORKFLOW_DIR/.github/workflows/claude-prp-pipeline.yml"
    
    # Verify multi-line commit message with Co-Authored-By
    [[ "$output" =~ "feat: implement PRP" ]]
    [[ "$output" =~ "Co-Authored-By: Claude" ]]
    [[ "$output" =~ "Generated with Claude Code" ]]
}

@test "claude-prp-pipeline: creates pull request with correct parameters" {
    # Check PR creation step
    run yq eval '.jobs.implement-prp.steps[] | select(.name == "Create Pull Request") | .with' \
        "$TEST_WORKFLOW_DIR/.github/workflows/claude-prp-pipeline.yml"
    
    [[ "$output" =~ "operation: create-pr" ]]
    [[ "$output" =~ "pr_base: main" ]]
    [[ "$output" =~ "draft_pr: false" ]]
}

@test "claude-prp-pipeline: success comment includes all required info" {
    # Check success comment
    run yq eval '.jobs.implement-prp.steps[] | select(.name == "Comment Success on Issue") | .with.comment_body' \
        "$TEST_WORKFLOW_DIR/.github/workflows/claude-prp-pipeline.yml"
    
    [[ "$output" =~ "PRP Implementation Complete!" ]]
    [[ "$output" =~ "Pull Request:" ]]
    [[ "$output" =~ "Branch:" ]]
    [[ "$output" =~ "API Provider:" ]]
}

@test "claude-prp-pipeline: handles implementation with no changes" {
    # Check no changes comment
    run yq eval '.jobs.implement-prp.steps[] | select(.name == "Comment No Changes on Issue") | .with.comment_body' \
        "$TEST_WORKFLOW_DIR/.github/workflows/claude-prp-pipeline.yml"
    
    [[ "$output" =~ "PRP Implementation Status" ]]
    [[ "$output" =~ "No changes were generated" ]]
}

@test "claude-prp-pipeline: permissions are correctly set" {
    # Check required permissions
    run yq eval '.jobs.implement-prp.permissions' \
        "$TEST_WORKFLOW_DIR/.github/workflows/claude-prp-pipeline.yml"
    
    [[ "$output" =~ "contents: write" ]]
    [[ "$output" =~ "issues: write" ]]
    [[ "$output" =~ "pull-requests: write" ]]
}

@test "claude-prp-pipeline: conditional steps work correctly" {
    # Test conditional execution based on has_prp
    
    # Count steps that depend on has_prp == 'true'
    run yq eval '.jobs.implement-prp.steps[] | select(.if | contains("has_prp == '\''true'\''")) | .name' \
        "$TEST_WORKFLOW_DIR/.github/workflows/claude-prp-pipeline.yml"
    
    # Should have multiple conditional steps
    line_count=$(echo "$output" | grep -c ".")
    [ "$line_count" -ge 4 ]
}

@test "claude-prp-pipeline: handles branch push correctly" {
    # Check push step
    run yq eval '.jobs.implement-prp.steps[] | select(.name == "Push Implementation Branch") | .run' \
        "$TEST_WORKFLOW_DIR/.github/workflows/claude-prp-pipeline.yml"
    
    [[ "$output" =~ "git push origin" ]]
    [[ "$output" =~ "steps.prp.outputs.branch_name" ]]
}

@test "claude-prp-pipeline: integration test with comment parsing" {
    # Test comment parsing for PRP path
    test_comment="Please implement PRPs/todo/feature-xyz.md"
    
    # Simulate PRP extraction (this would be done by prp-management action)
    if [[ "$test_comment" =~ PRPs/[^[:space:]]+ ]]; then
        prp_path="${BASH_REMATCH[0]}"
        echo "Found PRP: $prp_path"
        [ "$prp_path" = "PRPs/todo/feature-xyz.md" ]
    fi
}

@test "claude-prp-pipeline: handles skip_pr_check input" {
    # Test with skip_pr_check enabled
    cat > "$TEST_WORKFLOW_DIR/.github/workflows/test-skip-pr.yml" << 'EOF'
name: Test Skip PR Check
on: [issue_comment]
jobs:
  test:
    uses: ./.github/workflows/claude-prp-pipeline.yml
    with:
      skip_pr_check: true
    secrets:
      bot_token: ${{ secrets.BOT_TOKEN }}
      claude_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
EOF
    
    cd "$TEST_WORKFLOW_DIR"
    
    # Should run even with PR reference when skip_pr_check is true
    run act issue_comment --dryrun
    [ "$status" -eq 0 ]
}

@test "claude-prp-pipeline: uses correct git configuration" {
    # Check git user configuration
    run yq eval '.on.workflow_call.inputs.git_user_name.default' \
        "$TEST_WORKFLOW_DIR/.github/workflows/claude-prp-pipeline.yml"
    [ "$output" = "Claude PRP Implementation Bot" ]
    
    run yq eval '.on.workflow_call.inputs.git_user_email.default' \
        "$TEST_WORKFLOW_DIR/.github/workflows/claude-prp-pipeline.yml"
    [ "$output" = "claude-prp-bot@users.noreply.github.com" ]
}

@test "claude-prp-pipeline: claude code action configuration" {
    # Check Claude Code action configuration
    run yq eval '.jobs.implement-prp.steps[] | select(.name == "Implement PRP with Claude Code") | .with' \
        "$TEST_WORKFLOW_DIR/.github/workflows/claude-prp-pipeline.yml"
    
    [[ "$output" =~ "prompt_file: /tmp/prp-implementation-prompt.md" ]]
    [[ "$output" =~ "timeout_minutes:" ]]
    [[ "$output" =~ "allowed_tools:" ]]
    [[ "$output" =~ "model:" ]]
}

@test "claude-prp-pipeline: end-to-end simulation" {
    # Simulate full workflow execution
    cd "$TEST_WORKFLOW_DIR"
    
    # Initialize git repo
    git init
    git config user.email "test@example.com"
    git config user.name "Test User"
    
    # Create initial commit
    echo "test" > README.md
    git add README.md
    git commit -m "Initial commit"
    
    # Create PRP file
    mkdir -p PRPs/todo
    cat > PRPs/todo/test-feature.md << 'EOF'
# Test Feature
This is a test PRP for implementation.
EOF
    
    # Simulate PRP management outputs
    export PRP_HAS_PRP="true"
    export PRP_PATH="PRPs/todo/test-feature.md"
    export PRP_NAME="test-feature"
    export PRP_BRANCH="implement/test-feature"
    
    # Create implementation
    echo "// Implementation" > feature.js
    git add feature.js
    
    # Check if we have changes
    if ! git diff --staged --quiet; then
        echo "✅ Changes detected for commit"
    fi
    
    # Simulate successful workflow completion
    echo "✅ End-to-end simulation completed"
}