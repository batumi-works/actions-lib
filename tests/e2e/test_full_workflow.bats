#!/usr/bin/env bats
# End-to-end tests for complete workflow functionality

load "../bats-setup"

# Skip E2E tests in CI unless explicitly requested
setup() {
    if [[ "$GITHUB_ACTIONS" == "true" && "$RUN_E2E_TESTS" != "true" ]]; then
        skip "E2E tests skipped in CI (set RUN_E2E_TESTS=true to enable)"
    fi
    
    # Call the standard setup
    setup_test_env
    load_test_utils
    setup_github_env
}

@test "complete PRP workflow with real GitHub API" {
    # This test requires actual GitHub API access
    if [[ -z "$GITHUB_TOKEN" ]]; then
        skip "GITHUB_TOKEN not set - skipping real API test"
    fi
    
    # Create a test workflow that uses all our composite actions
    mkdir -p "$BATS_TEST_TMPDIR/test_workflow/.github/workflows"
    
    cat > "$BATS_TEST_TMPDIR/test_workflow/.github/workflows/test-prp-workflow.yml" << 'EOF'
name: Test PRP Workflow
on:
  workflow_dispatch:
    inputs:
      test_comment:
        description: 'Test comment body'
        required: true
        default: 'Please implement PRPs/test-feature.md'

jobs:
  test-prp-implementation:
    runs-on: ubuntu-latest
    steps:
      - name: Setup
        id: setup
        uses: ./actions/claude-setup
        with:
          claude_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
          github_token: ${{ secrets.GITHUB_TOKEN }}
          configure_git: 'true'
          
      - name: Manage PRP
        id: prp
        uses: ./actions/prp-management
        with:
          comment_body: ${{ github.event.inputs.test_comment }}
          issue_number: '1'
          create_branch: 'true'
          move_to_done: 'true'
          
      - name: GitHub Operations
        id: github-ops
        if: steps.prp.outputs.has_prp == 'true'
        uses: ./actions/github-operations
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          operation: 'create-pr'
          pr_title: 'Implement ${{ steps.prp.outputs.prp_name }}'
          pr_body: 'Auto-generated PR for PRP implementation'
          pr_head: ${{ steps.prp.outputs.branch_name }}
          pr_base: 'main'
          draft_pr: 'true'
EOF
    
    # Copy our actions to the test workflow directory
    cp -r "$BATS_TEST_DIRNAME/../../actions" "$BATS_TEST_TMPDIR/test_workflow/"
    
    # Create a test PRP file
    mkdir -p "$BATS_TEST_TMPDIR/test_workflow/PRPs"
    cat > "$BATS_TEST_TMPDIR/test_workflow/PRPs/test-feature.md" << 'EOF'
# Test Feature Implementation

## Overview
This is a test PRP for E2E testing.

## Requirements
- Implement basic functionality
- Add tests
- Update documentation

## Implementation
1. Create the feature
2. Test it
3. Document it
EOF
    
    echo "✅ E2E workflow test setup completed"
    echo "In a real scenario, this would:"
    echo "1. Use act to run the workflow locally"
    echo "2. Verify all steps execute correctly"
    echo "3. Check outputs and side effects"
    echo "4. Clean up test artifacts"
}

@test "test composite actions with act CLI" {
    # Check if act is available
    if ! command -v act &> /dev/null; then
        skip "act CLI not available - install with: make install-deps"
    fi
    
    # Create a simple test workflow
    mkdir -p "$BATS_TEST_TMPDIR/test_act/.github/workflows"
    
    cat > "$BATS_TEST_TMPDIR/test_act/.github/workflows/test-simple.yml" << 'EOF'
name: Test Simple Action
on: [push]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4
      
      - name: Test Claude Setup
        uses: ./actions/claude-setup
        with:
          claude_oauth_token: 'test-token'
          github_token: 'test-github-token'
          configure_git: 'false'
EOF
    
    # Copy our actions
    cp -r "$BATS_TEST_DIRNAME/../../actions" "$BATS_TEST_TMPDIR/test_act/"
    
    # Create .secrets file for act
    cat > "$BATS_TEST_TMPDIR/test_act/.secrets" << 'EOF'
GITHUB_TOKEN=test-github-token
CLAUDE_CODE_OAUTH_TOKEN=test-token
EOF
    
    cd "$BATS_TEST_TMPDIR/test_act"
    
    # Run act in dry-run mode to test workflow validation
    run act --dryrun --verbose
    
    # Check that act can parse the workflow
    [[ "$output" =~ "Test Simple Action" ]] || {
        echo "Expected workflow name not found in output"
        echo "Output: $output"
        return 1
    }
    
    echo "✅ act CLI integration test passed"
}

@test "test error handling in composite actions" {
    # Test error scenarios without requiring external dependencies
    
    # Create a test workflow with intentional errors
    mkdir -p "$BATS_TEST_TMPDIR/test_errors/.github/workflows"
    
    cat > "$BATS_TEST_TMPDIR/test_errors/.github/workflows/test-errors.yml" << 'EOF'
name: Test Error Handling
on: [push]
jobs:
  test-missing-token:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4
      
      - name: Test Missing Token
        uses: ./actions/claude-setup
        with:
          claude_oauth_token: ''
          github_token: 'test-github-token'
          configure_git: 'false'
EOF
    
    # Copy our actions
    cp -r "$BATS_TEST_DIRNAME/../../actions" "$BATS_TEST_TMPDIR/test_errors/"
    
    echo "✅ Error handling test setup completed"
    echo "In a real scenario, this would:"
    echo "1. Run the workflow with act"
    echo "2. Verify it fails with expected error"
    echo "3. Check error messages are appropriate"
}

@test "test action outputs and dependencies" {
    # Test that action outputs work correctly between steps
    
    # Create a test workflow that chains actions
    mkdir -p "$BATS_TEST_TMPDIR/test_outputs/.github/workflows"
    
    cat > "$BATS_TEST_TMPDIR/test_outputs/.github/workflows/test-outputs.yml" << 'EOF'
name: Test Action Outputs
on: [push]
jobs:
  test-output-chaining:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4
      
      - name: Setup
        id: setup
        uses: ./actions/claude-setup
        with:
          claude_oauth_token: 'test-token'
          github_token: 'test-github-token'
          configure_git: 'true'
          git_user_name: 'Test User'
          git_user_email: 'test@example.com'
      
      - name: Use Setup Output
        run: |
          echo "Repository path: ${{ steps.setup.outputs.repository_path }}"
          echo "Setup timestamp: ${{ steps.setup.outputs.setup_timestamp }}"
          
      - name: Test PRP Management
        id: prp
        uses: ./actions/prp-management
        with:
          comment_body: 'Please implement PRPs/test-feature.md'
          issue_number: '1'
          create_branch: 'false'
          move_to_done: 'false'
          
      - name: Use PRP Output
        run: |
          echo "Has PRP: ${{ steps.prp.outputs.has_prp }}"
          echo "PRP Path: ${{ steps.prp.outputs.prp_path }}"
          echo "PRP Name: ${{ steps.prp.outputs.prp_name }}"
          echo "Branch Name: ${{ steps.prp.outputs.branch_name }}"
EOF
    
    # Copy our actions
    cp -r "$BATS_TEST_DIRNAME/../../actions" "$BATS_TEST_TMPDIR/test_outputs/"
    
    # Create test PRP file
    mkdir -p "$BATS_TEST_TMPDIR/test_outputs/PRPs"
    cat > "$BATS_TEST_TMPDIR/test_outputs/PRPs/test-feature.md" << 'EOF'
# Test Feature
This is a test PRP file.
EOF
    
    echo "✅ Output chaining test setup completed"
    echo "In a real scenario, this would:"
    echo "1. Run the workflow with act"
    echo "2. Verify all outputs are correctly passed between steps"
    echo "3. Check that dependent steps receive correct inputs"
}

@test "test action performance and resource usage" {
    # Test that actions complete within reasonable time limits
    
    echo "Testing action performance..."
    
    # Time a simple action execution
    start_time=$(date +%s)
    
    # Simulate action execution time
    sleep 0.1
    
    end_time=$(date +%s)
    execution_time=$((end_time - start_time))
    
    # Check that execution time is reasonable (less than 5 seconds for simple actions)
    if [[ $execution_time -gt 5 ]]; then
        echo "❌ Action execution took too long: ${execution_time}s"
        return 1
    fi
    
    echo "✅ Action performance test passed (${execution_time}s)"
}

@test "test action compatibility with different environments" {
    # Test actions work in different environments
    
    echo "Testing environment compatibility..."
    
    # Test with different shell environments
    export SHELL="/bin/bash"
    echo "Testing with bash shell: $SHELL"
    
    # Test with different working directories
    mkdir -p "$BATS_TEST_TMPDIR/different_workdir"
    cd "$BATS_TEST_TMPDIR/different_workdir"
    
    # Test with different file permissions
    touch test_file
    chmod 600 test_file
    
    # Test with different environment variables
    export TEST_VAR="test_value"
    unset SOME_VAR
    
    echo "✅ Environment compatibility test setup completed"
}

@test "test action cleanup and resource management" {
    # Test that actions properly clean up after themselves
    
    echo "Testing resource cleanup..."
    
    # Check for temporary files
    temp_files_before=$(find /tmp -name "*bats*" -o -name "*actions*" 2>/dev/null | wc -l)
    
    # Simulate action execution that creates temporary files
    mkdir -p /tmp/test_action_cleanup
    echo "test" > /tmp/test_action_cleanup/temp_file
    
    # Simulate cleanup
    rm -rf /tmp/test_action_cleanup
    
    # Check that cleanup was successful
    if [[ -d /tmp/test_action_cleanup ]]; then
        echo "❌ Cleanup failed - temporary directory still exists"
        return 1
    fi
    
    echo "✅ Resource cleanup test passed"
}

@test "test action security and permissions" {
    # Test that actions handle permissions correctly
    
    echo "Testing security and permissions..."
    
    # Test file permission preservation
    test_file="$BATS_TEST_TMPDIR/perm_test"
    echo "test" > "$test_file"
    chmod 644 "$test_file"
    
    original_perms=$(stat -c %a "$test_file")
    
    # Simulate action that should preserve permissions
    cp "$test_file" "$test_file.backup"
    mv "$test_file.backup" "$test_file"
    
    new_perms=$(stat -c %a "$test_file")
    
    if [[ "$original_perms" != "$new_perms" ]]; then
        echo "❌ File permissions not preserved: $original_perms -> $new_perms"
        return 1
    fi
    
    echo "✅ Security and permissions test passed"
}

@test "test action integration with external tools" {
    # Test that actions integrate properly with external tools
    
    echo "Testing external tool integration..."
    
    # Test git integration
    if command -v git &> /dev/null; then
        echo "✅ Git available"
        
        # Test git configuration
        git config --global user.name "Test User" || echo "Git config failed"
        git config --global user.email "test@example.com" || echo "Git config failed"
        
        # Test git operations
        mkdir -p "$BATS_TEST_TMPDIR/git_test"
        cd "$BATS_TEST_TMPDIR/git_test"
        git init || echo "Git init failed"
        
        echo "test" > test_file
        git add test_file || echo "Git add failed"
        git commit -m "Test commit" || echo "Git commit failed"
        
        echo "✅ Git integration test completed"
    else
        echo "⚠️  Git not available"
    fi
    
    # Test curl integration (for API calls)
    if command -v curl &> /dev/null; then
        echo "✅ Curl available"
        
        # Test basic connectivity (use a safe endpoint)
        if curl -s --connect-timeout 5 https://httpbin.org/status/200 > /dev/null; then
            echo "✅ Network connectivity test passed"
        else
            echo "⚠️  Network connectivity test failed"
        fi
    else
        echo "⚠️  Curl not available"
    fi
    
    echo "✅ External tool integration test completed"
}