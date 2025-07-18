#!/usr/bin/env bats
# Unit tests for claude-setup output generation functionality

load "../../bats-setup"

@test "set_output script uses default repository path" {
    # Set up environment
    export GITHUB_WORKSPACE="$BATS_TEST_TMPDIR/workspace"
    export GITHUB_OUTPUT="$BATS_TEST_TMPDIR/github_output"
    mkdir -p "$GITHUB_WORKSPACE"
    
    # Test with default path
    run bash "$BATS_TEST_DIRNAME/../../../actions/claude-setup/scripts/set_output.sh"
    [ "$status" -eq 0 ]
    
    # Check output
    assert_github_output_contains "repository_path" "$GITHUB_WORKSPACE"
}

@test "set_output script uses custom repository path" {
    # Set up environment
    export GITHUB_OUTPUT="$BATS_TEST_TMPDIR/github_output"
    local custom_path="$BATS_TEST_TMPDIR/custom_workspace"
    mkdir -p "$custom_path"
    
    # Test with custom path
    run bash "$BATS_TEST_DIRNAME/../../../actions/claude-setup/scripts/set_output.sh" "$custom_path"
    [ "$status" -eq 0 ]
    
    # Check output
    assert_github_output_contains "repository_path" "$custom_path"
}

@test "set_output script fails for non-existent path" {
    # Set up environment
    export GITHUB_OUTPUT="$BATS_TEST_TMPDIR/github_output"
    local non_existent_path="$BATS_TEST_TMPDIR/non_existent"
    
    # Test with non-existent path
    run bash "$BATS_TEST_DIRNAME/../../../actions/claude-setup/scripts/set_output.sh" "$non_existent_path"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Repository path does not exist" ]]
}

@test "set_output script sets git user outputs" {
    # Set up environment
    export GITHUB_OUTPUT="$BATS_TEST_TMPDIR/github_output"
    local test_path="$BATS_TEST_TMPDIR/workspace"
    mkdir -p "$test_path"
    
    # Test with git user info
    run bash "$BATS_TEST_DIRNAME/../../../actions/claude-setup/scripts/set_output.sh" "$test_path" "Test User" "test@example.com"
    [ "$status" -eq 0 ]
    
    # Check outputs
    assert_github_output_contains "repository_path" "$test_path"
    assert_github_output_contains "git_user_name" "Test User"
    assert_github_output_contains "git_user_email" "test@example.com"
}

@test "set_output script sets timestamp" {
    # Set up environment
    export GITHUB_OUTPUT="$BATS_TEST_TMPDIR/github_output"
    local test_path="$BATS_TEST_TMPDIR/workspace"
    mkdir -p "$test_path"
    
    # Test timestamp generation
    run bash "$BATS_TEST_DIRNAME/../../../actions/claude-setup/scripts/set_output.sh" "$test_path"
    [ "$status" -eq 0 ]
    
    # Check that timestamp is set
    grep -q "setup_timestamp=" "$GITHUB_OUTPUT"
    
    # Check timestamp format (ISO 8601)
    local timestamp
    timestamp=$(grep "setup_timestamp=" "$GITHUB_OUTPUT" | cut -d'=' -f2)
    [[ "$timestamp" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]
}

@test "set_output script handles empty git user info" {
    # Set up environment
    export GITHUB_OUTPUT="$BATS_TEST_TMPDIR/github_output"
    local test_path="$BATS_TEST_TMPDIR/workspace"
    mkdir -p "$test_path"
    
    # Test with empty git user info
    run bash "$BATS_TEST_DIRNAME/../../../actions/claude-setup/scripts/set_output.sh" "$test_path" "" ""
    [ "$status" -eq 0 ]
    
    # Check that repository path is still set
    assert_github_output_contains "repository_path" "$test_path"
    
    # Check that git user info is not set
    ! grep -q "git_user_name=" "$GITHUB_OUTPUT"
    ! grep -q "git_user_email=" "$GITHUB_OUTPUT"
}

@test "set_output script handles partial git user info" {
    # Set up environment
    export GITHUB_OUTPUT="$BATS_TEST_TMPDIR/github_output"
    local test_path="$BATS_TEST_TMPDIR/workspace"
    mkdir -p "$test_path"
    
    # Test with only user name
    run bash "$BATS_TEST_DIRNAME/../../../actions/claude-setup/scripts/set_output.sh" "$test_path" "Test User" ""
    [ "$status" -eq 0 ]
    
    # Check outputs
    assert_github_output_contains "git_user_name" "Test User"
    ! grep -q "git_user_email=" "$GITHUB_OUTPUT"
    
    # Reset and test with only email
    rm -f "$GITHUB_OUTPUT"
    run bash "$BATS_TEST_DIRNAME/../../../actions/claude-setup/scripts/set_output.sh" "$test_path" "" "test@example.com"
    [ "$status" -eq 0 ]
    
    # Check outputs
    assert_github_output_contains "git_user_email" "test@example.com"
    ! grep -q "git_user_name=" "$GITHUB_OUTPUT"
}

@test "set_output script creates output file if missing" {
    # Set up environment without output file
    export GITHUB_OUTPUT="$BATS_TEST_TMPDIR/github_output"
    local test_path="$BATS_TEST_TMPDIR/workspace"
    mkdir -p "$test_path"
    
    # Ensure output file doesn't exist
    rm -f "$GITHUB_OUTPUT"
    
    # Test output generation
    run bash "$BATS_TEST_DIRNAME/../../../actions/claude-setup/scripts/set_output.sh" "$test_path"
    [ "$status" -eq 0 ]
    
    # Check that output file was created
    assert_file_exists "$GITHUB_OUTPUT"
    assert_github_output_contains "repository_path" "$test_path"
}