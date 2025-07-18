#!/usr/bin/env bash
# Git-specific mock functions for testing

# Mock git command with configurable behavior
mock_git() {
    local behavior="${1:-default}"
    
    cat > "$BATS_TEST_TMPDIR/git" << EOF
#!/usr/bin/env bash
# Mock git implementation

# Log the call
echo "git called with: \$*" >> "$BATS_TEST_TMPDIR/mock_git_calls"

case "\$1" in
    "config")
        case "$behavior" in
            "config_fail")
                echo "fatal: could not lock config file" >&2
                exit 1
                ;;
            *)
                echo "Git config set: \$*"
                ;;
        esac
        ;;
    "checkout")
        case "$behavior" in
            "checkout_fail")
                echo "fatal: A branch named '\$3' already exists" >&2
                exit 1
                ;;
            *)
                echo "Switched to branch '\$3'"
                ;;
        esac
        ;;
    "add")
        echo "Added: \$*"
        ;;
    "commit")
        echo "Committed: \$*"
        ;;
    "push")
        case "$behavior" in
            "push_fail")
                echo "fatal: repository not found" >&2
                exit 1
                ;;
            *)
                echo "Pushed to remote"
                ;;
        esac
        ;;
    "status")
        case "$behavior" in
            "dirty")
                echo "modified: test_file.txt"
                ;;
            *)
                echo "nothing to commit, working tree clean"
                ;;
        esac
        ;;
    "diff")
        echo "diff --git a/test_file.txt b/test_file.txt"
        ;;
    "log")
        echo "commit abc123 (HEAD -> main)"
        echo "Author: Test User <test@example.com>"
        echo "Date: Mon Jan 1 00:00:00 2024 +0000"
        echo ""
        echo "    Test commit"
        ;;
    "branch")
        case "\$2" in
            "-d"|"--delete")
                echo "Deleted branch \$3"
                ;;
            *)
                echo "* main"
                echo "  feature/test"
                ;;
        esac
        ;;
    "remote")
        case "\$2" in
            "add")
                echo "Added remote: \$3"
                ;;
            *)
                echo "origin"
                ;;
        esac
        ;;
    "clone")
        local repo_dir="\${2##*/}"
        repo_dir="\${repo_dir%.git}"
        mkdir -p "\$repo_dir"
        echo "Cloned repository to \$repo_dir"
        ;;
    "init")
        echo "Initialized empty Git repository"
        ;;
    "rev-parse")
        case "\$2" in
            "HEAD")
                echo "abc123def456"
                ;;
            "--show-toplevel")
                echo "$BATS_TEST_TMPDIR/test_repo"
                ;;
            *)
                echo "abc123"
                ;;
        esac
        ;;
    *)
        echo "Unknown git command: \$1"
        exit 1
        ;;
esac
EOF
    
    chmod +x "$BATS_TEST_TMPDIR/git"
    export PATH="$BATS_TEST_TMPDIR:$PATH"
}

# Mock git with specific responses for different scenarios
mock_git_with_responses() {
    local config_file="$1"
    
    cat > "$BATS_TEST_TMPDIR/git" << EOF
#!/usr/bin/env bash
# Mock git with custom responses

# Log the call
echo "git called with: \$*" >> "$BATS_TEST_TMPDIR/mock_git_calls"

# Source custom responses if provided
if [[ -f "$config_file" ]]; then
    source "$config_file"
fi

# Default implementations
git_config_default() {
    echo "Git config set: \$*"
}

git_checkout_default() {
    echo "Switched to branch '\$3'"
}

git_status_default() {
    echo "nothing to commit, working tree clean"
}

# Route to appropriate function
case "\$1" in
    "config")
        if type git_config_response &>/dev/null; then
            git_config_response "\$@"
        else
            git_config_default "\$@"
        fi
        ;;
    "checkout")
        if type git_checkout_response &>/dev/null; then
            git_checkout_response "\$@"
        else
            git_checkout_default "\$@"
        fi
        ;;
    "status")
        if type git_status_response &>/dev/null; then
            git_status_response "\$@"
        else
            git_status_default "\$@"
        fi
        ;;
    *)
        echo "Unknown git command: \$1"
        exit 1
        ;;
esac
EOF
    
    chmod +x "$BATS_TEST_TMPDIR/git"
    export PATH="$BATS_TEST_TMPDIR:$PATH"
}

# Create a git repository state for testing
create_git_test_state() {
    local repo_dir="$1"
    local branch="${2:-main}"
    
    mkdir -p "$repo_dir"
    cd "$repo_dir"
    
    # Initialize repository
    git init
    git config user.name "Test User"
    git config user.email "test@example.com"
    
    # Create initial commit
    echo "# Test Repository" > README.md
    git add README.md
    git commit -m "Initial commit"
    
    # Create requested branch if not main
    if [[ "$branch" != "main" ]]; then
        git checkout -b "$branch"
    fi
    
    # Add some test files
    echo "test content" > test_file.txt
    git add test_file.txt
    git commit -m "Add test file"
    
    echo "$repo_dir"
}

# Verify git commands were called correctly
verify_git_command() {
    local expected_command="$1"
    local call_log="$BATS_TEST_TMPDIR/mock_git_calls"
    
    if [[ ! -f "$call_log" ]]; then
        echo "Git was not called"
        return 1
    fi
    
    # Check for the command with the "git called with:" prefix
    if ! grep -q "git called with: $expected_command" "$call_log"; then
        echo "Expected git command not found: $expected_command"
        echo "Actual calls:"
        cat "$call_log"
        return 1
    fi
}

# Get all git command calls
get_git_calls() {
    local call_log="$BATS_TEST_TMPDIR/mock_git_calls"
    
    if [[ -f "$call_log" ]]; then
        cat "$call_log"
    fi
}

# Count git command calls
count_git_calls() {
    local call_log="$BATS_TEST_TMPDIR/mock_git_calls"
    
    if [[ -f "$call_log" ]]; then
        wc -l < "$call_log"
    else
        echo "0"
    fi
}

# Mock git with failure scenarios
mock_git_failures() {
    local failure_type="$1"
    
    case "$failure_type" in
        "config_permission")
            mock_git "config_fail"
            ;;
        "checkout_exists")
            mock_git "checkout_fail"
            ;;
        "push_no_remote")
            mock_git "push_fail"
            ;;
        *)
            echo "Unknown failure type: $failure_type"
            return 1
            ;;
    esac
}

# Clean up git-specific mocks
cleanup_git_mocks() {
    rm -f "$BATS_TEST_TMPDIR"/git "$BATS_TEST_TMPDIR"/mock_git*
}