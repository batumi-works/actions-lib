#!/usr/bin/env bash
# Common test helper functions for GitHub Actions testing

# Assert that a file exists
assert_file_exists() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        echo "Expected file to exist: $file"
        return 1
    fi
}

# Assert that a directory exists
assert_dir_exists() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        echo "Expected directory to exist: $dir"
        return 1
    fi
}

# Assert that a string contains substring
assert_contains() {
    local string="$1"
    local substring="$2"
    if [[ "$string" != *"$substring"* ]]; then
        echo "Expected '$string' to contain '$substring'"
        return 1
    fi
}

# Assert that a string does not contain substring
assert_not_contains() {
    local string="$1"
    local substring="$2"
    if [[ "$string" == *"$substring"* ]]; then
        echo "Expected '$string' to not contain '$substring'"
        return 1
    fi
}

# Assert that GitHub output contains key=value
assert_github_output_contains() {
    local key="$1"
    local expected_value="$2"
    local output_file="${GITHUB_OUTPUT:-/tmp/github_output}"
    
    if [[ ! -f "$output_file" ]]; then
        echo "GitHub output file not found: $output_file"
        return 1
    fi
    
    local actual_value
    actual_value=$(grep "^${key}=" "$output_file" | cut -d'=' -f2-)
    
    if [[ "$actual_value" != "$expected_value" ]]; then
        echo "Expected GitHub output '$key' to be '$expected_value', got '$actual_value'"
        return 1
    fi
}

# Create a temporary git repository for testing
create_test_repo() {
    local repo_dir="${1:-$BATS_TEST_TMPDIR/test_repo}"
    mkdir -p "$repo_dir"
    cd "$repo_dir"
    
    git init
    git config user.name "Test User"
    git config user.email "test@example.com"
    
    # Create initial commit
    echo "# Test Repository" > README.md
    git add README.md
    git commit -m "Initial commit"
    
    echo "$repo_dir"
}

# Create a sample PRP file for testing
create_sample_prp() {
    local prp_path="${1:-$BATS_TEST_TMPDIR/sample.md}"
    local prp_dir=$(dirname "$prp_path")
    mkdir -p "$prp_dir"
    
    cat > "$prp_path" << 'EOF'
# Sample PRP: Test Feature Implementation

## Overview
This is a sample PRP file for testing purposes.

## Requirements
- Implement test feature
- Add proper error handling
- Include unit tests

## Implementation Plan
1. Create new module
2. Add functionality
3. Write tests
4. Update documentation

## Acceptance Criteria
- [ ] Feature works as expected
- [ ] Tests pass
- [ ] Documentation updated
EOF
    
    echo "$prp_path"
}

# Run command and capture both stdout and stderr
run_with_stderr() {
    local cmd="$1"
    local output_file="$BATS_TEST_TMPDIR/command_output"
    local error_file="$BATS_TEST_TMPDIR/command_error"
    
    eval "$cmd" > "$output_file" 2> "$error_file"
    local exit_code=$?
    
    export captured_output=$(cat "$output_file")
    export captured_error=$(cat "$error_file")
    export captured_exit_code=$exit_code
    
    return $exit_code
}

# Mock external command
mock_command() {
    local command_name="$1"
    local mock_behavior="$2"
    local mock_file="$BATS_TEST_TMPDIR/mock_$command_name"
    
    cat > "$mock_file" << EOF
#!/usr/bin/env bash
$mock_behavior
EOF
    chmod +x "$mock_file"
    
    # Add to PATH
    export PATH="$(dirname "$mock_file"):$PATH"
}

# Verify mock was called
verify_mock_called() {
    local command_name="$1"
    local call_log="$BATS_TEST_TMPDIR/mock_${command_name}_calls"
    
    if [[ ! -f "$call_log" ]]; then
        echo "Mock $command_name was not called"
        return 1
    fi
    
    local call_count=$(wc -l < "$call_log")
    if [[ $call_count -eq 0 ]]; then
        echo "Mock $command_name was not called"
        return 1
    fi
}

# Get mock call arguments
get_mock_calls() {
    local command_name="$1"
    local call_log="$BATS_TEST_TMPDIR/mock_${command_name}_calls"
    
    if [[ -f "$call_log" ]]; then
        cat "$call_log"
    fi
}

# Clean up mock files
cleanup_mocks() {
    rm -f "$BATS_TEST_TMPDIR"/mock_*
}