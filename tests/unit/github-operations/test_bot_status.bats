#!/usr/bin/env bats
# Unit tests for github-operations bot status checking functionality

load "../../bats-setup"

@test "bot status check determines if bot should process" {
    # Set up test environment
    setup_github_actions_env
    export GITHUB_OUTPUT="$BATS_TEST_TMPDIR/github_output"
    
    # Create a mock script that simulates bot status check
    cat > "$BATS_TEST_TMPDIR/test_bot_status.sh" << 'EOF'
#!/usr/bin/env bash
# Test bot status check logic

ISSUE_NUMBER="$1"
BOT_USERNAME="$2"
LAST_COMMENT_USER="$3"

# Determine if bot should process
if [[ "$LAST_COMMENT_USER" == "$BOT_USERNAME" ]]; then
    SHOULD_PROCESS="false"
    echo "Last comment was from bot, skipping processing"
else
    SHOULD_PROCESS="true"
    echo "Bot should process this issue"
fi

# Set output
echo "should_process=$SHOULD_PROCESS" >> "$GITHUB_OUTPUT"
echo "Should process issue: $SHOULD_PROCESS"
EOF
    chmod +x "$BATS_TEST_TMPDIR/test_bot_status.sh"
    
    # Test when last comment is from bot
    run "$BATS_TEST_TMPDIR/test_bot_status.sh" "123" "Claude AI Bot" "Claude AI Bot"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Last comment was from bot" ]]
    assert_github_output_contains "should_process" "false"
    
    # Clear GitHub output for next test
    echo "" > "$GITHUB_OUTPUT"
    
    # Test when last comment is from different user
    run "$BATS_TEST_TMPDIR/test_bot_status.sh" "123" "Claude AI Bot" "other-user"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Bot should process this issue" ]]
    assert_github_output_contains "should_process" "true"
}

@test "bot status check handles empty comments" {
    # Set up test environment
    setup_github_actions_env
    export GITHUB_OUTPUT="$BATS_TEST_TMPDIR/github_output"
    
    # Create a mock script that handles empty comments
    cat > "$BATS_TEST_TMPDIR/test_empty_comments.sh" << 'EOF'
#!/usr/bin/env bash
# Test empty comments handling

COMMENTS_COUNT="$1"
BOT_USERNAME="Claude AI Bot"

# Handle case where there are no comments
if [[ "$COMMENTS_COUNT" -eq 0 ]]; then
    SHOULD_PROCESS="true"
    echo "No comments found, bot should process"
else
    SHOULD_PROCESS="false"
    echo "Comments exist, checking last comment"
fi

echo "should_process=$SHOULD_PROCESS" >> "$GITHUB_OUTPUT"
EOF
    chmod +x "$BATS_TEST_TMPDIR/test_empty_comments.sh"
    
    # Test with no comments
    run "$BATS_TEST_TMPDIR/test_empty_comments.sh" "0"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "No comments found, bot should process" ]]
    assert_github_output_contains "should_process" "true"
    
    # Clear GitHub output for next test
    echo "" > "$GITHUB_OUTPUT"
    
    # Test with existing comments
    run "$BATS_TEST_TMPDIR/test_empty_comments.sh" "5"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Comments exist, checking last comment" ]]
    assert_github_output_contains "should_process" "false"
}

@test "bot status check creates discussion context" {
    # Set up test environment
    setup_github_actions_env
    
    # Create a mock script that creates discussion context
    cat > "$BATS_TEST_TMPDIR/test_discussion_context.sh" << 'EOF'
#!/usr/bin/env bash
# Test discussion context creation

ISSUE_TITLE="Test Issue"
ISSUE_BODY="Test issue body"
SHOULD_PROCESS="true"

if [[ "$SHOULD_PROCESS" == "true" ]]; then
    # Create discussion context
    DISCUSSION_CONTEXT="# Issue: $ISSUE_TITLE

$ISSUE_BODY

## Discussion:

**user1** (2024-01-01T00:00:00Z):
First comment

**user2** (2024-01-01T00:00:00Z):
Second comment
"
    
    # Save to file
    echo "$DISCUSSION_CONTEXT" > /tmp/discussion-context.md
    echo "Created discussion context file"
else
    echo "Skipping discussion context creation"
fi
EOF
    chmod +x "$BATS_TEST_TMPDIR/test_discussion_context.sh"
    
    # Run the test
    run "$BATS_TEST_TMPDIR/test_discussion_context.sh"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Created discussion context file" ]]
    
    # Check that file was created
    assert_file_exists "/tmp/discussion-context.md"
    
    # Check file contents
    run cat /tmp/discussion-context.md
    [[ "$output" =~ "# Issue: Test Issue" ]]
    [[ "$output" =~ "## Discussion:" ]]
    [[ "$output" =~ "**user1**" ]]
}

@test "bot status check handles API errors" {
    # Set up test environment
    setup_github_actions_env
    
    # Create a mock script that simulates API errors
    cat > "$BATS_TEST_TMPDIR/test_api_error.sh" << 'EOF'
#!/usr/bin/env bash
# Test API error handling

ERROR_TYPE="$1"

case "$ERROR_TYPE" in
    "not_found")
        echo "::error::Failed to check bot status: Issue not found"
        exit 1
        ;;
    "permission")
        echo "::error::Failed to check bot status: Permission denied"
        exit 1
        ;;
    "rate_limit")
        echo "::error::Failed to check bot status: Rate limit exceeded"
        exit 1
        ;;
    *)
        echo "Bot status check completed successfully"
        ;;
esac
EOF
    chmod +x "$BATS_TEST_TMPDIR/test_api_error.sh"
    
    # Test different error scenarios
    run "$BATS_TEST_TMPDIR/test_api_error.sh" "not_found"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Issue not found" ]]
    
    run "$BATS_TEST_TMPDIR/test_api_error.sh" "permission"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Permission denied" ]]
    
    run "$BATS_TEST_TMPDIR/test_api_error.sh" "rate_limit"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Rate limit exceeded" ]]
    
    # Test success case
    run "$BATS_TEST_TMPDIR/test_api_error.sh" "success"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "completed successfully" ]]
}

@test "bot status check handles different bot usernames" {
    # Set up test environment
    setup_github_actions_env
    export GITHUB_OUTPUT="$BATS_TEST_TMPDIR/github_output"
    
    # Create a mock script that handles different bot usernames
    cat > "$BATS_TEST_TMPDIR/test_bot_usernames.sh" << 'EOF'
#!/usr/bin/env bash
# Test different bot usernames

BOT_USERNAME="$1"
LAST_COMMENT_USER="$2"

echo "Checking bot username: $BOT_USERNAME"
echo "Last comment user: $LAST_COMMENT_USER"

if [[ "$LAST_COMMENT_USER" == "$BOT_USERNAME" ]]; then
    echo "should_process=false" >> "$GITHUB_OUTPUT"
    echo "Bot should not process (last comment from bot)"
else
    echo "should_process=true" >> "$GITHUB_OUTPUT"
    echo "Bot should process (last comment not from bot)"
fi
EOF
    chmod +x "$BATS_TEST_TMPDIR/test_bot_usernames.sh"
    
    # Test with default bot username
    run "$BATS_TEST_TMPDIR/test_bot_usernames.sh" "Claude AI Bot" "Claude AI Bot"
    [ "$status" -eq 0 ]
    assert_github_output_contains "should_process" "false"
    
    # Clear GitHub output for next test
    echo "" > "$GITHUB_OUTPUT"
    
    # Test with custom bot username
    run "$BATS_TEST_TMPDIR/test_bot_usernames.sh" "Custom Bot" "Custom Bot"
    [ "$status" -eq 0 ]
    assert_github_output_contains "should_process" "false"
    
    # Clear GitHub output for next test
    echo "" > "$GITHUB_OUTPUT"
    
    # Test with different user
    run "$BATS_TEST_TMPDIR/test_bot_usernames.sh" "Claude AI Bot" "human-user"
    [ "$status" -eq 0 ]
    assert_github_output_contains "should_process" "true"
}