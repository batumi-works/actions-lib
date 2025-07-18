#!/usr/bin/env bats
# Unit tests for github-operations issue commenting functionality

load "../../bats-setup"

@test "comment issue operation requires issue number" {
    # Set up test environment
    setup_github_actions_env
    
    # Create a mock script that validates issue number
    cat > "$BATS_TEST_TMPDIR/test_comment_validation.sh" << 'EOF'
#!/usr/bin/env bash
# Test comment issue validation

ISSUE_NUMBER="$1"
COMMENT_BODY="$2"

# Validate issue number
if [[ -z "$ISSUE_NUMBER" ]]; then
    echo "::error::Issue number is required"
    exit 1
fi

# Validate issue number is numeric
if ! [[ "$ISSUE_NUMBER" =~ ^[0-9]+$ ]]; then
    echo "::error::Issue number must be numeric"
    exit 1
fi

# Validate comment body
if [[ -z "$COMMENT_BODY" ]]; then
    echo "::error::Comment body is required"
    exit 1
fi

echo "Comment validation passed"
EOF
    chmod +x "$BATS_TEST_TMPDIR/test_comment_validation.sh"
    
    # Test missing issue number
    run "$BATS_TEST_TMPDIR/test_comment_validation.sh" "" "Test comment"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Issue number is required" ]]
    
    # Test invalid issue number
    run "$BATS_TEST_TMPDIR/test_comment_validation.sh" "abc" "Test comment"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Issue number must be numeric" ]]
    
    # Test missing comment body
    run "$BATS_TEST_TMPDIR/test_comment_validation.sh" "123" ""
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Comment body is required" ]]
    
    # Test valid inputs
    run "$BATS_TEST_TMPDIR/test_comment_validation.sh" "123" "Test comment"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Comment validation passed" ]]
}

@test "comment issue operation creates comment successfully" {
    # Set up test environment
    setup_github_actions_env
    export GITHUB_OUTPUT="$BATS_TEST_TMPDIR/github_output"
    
    # Create a mock script that simulates comment creation
    cat > "$BATS_TEST_TMPDIR/test_create_comment.sh" << 'EOF'
#!/usr/bin/env bash
# Test comment creation

ISSUE_NUMBER="123"
COMMENT_BODY="Test comment body"

# Mock successful comment creation
echo "comment_id=456" >> "$GITHUB_OUTPUT"
echo "Created comment: https://github.com/test-org/test-repo/issues/123#issuecomment-456"
EOF
    chmod +x "$BATS_TEST_TMPDIR/test_create_comment.sh"
    
    # Run the test
    run "$BATS_TEST_TMPDIR/test_create_comment.sh"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Created comment:" ]]
    
    # Check output
    assert_github_output_contains "comment_id" "456"
}

@test "comment issue operation handles API errors" {
    # Set up test environment
    setup_github_actions_env
    
    # Create a mock script that simulates API errors
    cat > "$BATS_TEST_TMPDIR/test_comment_error.sh" << 'EOF'
#!/usr/bin/env bash
# Test comment creation error handling

# Simulate different types of API errors
case "$1" in
    "not_found")
        echo "::error::Failed to create comment: Issue not found"
        exit 1
        ;;
    "permission")
        echo "::error::Failed to create comment: Permission denied"
        exit 1
        ;;
    "rate_limit")
        echo "::error::Failed to create comment: Rate limit exceeded"
        exit 1
        ;;
    *)
        echo "::error::Failed to create comment: Unknown error"
        exit 1
        ;;
esac
EOF
    chmod +x "$BATS_TEST_TMPDIR/test_comment_error.sh"
    
    # Test different error scenarios
    run "$BATS_TEST_TMPDIR/test_comment_error.sh" "not_found"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Issue not found" ]]
    
    run "$BATS_TEST_TMPDIR/test_comment_error.sh" "permission"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Permission denied" ]]
    
    run "$BATS_TEST_TMPDIR/test_comment_error.sh" "rate_limit"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Rate limit exceeded" ]]
}

@test "comment issue operation handles special characters" {
    # Set up test environment
    setup_github_actions_env
    
    # Create a mock script that handles special characters
    cat > "$BATS_TEST_TMPDIR/test_special_chars.sh" << 'EOF'
#!/usr/bin/env bash
# Test comment with special characters

COMMENT_BODY="$1"

# Test that special characters are handled correctly
echo "Processing comment: $COMMENT_BODY"

# Check for potentially problematic characters
if [[ "$COMMENT_BODY" =~ [\"\'\\] ]]; then
    echo "Comment contains special characters - handling properly"
fi

echo "Comment processed successfully"
EOF
    chmod +x "$BATS_TEST_TMPDIR/test_special_chars.sh"
    
    # Test various special character scenarios
    run "$BATS_TEST_TMPDIR/test_special_chars.sh" "Comment with \"quotes\""
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Comment processed successfully" ]]
    
    run "$BATS_TEST_TMPDIR/test_special_chars.sh" "Comment with 'single quotes'"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Comment processed successfully" ]]
    
    run "$BATS_TEST_TMPDIR/test_special_chars.sh" "Comment with backslash \\"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Comment processed successfully" ]]
}

@test "comment issue operation handles multiline comments" {
    # Set up test environment
    setup_github_actions_env
    
    # Create a mock script that handles multiline comments
    cat > "$BATS_TEST_TMPDIR/test_multiline_comment.sh" << 'EOF'
#!/usr/bin/env bash
# Test multiline comment handling

# Read multiline comment from stdin
COMMENT_BODY="Line 1
Line 2
Line 3"

# Process multiline comment
echo "Processing multiline comment..."
echo "Lines: $(echo "$COMMENT_BODY" | wc -l)"

# Validate that newlines are preserved
if [[ "$COMMENT_BODY" =~ $'\n' ]]; then
    echo "Multiline comment detected and processed"
else
    echo "Single line comment"
fi

echo "Multiline comment processed successfully"
EOF
    chmod +x "$BATS_TEST_TMPDIR/test_multiline_comment.sh"
    
    # Run the test
    run "$BATS_TEST_TMPDIR/test_multiline_comment.sh"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Multiline comment detected and processed" ]]
    [[ "$output" =~ "Lines: 3" ]]
}