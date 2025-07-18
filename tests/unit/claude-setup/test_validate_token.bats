#!/usr/bin/env bats
# Unit tests for claude-setup token validation functionality

load "../../bats-setup"

@test "validate_token script requires Claude OAuth token" {
    # Test without Claude token
    run bash "$BATS_TEST_DIRNAME/../../../actions/claude-setup/scripts/validate_token.sh" "" "ghp_test_token"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Claude OAuth token is required" ]]
}

@test "validate_token script requires GitHub token" {
    # Test without GitHub token
    run bash "$BATS_TEST_DIRNAME/../../../actions/claude-setup/scripts/validate_token.sh" "claude_test_token" ""
    [ "$status" -eq 1 ]
    [[ "$output" =~ "GitHub token is required" ]]
}

@test "validate_token script validates Claude token format" {
    # Test with invalid Claude token format
    run bash "$BATS_TEST_DIRNAME/../../../actions/claude-setup/scripts/validate_token.sh" "invalid@token!" "ghp_test_token"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Invalid Claude OAuth token format" ]]
    
    # Test with valid Claude token format
    run bash "$BATS_TEST_DIRNAME/../../../actions/claude-setup/scripts/validate_token.sh" "claude_test_token_12345" "ghp_test_token"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Claude OAuth token validation passed" ]]
}

@test "validate_token script validates Claude token length" {
    # Test with short Claude token
    run bash "$BATS_TEST_DIRNAME/../../../actions/claude-setup/scripts/validate_token.sh" "short" "ghp_test_token"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Claude OAuth token appears to be too short" ]]
    
    # Test with adequate length token
    run bash "$BATS_TEST_DIRNAME/../../../actions/claude-setup/scripts/validate_token.sh" "long_enough_token" "ghp_test_token"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Claude OAuth token validation passed" ]]
}

@test "validate_token script validates GitHub token format" {
    # Test with invalid GitHub token format
    run bash "$BATS_TEST_DIRNAME/../../../actions/claude-setup/scripts/validate_token.sh" "claude_test_token_12345" "invalid_github_token"
    [ "$status" -eq 0 ]  # Should not fail, just warn
    [[ "$output" =~ "GitHub token format may be invalid" ]]
    
    # Test with valid GitHub token format
    run bash "$BATS_TEST_DIRNAME/../../../actions/claude-setup/scripts/validate_token.sh" "claude_test_token_12345" "ghp_test_token_12345"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "GitHub token validation passed" ]]
}

@test "validate_token script accepts different GitHub token types" {
    local token_types=("ghp_" "gho_" "ghu_" "ghs_" "ghr_")
    
    for prefix in "${token_types[@]}"; do
        run bash "$BATS_TEST_DIRNAME/../../../actions/claude-setup/scripts/validate_token.sh" "claude_test_token_12345" "${prefix}test_token_12345"
        [ "$status" -eq 0 ]
        [[ "$output" =~ "GitHub token validation passed" ]]
    done
}

@test "validate_token script passes all validations" {
    # Test with valid tokens
    run bash "$BATS_TEST_DIRNAME/../../../actions/claude-setup/scripts/validate_token.sh" "claude_test_token_12345" "ghp_test_token_12345"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Claude OAuth token validation passed" ]]
    [[ "$output" =~ "GitHub token validation passed" ]]
    [[ "$output" =~ "All token validations passed" ]]
}

@test "validate_token script handles connectivity testing" {
    # Test with connectivity testing enabled
    run bash "$BATS_TEST_DIRNAME/../../../actions/claude-setup/scripts/validate_token.sh" "claude_test_token_12345" "ghp_test_token_12345" "true"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Token connectivity test skipped (placeholder)" ]]
    
    # Test with connectivity testing disabled (default)
    run bash "$BATS_TEST_DIRNAME/../../../actions/claude-setup/scripts/validate_token.sh" "claude_test_token_12345" "ghp_test_token_12345" "false"
    [ "$status" -eq 0 ]
    [[ "$output" != *"Token connectivity test"* ]]
}

@test "validate_token script handles edge cases" {
    # Test with tokens containing underscores and hyphens
    run bash "$BATS_TEST_DIRNAME/../../../actions/claude-setup/scripts/validate_token.sh" "claude_test-token_12345" "ghp_test-token_12345"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "All token validations passed" ]]
    
    # Test with minimum length tokens
    run bash "$BATS_TEST_DIRNAME/../../../actions/claude-setup/scripts/validate_token.sh" "1234567890" "ghp_1234567890"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "All token validations passed" ]]
}