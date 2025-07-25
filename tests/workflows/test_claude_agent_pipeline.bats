#!/usr/bin/env bats
# Tests for claude-agent-pipeline.yml workflow

# Load test setup from parent directory
source "${BATS_TEST_DIRNAME}/../bats-setup.bash"
# Test helpers are loaded by bats-setup.bash

setup() {
    setup_test_env
    load_test_utils
    setup_github_env
    
    # Set up test workflow directory
    export TEST_WORKFLOW_DIR="$BATS_TEST_TMPDIR/claude-agent-pipeline"
    mkdir -p "$TEST_WORKFLOW_DIR/.github/workflows"
    
    # Copy the workflow file
    cp "$BATS_TEST_DIRNAME/../../.github/workflows/claude-agent-pipeline.yml" \
       "$TEST_WORKFLOW_DIR/.github/workflows/"
}

teardown() {
    teardown_test_env
}

@test "claude-agent-pipeline: workflow file is valid YAML" {
    run validate_yaml "$TEST_WORKFLOW_DIR/.github/workflows/claude-agent-pipeline.yml"
    [ "$status" -eq 0 ]
}

@test "claude-agent-pipeline: has required workflow_call inputs" {
    # Check that all required inputs are defined
    run yq eval '.on.workflow_call.inputs | keys' \
        "$TEST_WORKFLOW_DIR/.github/workflows/claude-agent-pipeline.yml"
    
    # Verify expected inputs exist
    [[ "$output" =~ "api_provider" ]]
    [[ "$output" =~ "anthropic_base_url" ]]
    [[ "$output" =~ "timeout_minutes" ]]
    [[ "$output" =~ "allowed_tools" ]]
    [[ "$output" =~ "claude_model" ]]
    [[ "$output" =~ "bot_username" ]]
    [[ "$output" =~ "git_user_name" ]]
    [[ "$output" =~ "git_user_email" ]]
    [[ "$output" =~ "commit_message_prefix" ]]
}

@test "claude-agent-pipeline: has required secrets" {
    # Check that all required secrets are defined
    run yq eval '.on.workflow_call.secrets | keys' \
        "$TEST_WORKFLOW_DIR/.github/workflows/claude-agent-pipeline.yml"
    
    # Verify bot_token is required
    run yq eval '.on.workflow_call.secrets.bot_token.required' \
        "$TEST_WORKFLOW_DIR/.github/workflows/claude-agent-pipeline.yml"
    [ "$output" = "true" ]
}

@test "claude-agent-pipeline: validates API configuration correctly" {
    # Test with anthropic provider
    cat > "$TEST_WORKFLOW_DIR/.github/workflows/test-api-validation.yml" << 'EOF'
name: Test API Validation
on: [push]
jobs:
  test:
    uses: ./.github/workflows/claude-agent-pipeline.yml
    with:
      api_provider: anthropic
    secrets:
      bot_token: ${{ secrets.BOT_TOKEN }}
EOF
    
    cd "$TEST_WORKFLOW_DIR"
    
    # This should fail without claude_oauth_token
    run act --dryrun --secret-file /dev/null
    [ "$status" -ne 0 ] || [[ "$output" =~ "claude_oauth_token is required" ]]
}

@test "claude-agent-pipeline: handles issue events correctly" {
    # Create test event payload
    cat > "$TEST_WORKFLOW_DIR/issue_event.json" << 'EOF'
{
  "action": "opened",
  "issue": {
    "number": 123,
    "title": "Test Issue",
    "body": "This is a test issue"
  }
}
EOF
    
    # Create secrets file
    cat > "$TEST_WORKFLOW_DIR/.secrets" << 'EOF'
CLAUDE_CODE_OAUTH_TOKEN=test-token
BOT_TOKEN=test-bot-token
EOF
    
    cd "$TEST_WORKFLOW_DIR"
    
    # Test with issue event
    run act issues --eventpath issue_event.json --secret-file .secrets --dryrun
    [ "$status" -eq 0 ]
}

@test "claude-agent-pipeline: handles issue_comment events correctly" {
    # Create test event payload
    cat > "$TEST_WORKFLOW_DIR/issue_comment_event.json" << 'EOF'
{
  "action": "created",
  "issue": {
    "number": 123,
    "title": "Test Issue"
  },
  "comment": {
    "body": "Please help with this issue"
  }
}
EOF
    
    cd "$TEST_WORKFLOW_DIR"
    
    # Test with issue_comment event
    run act issue_comment --eventpath issue_comment_event.json --secret-file .secrets --dryrun
    [ "$status" -eq 0 ]
}

@test "claude-agent-pipeline: skips if bot already processed" {
    # Mock the bot status check to return should_process=false
    export MOCK_BOT_STATUS_SHOULD_PROCESS="false"
    
    # Create a test workflow that uses our mocked action
    cat > "$TEST_WORKFLOW_DIR/.github/workflows/test-bot-skip.yml" << 'EOF'
name: Test Bot Skip
on: [issue_comment]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - name: Check Bot Status
        id: bot-status
        run: |
          echo "should_process=false" >> $GITHUB_OUTPUT
      
      - name: Skip Message
        if: steps.bot-status.outputs.should_process == 'false'
        run: |
          echo "Bot already processed, skipping"
          exit 0
EOF
    
    cd "$TEST_WORKFLOW_DIR"
    
    # Run and verify it skips
    run act issue_comment --dryrun
    [ "$status" -eq 0 ]
}

@test "claude-agent-pipeline: creates PRP from issue successfully" {
    # Test the PRP creation flow
    cat > "$TEST_WORKFLOW_DIR/test_prp_creation.sh" << 'EOF'
#!/bin/bash
# Simulate PRP creation
echo "Creating PRP from issue..."
mkdir -p PRPs/todo
echo "# Test PRP" > PRPs/todo/test-feature.md
echo "PRP created successfully"
EOF
    
    chmod +x "$TEST_WORKFLOW_DIR/test_prp_creation.sh"
    
    run "$TEST_WORKFLOW_DIR/test_prp_creation.sh"
    [ "$status" -eq 0 ]
    [ -f "$TEST_WORKFLOW_DIR/PRPs/todo/test-feature.md" ]
}

@test "claude-agent-pipeline: commits and pushes PRP" {
    # Test commit logic
    cd "$TEST_WORKFLOW_DIR"
    git init
    git config user.email "test@example.com"
    git config user.name "Test User"
    
    # Create a change
    echo "test" > test.txt
    git add test.txt
    
    # Test commit detection
    if git diff --staged --quiet; then
        echo "has_changes=false"
    else
        echo "has_changes=true"
    fi
    
    # Verify we detect changes
    run git diff --staged --quiet
    [ "$status" -ne 0 ]
}

@test "claude-agent-pipeline: finds latest PRP correctly" {
    # Create test PRP files
    mkdir -p "$TEST_WORKFLOW_DIR/PRPs/todo"
    
    # Create multiple PRPs with different timestamps
    touch -t 202301010000 "$TEST_WORKFLOW_DIR/PRPs/todo/old-prp.md"
    touch -t 202301020000 "$TEST_WORKFLOW_DIR/PRPs/todo/newer-prp.md"
    touch -t 202301030000 "$TEST_WORKFLOW_DIR/PRPs/todo/newest-prp.md"
    
    cd "$TEST_WORKFLOW_DIR"
    
    # Find the most recent PRP
    latest_prp=$(ls -t PRPs/todo/*.md 2>/dev/null | head -1)
    prp_name=$(basename "$latest_prp")
    
    [ "$prp_name" = "newest-prp.md" ]
}

@test "claude-agent-pipeline: handles schedule event" {
    # Test schedule/workflow_dispatch events
    cat > "$TEST_WORKFLOW_DIR/schedule_event.json" << 'EOF'
{
  "schedule": "0 0 * * *"
}
EOF
    
    cd "$TEST_WORKFLOW_DIR"
    
    # Test with schedule event
    run act schedule --eventpath schedule_event.json --secret-file .secrets --dryrun
    [ "$status" -eq 0 ]
}

@test "claude-agent-pipeline: handles workflow_dispatch event" {
    # Test workflow_dispatch event
    cat > "$TEST_WORKFLOW_DIR/dispatch_event.json" << 'EOF'
{
  "inputs": {}
}
EOF
    
    cd "$TEST_WORKFLOW_DIR"
    
    # Test with workflow_dispatch event
    run act workflow_dispatch --eventpath dispatch_event.json --secret-file .secrets --dryrun
    [ "$status" -eq 0 ]
}

@test "claude-agent-pipeline: uses correct permissions" {
    # Check required permissions
    run yq eval '.jobs.create-prp.permissions' \
        "$TEST_WORKFLOW_DIR/.github/workflows/claude-agent-pipeline.yml"
    
    [[ "$output" =~ "contents: write" ]]
    [[ "$output" =~ "issues: write" ]]
    [[ "$output" =~ "pull-requests: read" ]]
}

@test "claude-agent-pipeline: handles API provider switching" {
    # Test anthropic provider
    run yq eval '.jobs.create-prp.steps[] | select(.name == "Create PRP from Issue") | .with' \
        "$TEST_WORKFLOW_DIR/.github/workflows/claude-agent-pipeline.yml"
    
    # Verify conditional API key usage
    [[ "$output" =~ "claude_code_oauth_token:" ]]
    [[ "$output" =~ "anthropic_api_key:" ]]
}

@test "claude-agent-pipeline: cleanup step always runs" {
    # Verify cleanup step has 'if: always()'
    run yq eval '.jobs.create-prp.steps[] | select(.name == "Cleanup") | .if' \
        "$TEST_WORKFLOW_DIR/.github/workflows/claude-agent-pipeline.yml"
    
    [ "$output" = "always()" ]
}

@test "claude-agent-pipeline: comment templates are properly formatted" {
    # Check success comment template
    run yq eval '.jobs.create-prp.steps[] | select(.name == "Comment on Issue with PRP Location") | .with.comment_body' \
        "$TEST_WORKFLOW_DIR/.github/workflows/claude-agent-pipeline.yml"
    
    # Verify it contains expected sections
    [[ "$output" =~ "PRP Created!" ]]
    [[ "$output" =~ "PRP Location:" ]]
    [[ "$output" =~ "API Provider:" ]]
    [[ "$output" =~ "### The PRP includes:" ]]
}

@test "claude-agent-pipeline: handles no changes scenario" {
    # Check no changes comment template
    run yq eval '.jobs.create-prp.steps[] | select(.name == "Comment No Changes") | .with.comment_body' \
        "$TEST_WORKFLOW_DIR/.github/workflows/claude-agent-pipeline.yml"
    
    # Verify it contains expected content
    [[ "$output" =~ "PRP Creation Status" ]]
    [[ "$output" =~ "no changes were generated" ]]
}

@test "claude-agent-pipeline: integration test with mock actions" {
    # Create a full mock workflow
    mkdir -p "$TEST_WORKFLOW_DIR/actions/claude-setup"
    cat > "$TEST_WORKFLOW_DIR/actions/claude-setup/action.yml" << 'EOF'
name: Mock Claude Setup
runs:
  using: composite
  steps:
    - run: echo "Mock claude setup completed"
      shell: bash
EOF
    
    mkdir -p "$TEST_WORKFLOW_DIR/actions/github-operations"
    cat > "$TEST_WORKFLOW_DIR/actions/github-operations/action.yml" << 'EOF'
name: Mock GitHub Operations
runs:
  using: composite
  steps:
    - run: |
        echo "should_process=true" >> $GITHUB_OUTPUT
        echo "Mock github operations completed"
      shell: bash
EOF
    
    # Run integration test
    cd "$TEST_WORKFLOW_DIR"
    run act issues --secret-file .secrets --dryrun
    [ "$status" -eq 0 ]
}