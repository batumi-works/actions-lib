#!/usr/bin/env bats
# Unit tests for prp-management file operations functionality

load "../../bats-setup"

@test "file operations moves PRP to done folder" {
    # Set up test environment
    setup_github_actions_env
    
    # Create test PRP file
    mkdir -p "$BATS_TEST_TMPDIR/PRPs"
    create_sample_prp "$BATS_TEST_TMPDIR/PRPs/test-feature.md"
    
    # Create the test script
    cat > "$BATS_TEST_TMPDIR/test_move_prp.sh" << 'EOF'
#!/usr/bin/env bash
# Test PRP file moving logic

PRP_PATH="$1"
PRP_NAME="$2"
MOVE_TO_DONE="$3"
HAS_PRP="$4"

cd "$BATS_TEST_TMPDIR"

if [[ "$HAS_PRP" == "true" && "$MOVE_TO_DONE" == "true" ]]; then
    # Create done directory if it doesn't exist
    mkdir -p PRPs/done
    
    # Move PRP to done folder
    if [ -f "$PRP_PATH" ]; then
        mv "$PRP_PATH" "PRPs/done/${PRP_NAME}.md"
        echo "Moved PRP to done: PRPs/done/${PRP_NAME}.md"
    else
        echo "PRP file not found for moving: $PRP_PATH"
        exit 1
    fi
else
    echo "PRP move skipped"
fi
EOF
    chmod +x "$BATS_TEST_TMPDIR/test_move_prp.sh"
    
    # Test moving PRP file
    run "$BATS_TEST_TMPDIR/test_move_prp.sh" "PRPs/test-feature.md" "test-feature" "true" "true"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Moved PRP to done: PRPs/done/test-feature.md" ]]
    
    # Check that file was moved
    assert_file_exists "$BATS_TEST_TMPDIR/PRPs/done/test-feature.md"
    [[ ! -f "$BATS_TEST_TMPDIR/PRPs/test-feature.md" ]]
}

@test "file operations skips move when disabled" {
    # Set up test environment
    setup_github_actions_env
    
    # Create test PRP file
    mkdir -p "$BATS_TEST_TMPDIR/PRPs"
    create_sample_prp "$BATS_TEST_TMPDIR/PRPs/test-feature.md"
    
    # Create the test script
    cat > "$BATS_TEST_TMPDIR/test_skip_move.sh" << 'EOF'
#!/usr/bin/env bash
# Test PRP move skip logic

PRP_PATH="$1"
PRP_NAME="$2"
MOVE_TO_DONE="$3"
HAS_PRP="$4"

cd "$BATS_TEST_TMPDIR"

if [[ "$HAS_PRP" == "true" && "$MOVE_TO_DONE" == "true" ]]; then
    mkdir -p PRPs/done
    if [ -f "$PRP_PATH" ]; then
        mv "$PRP_PATH" "PRPs/done/${PRP_NAME}.md"
        echo "Moved PRP to done: PRPs/done/${PRP_NAME}.md"
    else
        echo "PRP file not found for moving: $PRP_PATH"
    fi
else
    echo "PRP move skipped"
fi
EOF
    chmod +x "$BATS_TEST_TMPDIR/test_skip_move.sh"
    
    # Test with move_to_done=false
    run "$BATS_TEST_TMPDIR/test_skip_move.sh" "PRPs/test-feature.md" "test-feature" "false" "true"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "PRP move skipped" ]]
    
    # Check that file was not moved
    assert_file_exists "$BATS_TEST_TMPDIR/PRPs/test-feature.md"
    [[ ! -f "$BATS_TEST_TMPDIR/PRPs/done/test-feature.md" ]]
}

@test "file operations creates done directory if missing" {
    # Set up test environment
    setup_github_actions_env
    
    # Create test PRP file without done directory
    mkdir -p "$BATS_TEST_TMPDIR/PRPs"
    create_sample_prp "$BATS_TEST_TMPDIR/PRPs/test-feature.md"
    
    # Create the test script
    cat > "$BATS_TEST_TMPDIR/test_create_done_dir.sh" << 'EOF'
#!/usr/bin/env bash
# Test done directory creation

PRP_PATH="$1"
PRP_NAME="$2"
MOVE_TO_DONE="$3"
HAS_PRP="$4"

cd "$BATS_TEST_TMPDIR"

if [[ "$HAS_PRP" == "true" && "$MOVE_TO_DONE" == "true" ]]; then
    # Create done directory if it doesn't exist
    if [ ! -d "PRPs/done" ]; then
        mkdir -p PRPs/done
        echo "Created done directory"
    fi
    
    # Move PRP to done folder
    if [ -f "$PRP_PATH" ]; then
        mv "$PRP_PATH" "PRPs/done/${PRP_NAME}.md"
        echo "Moved PRP to done: PRPs/done/${PRP_NAME}.md"
    else
        echo "PRP file not found for moving: $PRP_PATH"
    fi
else
    echo "PRP move skipped"
fi
EOF
    chmod +x "$BATS_TEST_TMPDIR/test_create_done_dir.sh"
    
    # Ensure done directory doesn't exist
    rm -rf "$BATS_TEST_TMPDIR/PRPs/done"
    
    # Test directory creation
    run "$BATS_TEST_TMPDIR/test_create_done_dir.sh" "PRPs/test-feature.md" "test-feature" "true" "true"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Created done directory" ]]
    [[ "$output" =~ "Moved PRP to done" ]]
    
    # Check that directory and file exist
    assert_dir_exists "$BATS_TEST_TMPDIR/PRPs/done"
    assert_file_exists "$BATS_TEST_TMPDIR/PRPs/done/test-feature.md"
}

@test "file operations handles missing PRP file gracefully" {
    # Set up test environment
    setup_github_actions_env
    
    # Create the test script
    cat > "$BATS_TEST_TMPDIR/test_missing_file.sh" << 'EOF'
#!/usr/bin/env bash
# Test missing PRP file handling

PRP_PATH="$1"
PRP_NAME="$2"
MOVE_TO_DONE="$3"
HAS_PRP="$4"

cd "$BATS_TEST_TMPDIR"

if [[ "$HAS_PRP" == "true" && "$MOVE_TO_DONE" == "true" ]]; then
    mkdir -p PRPs/done
    
    # Try to move PRP to done folder
    if [ -f "$PRP_PATH" ]; then
        mv "$PRP_PATH" "PRPs/done/${PRP_NAME}.md"
        echo "Moved PRP to done: PRPs/done/${PRP_NAME}.md"
    else
        echo "PRP file not found for moving: $PRP_PATH"
        # Don't exit with error, just warn
        echo "::warning::PRP file not found for moving: $PRP_PATH"
    fi
else
    echo "PRP move skipped"
fi
EOF
    chmod +x "$BATS_TEST_TMPDIR/test_missing_file.sh"
    
    # Test with missing file
    run "$BATS_TEST_TMPDIR/test_missing_file.sh" "PRPs/non-existent.md" "non-existent" "true" "true"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "PRP file not found for moving" ]]
    [[ "$output" =~ "::warning::" ]]
}

@test "file operations preserves file permissions" {
    # Set up test environment
    setup_github_actions_env
    
    # Create test PRP file with specific permissions
    mkdir -p "$BATS_TEST_TMPDIR/PRPs"
    create_sample_prp "$BATS_TEST_TMPDIR/PRPs/test-feature.md"
    chmod 644 "$BATS_TEST_TMPDIR/PRPs/test-feature.md"
    
    # Create the test script
    cat > "$BATS_TEST_TMPDIR/test_permissions.sh" << 'EOF'
#!/usr/bin/env bash
# Test file permissions preservation

PRP_PATH="$1"
PRP_NAME="$2"
MOVE_TO_DONE="$3"
HAS_PRP="$4"

cd "$BATS_TEST_TMPDIR"

if [[ "$HAS_PRP" == "true" && "$MOVE_TO_DONE" == "true" ]]; then
    mkdir -p PRPs/done
    
    # Get original permissions
    original_perms=$(stat -c %a "$PRP_PATH" 2>/dev/null || echo "unknown")
    
    # Move PRP to done folder
    if [ -f "$PRP_PATH" ]; then
        mv "$PRP_PATH" "PRPs/done/${PRP_NAME}.md"
        
        # Check new permissions
        new_perms=$(stat -c %a "PRPs/done/${PRP_NAME}.md" 2>/dev/null || echo "unknown")
        
        echo "Original permissions: $original_perms"
        echo "New permissions: $new_perms"
        echo "Moved PRP to done: PRPs/done/${PRP_NAME}.md"
    else
        echo "PRP file not found for moving: $PRP_PATH"
    fi
else
    echo "PRP move skipped"
fi
EOF
    chmod +x "$BATS_TEST_TMPDIR/test_permissions.sh"
    
    # Test permissions preservation
    run "$BATS_TEST_TMPDIR/test_permissions.sh" "PRPs/test-feature.md" "test-feature" "true" "true"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Original permissions: 644" ]]
    [[ "$output" =~ "New permissions: 644" ]]
    [[ "$output" =~ "Moved PRP to done" ]]
    
    # Verify file permissions
    [ "$(stat -c %a "$BATS_TEST_TMPDIR/PRPs/done/test-feature.md")" = "644" ]
}

@test "file operations handles concurrent access" {
    # Set up test environment
    setup_github_actions_env
    
    # Create test PRP file
    mkdir -p "$BATS_TEST_TMPDIR/PRPs"
    create_sample_prp "$BATS_TEST_TMPDIR/PRPs/test-feature.md"
    
    # Create the test script
    cat > "$BATS_TEST_TMPDIR/test_concurrent.sh" << 'EOF'
#!/usr/bin/env bash
# Test concurrent access handling

PRP_PATH="$1"
PRP_NAME="$2"
MOVE_TO_DONE="$3"
HAS_PRP="$4"

cd "$BATS_TEST_TMPDIR"

if [[ "$HAS_PRP" == "true" && "$MOVE_TO_DONE" == "true" ]]; then
    mkdir -p PRPs/done
    
    # Check if target already exists (concurrent access)
    target_path="PRPs/done/${PRP_NAME}.md"
    if [ -f "$target_path" ]; then
        echo "Target file already exists, creating backup"
        backup_path="PRPs/done/${PRP_NAME}-backup-$(date +%s).md"
        mv "$target_path" "$backup_path"
        echo "Created backup: $backup_path"
    fi
    
    # Move PRP to done folder
    if [ -f "$PRP_PATH" ]; then
        mv "$PRP_PATH" "$target_path"
        echo "Moved PRP to done: $target_path"
    else
        echo "PRP file not found for moving: $PRP_PATH"
    fi
else
    echo "PRP move skipped"
fi
EOF
    chmod +x "$BATS_TEST_TMPDIR/test_concurrent.sh"
    
    # Create existing target file to simulate concurrent access
    mkdir -p "$BATS_TEST_TMPDIR/PRPs/done"
    echo "existing content" > "$BATS_TEST_TMPDIR/PRPs/done/test-feature.md"
    
    # Test concurrent access handling
    run "$BATS_TEST_TMPDIR/test_concurrent.sh" "PRPs/test-feature.md" "test-feature" "true" "true"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Target file already exists" ]]
    [[ "$output" =~ "Created backup" ]]
    [[ "$output" =~ "Moved PRP to done" ]]
    
    # Verify backup was created
    backup_files=$(find "$BATS_TEST_TMPDIR/PRPs/done" -name "test-feature-backup-*.md")
    [ -n "$backup_files" ]
}