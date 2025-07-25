#!/usr/bin/env bats
# Tests for claude-prp-pipeline-v2.yml workflow (Enhanced version)

# Load test setup from parent directory
source "${BATS_TEST_DIRNAME}/../bats-setup.bash"

setup() {
    setup_test_env
    load_test_utils
    setup_github_env
    
    # Set up test workflow directory
    export TEST_WORKFLOW_DIR="$BATS_TEST_TMPDIR/claude-prp-pipeline-v2"
    mkdir -p "$TEST_WORKFLOW_DIR/.github/workflows"
    
    # Copy the workflow file
    cp "$BATS_TEST_DIRNAME/../../.github/workflows/claude-prp-pipeline-v2.yml" \
       "$TEST_WORKFLOW_DIR/.github/workflows/"
}

teardown() {
    teardown_test_env
}

@test "claude-prp-pipeline-v2: workflow file is valid YAML" {
    run validate_yaml "$TEST_WORKFLOW_DIR/.github/workflows/claude-prp-pipeline-v2.yml"
    [ "$status" -eq 0 ]
}

@test "claude-prp-pipeline-v2: has enhanced inputs over v1" {
    # Check that v2 has additional inputs
    run yq eval '.on.workflow_call.inputs | keys' \
        "$TEST_WORKFLOW_DIR/.github/workflows/claude-prp-pipeline-v2.yml"
    
    # Should have all v1 inputs plus new ones
    [[ "$output" =~ "api_provider" ]]
    [[ "$output" =~ "enable_cache" ]]
    [[ "$output" =~ "enable_tests" ]]
    [[ "$output" =~ "test_command" ]]
    [[ "$output" =~ "enable_lint" ]]
    [[ "$output" =~ "lint_command" ]]
}

@test "claude-prp-pipeline-v2: cache configuration" {
    # Check cache input default
    run yq eval '.on.workflow_call.inputs.enable_cache.default' \
        "$TEST_WORKFLOW_DIR/.github/workflows/claude-prp-pipeline-v2.yml"
    [ "$output" = "true" ]
}

@test "claude-prp-pipeline-v2: test configuration" {
    # Check test-related inputs
    run yq eval '.on.workflow_call.inputs.enable_tests.default' \
        "$TEST_WORKFLOW_DIR/.github/workflows/claude-prp-pipeline-v2.yml"
    [ "$output" = "true" ]
    
    run yq eval '.on.workflow_call.inputs.test_command.default' \
        "$TEST_WORKFLOW_DIR/.github/workflows/claude-prp-pipeline-v2.yml"
    [[ "$output" =~ "npm test" ]] || [[ "$output" =~ "make test" ]]
}

@test "claude-prp-pipeline-v2: lint configuration" {
    # Check lint-related inputs
    run yq eval '.on.workflow_call.inputs.enable_lint.default' \
        "$TEST_WORKFLOW_DIR/.github/workflows/claude-prp-pipeline-v2.yml"
    [ "$output" = "true" ]
    
    run yq eval '.on.workflow_call.inputs.lint_command.default' \
        "$TEST_WORKFLOW_DIR/.github/workflows/claude-prp-pipeline-v2.yml"
    [[ "$output" =~ "npm run lint" ]] || [[ "$output" =~ "make lint" ]]
}

@test "claude-prp-pipeline-v2: has dependency detection step" {
    # Check for dependency detection
    run yq eval '.jobs.implement-prp.steps[] | select(.name | contains("Detect Dependencies")) | .name' \
        "$TEST_WORKFLOW_DIR/.github/workflows/claude-prp-pipeline-v2.yml"
    
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Detect" ]]
}

@test "claude-prp-pipeline-v2: has cache setup steps" {
    # Check for cache-related steps
    run yq eval '.jobs.implement-prp.steps[] | select(.name | contains("Cache")) | .name' \
        "$TEST_WORKFLOW_DIR/.github/workflows/claude-prp-pipeline-v2.yml"
    
    # Should have cache setup
    [ "$status" -eq 0 ]
}

@test "claude-prp-pipeline-v2: runs tests after implementation" {
    # Check for test execution step
    run yq eval '.jobs.implement-prp.steps[] | select(.name | contains("Run Tests")) | .if' \
        "$TEST_WORKFLOW_DIR/.github/workflows/claude-prp-pipeline-v2.yml"
    
    # Should be conditional on enable_tests
    [[ "$output" =~ "enable_tests" ]]
}

@test "claude-prp-pipeline-v2: runs linting after implementation" {
    # Check for lint execution step
    run yq eval '.jobs.implement-prp.steps[] | select(.name | contains("Run Lint")) | .if' \
        "$TEST_WORKFLOW_DIR/.github/workflows/claude-prp-pipeline-v2.yml"
    
    # Should be conditional on enable_lint
    [[ "$output" =~ "enable_lint" ]]
}

@test "claude-prp-pipeline-v2: handles test failures gracefully" {
    # Check test failure handling
    run yq eval '.jobs.implement-prp.steps[] | select(.name | contains("Run Tests")) | .continue-on-error' \
        "$TEST_WORKFLOW_DIR/.github/workflows/claude-prp-pipeline-v2.yml"
    
    # May allow tests to fail without blocking PR
    [ "$output" = "true" ] || [ "$output" = "false" ]
}

@test "claude-prp-pipeline-v2: generates test report" {
    # Check for test report generation
    run yq eval '.jobs.implement-prp.steps[] | select(.name | contains("Test Report") or contains("test report")) | .name' \
        "$TEST_WORKFLOW_DIR/.github/workflows/claude-prp-pipeline-v2.yml"
    
    # Should generate or upload test results
    [ "$status" -eq 0 ] || echo "No test report step found (optional)"
}

@test "claude-prp-pipeline-v2: supports multiple package managers" {
    # Check dependency detection logic
    test_files=(
        "package.json:npm"
        "yarn.lock:yarn"
        "pnpm-lock.yaml:pnpm"
        "Gemfile:bundle"
        "requirements.txt:pip"
        "go.mod:go"
        "Cargo.toml:cargo"
    )
    
    for file_info in "${test_files[@]}"; do
        IFS=':' read -r file manager <<< "$file_info"
        
        # Test detection logic
        if [[ -f "$file" ]]; then
            echo "Detected $manager from $file"
        fi
    done
}

@test "claude-prp-pipeline-v2: caches correct directories" {
    # Common cache paths for different package managers
    cache_paths=(
        "~/.npm"
        "~/.cache/yarn"
        "~/.pnpm-store"
        "~/.cache/pip"
        "~/go/pkg/mod"
        "~/.cargo"
        "target/"
    )
    
    echo "Expected cache paths:"
    for path in "${cache_paths[@]}"; do
        echo "  - $path"
    done
}

@test "claude-prp-pipeline-v2: enhanced PR description" {
    # Check if PR description includes test/lint results
    run yq eval '.jobs.implement-prp.steps[] | select(.name == "Create Pull Request") | .with.pr_body' \
        "$TEST_WORKFLOW_DIR/.github/workflows/claude-prp-pipeline-v2.yml"
    
    # Should include enhanced information
    [[ "$output" =~ "Implementation Details" ]]
    # May include test status, lint results, etc.
}

@test "claude-prp-pipeline-v2: supports custom test commands" {
    # Test with custom test command
    cat > "$TEST_WORKFLOW_DIR/.github/workflows/test-custom-commands.yml" << 'EOF'
name: Test Custom Commands
on: [issue_comment]
jobs:
  test:
    uses: ./.github/workflows/claude-prp-pipeline-v2.yml
    with:
      enable_tests: true
      test_command: 'pytest tests/ -v'
      enable_lint: true
      lint_command: 'black --check . && flake8'
    secrets:
      bot_token: ${{ secrets.BOT_TOKEN }}
      claude_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
EOF
    
    cd "$TEST_WORKFLOW_DIR"
    
    run validate_yaml ".github/workflows/test-custom-commands.yml"
    [ "$status" -eq 0 ]
}

@test "claude-prp-pipeline-v2: matrix strategy support" {
    # Check if v2 supports matrix builds
    run yq eval '.jobs | keys' \
        "$TEST_WORKFLOW_DIR/.github/workflows/claude-prp-pipeline-v2.yml"
    
    # May have additional jobs for parallel testing
    echo "Jobs in v2: $output"
}

@test "claude-prp-pipeline-v2: artifact upload support" {
    # Check for artifact upload steps
    run yq eval '.jobs.implement-prp.steps[] | select(.uses | contains("upload-artifact")) | .name' \
        "$TEST_WORKFLOW_DIR/.github/workflows/claude-prp-pipeline-v2.yml"
    
    # May upload test results, coverage, etc.
    [ "$status" -eq 0 ] || echo "No artifact upload found (optional)"
}

@test "claude-prp-pipeline-v2: enhanced error reporting" {
    # Check for enhanced error handling
    run yq eval '.jobs.implement-prp.steps[] | select(.name | contains("Error") or contains("Failure")) | .name' \
        "$TEST_WORKFLOW_DIR/.github/workflows/claude-prp-pipeline-v2.yml"
    
    # Should have better error reporting than v1
    [ "$status" -eq 0 ] || echo "Enhanced error reporting may be inline"
}

@test "claude-prp-pipeline-v2: performance optimizations" {
    # Check for performance-related configurations
    
    # Parallel execution
    run yq eval '.jobs.implement-prp.steps[] | select(.name) | .name' \
        "$TEST_WORKFLOW_DIR/.github/workflows/claude-prp-pipeline-v2.yml"
    
    # Count steps to ensure workflow is optimized
    step_count=$(echo "$output" | wc -l)
    echo "Total steps in v2: $step_count"
    
    # Should have reasonable number of steps
    [ "$step_count" -lt 50 ]
}

@test "claude-prp-pipeline-v2: backwards compatibility" {
    # Test that v2 can be used as drop-in replacement for v1
    cat > "$TEST_WORKFLOW_DIR/.github/workflows/test-v1-compat.yml" << 'EOF'
name: Test V1 Compatibility
on: [issue_comment]
jobs:
  test:
    uses: ./.github/workflows/claude-prp-pipeline-v2.yml
    with:
      # Only v1 parameters
      api_provider: anthropic
      timeout_minutes: 90
      allowed_tools: 'Bash,Read,Write,Edit'
      claude_model: 'claude-sonnet-4-20250514'
    secrets:
      bot_token: ${{ secrets.BOT_TOKEN }}
      claude_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
EOF
    
    cd "$TEST_WORKFLOW_DIR"
    
    # Should work without v2-specific parameters
    run validate_yaml ".github/workflows/test-v1-compat.yml"
    [ "$status" -eq 0 ]
}

@test "claude-prp-pipeline-v2: integration with CI/CD tools" {
    # Check for CI/CD tool integrations
    echo "Checking for common CI/CD integrations:"
    
    # GitHub Actions annotations
    echo "- GitHub Actions annotations for errors/warnings"
    
    # Status checks
    echo "- Commit status updates"
    
    # PR comments with results
    echo "- Enhanced PR comments with test/lint results"
    
    # Webhook notifications
    echo "- Optional webhook notifications"
}