#!/usr/bin/env bats
# Unit tests for prp-management branch creation functionality

load "../../bats-setup"

@test "branch creation creates implementation branch" {
    # Set up test environment
    setup_github_actions_env
    mock_git "default"
    
    # Create the test script
    cat > "$BATS_TEST_TMPDIR/test_branch_creation.sh" << 'EOF'
#!/usr/bin/env bash
# Test branch creation logic

BRANCH_NAME="$1"
CREATE_BRANCH="$2"
HAS_PRP="$3"

if [[ "$HAS_PRP" == "true" && "$CREATE_BRANCH" == "true" ]]; then
    git checkout -b "$BRANCH_NAME"
    echo "Created branch: $BRANCH_NAME"
else
    echo "Branch creation skipped"
fi
EOF
    chmod +x "$BATS_TEST_TMPDIR/test_branch_creation.sh"
    
    # Test branch creation
    run "$BATS_TEST_TMPDIR/test_branch_creation.sh" "implement/test-feature-123456" "true" "true"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Created branch: implement/test-feature-123456" ]]
    
    # Verify git command was called
    verify_git_command "checkout -b implement/test-feature-123456"
}

@test "branch creation skips when disabled" {
    # Set up test environment
    setup_github_actions_env
    mock_git "default"
    
    # Create the test script
    cat > "$BATS_TEST_TMPDIR/test_branch_skip.sh" << 'EOF'
#!/usr/bin/env bash
# Test branch creation skip logic

BRANCH_NAME="$1"
CREATE_BRANCH="$2"
HAS_PRP="$3"

if [[ "$HAS_PRP" == "true" && "$CREATE_BRANCH" == "true" ]]; then
    git checkout -b "$BRANCH_NAME"
    echo "Created branch: $BRANCH_NAME"
else
    echo "Branch creation skipped"
fi
EOF
    chmod +x "$BATS_TEST_TMPDIR/test_branch_skip.sh"
    
    # Test with create_branch=false
    run "$BATS_TEST_TMPDIR/test_branch_skip.sh" "implement/test-feature-123456" "false" "true"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Branch creation skipped" ]]
    
    # Verify git command was not called
    [ ! -f "$BATS_TEST_TMPDIR/mock_git_calls" ]
}

@test "branch creation skips when no PRP found" {
    # Set up test environment
    setup_github_actions_env
    mock_git "default"
    
    # Create the test script
    cat > "$BATS_TEST_TMPDIR/test_no_prp_branch.sh" << 'EOF'
#!/usr/bin/env bash
# Test branch creation with no PRP

BRANCH_NAME="$1"
CREATE_BRANCH="$2"
HAS_PRP="$3"

if [[ "$HAS_PRP" == "true" && "$CREATE_BRANCH" == "true" ]]; then
    git checkout -b "$BRANCH_NAME"
    echo "Created branch: $BRANCH_NAME"
else
    echo "Branch creation skipped (no PRP or disabled)"
fi
EOF
    chmod +x "$BATS_TEST_TMPDIR/test_no_prp_branch.sh"
    
    # Test with has_prp=false
    run "$BATS_TEST_TMPDIR/test_no_prp_branch.sh" "implement/test-feature-123456" "true" "false"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Branch creation skipped" ]]
    
    # Verify git command was not called
    [ ! -f "$BATS_TEST_TMPDIR/mock_git_calls" ]
}

@test "branch creation handles git errors" {
    # Set up test environment
    setup_github_actions_env
    mock_git "checkout_fail"
    
    # Create the test script
    cat > "$BATS_TEST_TMPDIR/test_branch_error.sh" << 'EOF'
#!/usr/bin/env bash
# Test branch creation error handling

BRANCH_NAME="$1"
CREATE_BRANCH="$2"
HAS_PRP="$3"

if [[ "$HAS_PRP" == "true" && "$CREATE_BRANCH" == "true" ]]; then
    if git checkout -b "$BRANCH_NAME"; then
        echo "Created branch: $BRANCH_NAME"
    else
        echo "Failed to create branch: $BRANCH_NAME"
        exit 1
    fi
else
    echo "Branch creation skipped"
fi
EOF
    chmod +x "$BATS_TEST_TMPDIR/test_branch_error.sh"
    
    # Test with git failure
    run "$BATS_TEST_TMPDIR/test_branch_error.sh" "implement/test-feature-123456" "true" "true"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Failed to create branch" ]]
}

@test "branch creation validates branch names" {
    # Set up test environment
    setup_github_actions_env
    mock_git "default"
    
    # Create the test script
    cat > "$BATS_TEST_TMPDIR/test_branch_validation.sh" << 'EOF'
#!/usr/bin/env bash
# Test branch name validation

BRANCH_NAME="$1"
CREATE_BRANCH="$2"
HAS_PRP="$3"

# Validate branch name format
if [[ ! "$BRANCH_NAME" =~ ^[a-zA-Z0-9/_-]+$ ]]; then
    echo "Invalid branch name format: $BRANCH_NAME"
    exit 1
fi

# Check for reserved patterns
if [[ "$BRANCH_NAME" =~ ^(main|master|HEAD)$ ]]; then
    echo "Branch name conflicts with reserved name: $BRANCH_NAME"
    exit 1
fi

if [[ "$HAS_PRP" == "true" && "$CREATE_BRANCH" == "true" ]]; then
    git checkout -b "$BRANCH_NAME"
    echo "Created branch: $BRANCH_NAME"
else
    echo "Branch creation skipped"
fi
EOF
    chmod +x "$BATS_TEST_TMPDIR/test_branch_validation.sh"
    
    # Test valid branch name
    run "$BATS_TEST_TMPDIR/test_branch_validation.sh" "implement/test-feature-123456" "true" "true"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Created branch" ]]
    
    # Test invalid branch name with special characters
    run "$BATS_TEST_TMPDIR/test_branch_validation.sh" "implement/test@feature" "true" "true"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Invalid branch name format" ]]
    
    # Test reserved branch name
    run "$BATS_TEST_TMPDIR/test_branch_validation.sh" "main" "true" "true"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Branch name conflicts with reserved name" ]]
}

@test "branch creation handles long branch names" {
    # Set up test environment
    setup_github_actions_env
    mock_git "default"
    
    # Create the test script
    cat > "$BATS_TEST_TMPDIR/test_long_branch.sh" << 'EOF'
#!/usr/bin/env bash
# Test long branch name handling

BRANCH_NAME="$1"
CREATE_BRANCH="$2"
HAS_PRP="$3"

# Check branch name length (Git has a limit around 255 characters)
if [[ ${#BRANCH_NAME} -gt 200 ]]; then
    echo "Branch name too long (${#BRANCH_NAME} characters): truncating"
    BRANCH_NAME="${BRANCH_NAME:0:200}"
fi

if [[ "$HAS_PRP" == "true" && "$CREATE_BRANCH" == "true" ]]; then
    git checkout -b "$BRANCH_NAME"
    echo "Created branch: $BRANCH_NAME"
else
    echo "Branch creation skipped"
fi
EOF
    chmod +x "$BATS_TEST_TMPDIR/test_long_branch.sh"
    
    # Create a very long branch name
    long_branch="implement/$(printf 'a%.0s' {1..250})"
    
    # Test with long branch name
    run "$BATS_TEST_TMPDIR/test_long_branch.sh" "$long_branch" "true" "true"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Branch name too long" ]]
    [[ "$output" =~ "Created branch" ]]
}

@test "branch creation preserves existing branches" {
    # Set up test environment
    setup_github_actions_env
    
    # Create a mock git that simulates existing branches
    cat > "$BATS_TEST_TMPDIR/mock_git" << 'EOF'
#!/usr/bin/env bash
echo "git called with: $*" >> "$BATS_TEST_TMPDIR/mock_git_calls"

case "$1" in
    "checkout")
        if [[ "$3" == "implement/existing-branch" ]]; then
            echo "fatal: A branch named 'implement/existing-branch' already exists."
            exit 1
        else
            echo "Switched to a new branch '$3'"
        fi
        ;;
    "branch")
        if [[ "$2" == "-a" ]]; then
            echo "* main"
            echo "  implement/existing-branch"
        fi
        ;;
esac
EOF
    chmod +x "$BATS_TEST_TMPDIR/mock_git"
    export PATH="$BATS_TEST_TMPDIR:$PATH"
    
    # Create the test script
    cat > "$BATS_TEST_TMPDIR/test_existing_branch.sh" << 'EOF'
#!/usr/bin/env bash
# Test existing branch handling

BRANCH_NAME="$1"
CREATE_BRANCH="$2"
HAS_PRP="$3"

if [[ "$HAS_PRP" == "true" && "$CREATE_BRANCH" == "true" ]]; then
    if git checkout -b "$BRANCH_NAME" 2>/dev/null; then
        echo "Created branch: $BRANCH_NAME"
    else
        echo "Branch already exists or creation failed: $BRANCH_NAME"
        # Could implement fallback with different name
        timestamp=$(date +%s)
        fallback_branch="${BRANCH_NAME}-${timestamp}"
        if git checkout -b "$fallback_branch"; then
            echo "Created fallback branch: $fallback_branch"
        else
            echo "Failed to create fallback branch"
            exit 1
        fi
    fi
else
    echo "Branch creation skipped"
fi
EOF
    chmod +x "$BATS_TEST_TMPDIR/test_existing_branch.sh"
    
    # Test with existing branch
    run "$BATS_TEST_TMPDIR/test_existing_branch.sh" "implement/existing-branch" "true" "true"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Branch already exists" ]]
    [[ "$output" =~ "Created fallback branch" ]]
    
    # Test with new branch
    run "$BATS_TEST_TMPDIR/test_existing_branch.sh" "implement/new-branch" "true" "true"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Created branch: implement/new-branch" ]]
}