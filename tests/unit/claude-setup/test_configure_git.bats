#!/usr/bin/env bats
# Unit tests for claude-setup git configuration functionality

load "../../bats-setup"

@test "configure_git script uses default values" {
    # Mock git command
    mock_git "default"
    
    # Test with defaults
    run bash "$BATS_TEST_DIRNAME/../../../actions/claude-setup/scripts/configure_git.sh" "" "" "true"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Claude AI Bot" ]]
    [[ "$output" =~ "claude-ai@users.noreply.github.com" ]]
    
    # Verify git was called correctly
    verify_git_command "config --global user.name Claude AI Bot"
    verify_git_command "config --global user.email claude-ai@users.noreply.github.com"
}

@test "configure_git script uses custom values" {
    # Mock git command
    mock_git "default"
    
    # Test with custom values
    run bash "$BATS_TEST_DIRNAME/../../../actions/claude-setup/scripts/configure_git.sh" "Custom User" "custom@example.com" "true"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Custom User" ]]
    [[ "$output" =~ "custom@example.com" ]]
    
    # Verify git was called correctly
    verify_git_command "config --global user.name Custom User"
    verify_git_command "config --global user.email custom@example.com"
}

@test "configure_git script skips when disabled" {
    # Mock git command
    mock_git "default"
    
    # Test with configuration disabled
    run bash "$BATS_TEST_DIRNAME/../../../actions/claude-setup/scripts/configure_git.sh" "Test User" "test@example.com" "false"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Git configuration skipped" ]]
    
    # Verify git was not called
    [ ! -f "$BATS_TEST_TMPDIR/mock_git_calls" ]
}

@test "configure_git script handles git config failure" {
    # Mock git command to fail
    mock_git "config_fail"
    
    # Test with git config failure
    run bash "$BATS_TEST_DIRNAME/../../../actions/claude-setup/scripts/configure_git.sh" "Test User" "test@example.com" "true"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Failed to configure git user name" ]]
}

@test "configure_git script validates configuration" {
    # Mock git command with validation
    cat > "$BATS_TEST_TMPDIR/mock_git" << 'EOF'
#!/usr/bin/env bash
echo "git called with: $*" >> "$BATS_TEST_TMPDIR/mock_git_calls"

case "$1" in
    "config")
        case "$2" in
            "--global")
                case "$3" in
                    "user.name")
                        if [[ "$4" == "Test User" ]]; then
                            echo "Git config set: $*"
                        fi
                        ;;
                    "user.email")
                        if [[ "$4" == "test@example.com" ]]; then
                            echo "Git config set: $*"
                        fi
                        ;;
                esac
                ;;
            "--global")
                case "$3" in
                    "user.name")
                        echo "Test User"
                        ;;
                    "user.email")
                        echo "test@example.com"
                        ;;
                esac
                ;;
        esac
        ;;
esac
EOF
    chmod +x "$BATS_TEST_TMPDIR/mock_git"
    export PATH="$BATS_TEST_TMPDIR:$PATH"
    
    # Test configuration and validation
    run bash "$BATS_TEST_DIRNAME/../../../actions/claude-setup/scripts/configure_git.sh" "Test User" "test@example.com" "true"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Git user configured successfully" ]]
    [[ "$output" =~ "Git user: Test User <test@example.com>" ]]
}

@test "configure_git script handles missing git command" {
    # Remove git from PATH
    export PATH=""
    
    # Test with missing git command
    run bash "$BATS_TEST_DIRNAME/../../../actions/claude-setup/scripts/configure_git.sh" "Test User" "test@example.com" "true"
    [ "$status" -eq 127 ]  # Command not found
}