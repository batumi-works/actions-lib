#!/usr/bin/env bats
# Unit tests for claude-setup checkout functionality

load "../../bats-setup"

# Test the checkout script directly
@test "checkout script requires GitHub token" {
    # Test without token
    run bash "$BATS_TEST_DIRNAME/../../../actions/claude-setup/scripts/checkout.sh" "0" ""
    [ "$status" -eq 1 ]
    [[ "$output" =~ "GitHub token is required" ]]
}

@test "checkout script uses default fetch depth" {
    # Test with token but no fetch depth
    run bash "$BATS_TEST_DIRNAME/../../../actions/claude-setup/scripts/checkout.sh" "" "ghp_test_token"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "fetch-depth: 0" ]]
}

@test "checkout script uses custom fetch depth" {
    # Test with custom fetch depth
    run bash "$BATS_TEST_DIRNAME/../../../actions/claude-setup/scripts/checkout.sh" "1" "ghp_test_token"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "fetch-depth: 1" ]]
}

@test "checkout script sets repository path output" {
    # Set up GitHub output file
    export GITHUB_OUTPUT="$BATS_TEST_TMPDIR/github_output"
    export GITHUB_WORKSPACE="$BATS_TEST_TMPDIR/workspace"
    mkdir -p "$GITHUB_WORKSPACE"
    
    # Test output generation
    run bash "$BATS_TEST_DIRNAME/../../../actions/claude-setup/scripts/checkout.sh" "0" "ghp_test_token"
    [ "$status" -eq 0 ]
    
    # Check output file
    assert_github_output_contains "repository_path" "$GITHUB_WORKSPACE"
}

@test "checkout script works in GitHub Actions environment" {
    # Set up GitHub Actions environment
    export GITHUB_ACTIONS="true"
    export GITHUB_WORKSPACE="$BATS_TEST_TMPDIR/workspace"
    export GITHUB_OUTPUT="$BATS_TEST_TMPDIR/github_output"
    mkdir -p "$GITHUB_WORKSPACE"
    
    # Test in GitHub Actions environment
    run bash "$BATS_TEST_DIRNAME/../../../actions/claude-setup/scripts/checkout.sh" "0" "ghp_test_token"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Repository checked out successfully" ]]
}

@test "checkout script works in local environment" {
    # Set up local environment (no GITHUB_ACTIONS)
    unset GITHUB_ACTIONS
    export GITHUB_OUTPUT="$BATS_TEST_TMPDIR/github_output"
    
    # Test in local environment
    run bash "$BATS_TEST_DIRNAME/../../../actions/claude-setup/scripts/checkout.sh" "0" "ghp_test_token"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Repository checked out successfully" ]]
    
    # Check that local path is used
    assert_github_output_contains "repository_path" "$(pwd)"
}