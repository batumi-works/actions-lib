#!/usr/bin/env bats
# Unit tests for prp-management PRP file extraction functionality

load "../../bats-setup"

@test "prp extraction finds PRP path in comment body" {
    # Set up test environment
    setup_github_actions_env
    export GITHUB_OUTPUT="$BATS_TEST_TMPDIR/github_output"
    
    # Create test PRP file
    mkdir -p "$BATS_TEST_TMPDIR/PRPs"
    create_sample_prp "$BATS_TEST_TMPDIR/PRPs/test-feature.md"
    
    # Create a mock script that extracts PRP path
    cat > "$BATS_TEST_TMPDIR/test_prp_extraction.sh" << 'EOF'
#!/usr/bin/env bash
# Test PRP extraction logic

COMMENT_BODY="$1"
cd "$BATS_TEST_TMPDIR"

# Extract PRP path from comment body
prp_match=$(echo "$COMMENT_BODY" | grep -oE 'PRPs/[^[:space:]\)]+\.md' | head -1)

if [ -z "$prp_match" ]; then
    echo "has_prp=false" >> "$GITHUB_OUTPUT"
    echo "No PRP file path found in comment"
    exit 0
fi

# Validate PRP file exists
if [ ! -f "$prp_match" ]; then
    echo "has_prp=false" >> "$GITHUB_OUTPUT"
    echo "PRP file does not exist: $prp_match"
    exit 1
fi

# Extract PRP name and generate branch name
prp_name=$(basename "$prp_match" .md)
branch_name="implement/${prp_name}-$(date +%s)"

echo "prp_path=$prp_match" >> "$GITHUB_OUTPUT"
echo "prp_name=$prp_name" >> "$GITHUB_OUTPUT"
echo "branch_name=$branch_name" >> "$GITHUB_OUTPUT"
echo "has_prp=true" >> "$GITHUB_OUTPUT"

echo "Found PRP: $prp_match"
echo "Branch name: $branch_name"
EOF
    chmod +x "$BATS_TEST_TMPDIR/test_prp_extraction.sh"
    
    # Test with valid PRP path
    run "$BATS_TEST_TMPDIR/test_prp_extraction.sh" "Please implement PRPs/test-feature.md"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Found PRP: PRPs/test-feature.md" ]]
    
    # Check outputs
    assert_github_output_contains "has_prp" "true"
    assert_github_output_contains "prp_path" "PRPs/test-feature.md"
    assert_github_output_contains "prp_name" "test-feature"
    grep -q "branch_name=implement/test-feature-" "$GITHUB_OUTPUT"
}

@test "prp extraction handles missing PRP file" {
    # Set up test environment
    setup_github_actions_env
    export GITHUB_OUTPUT="$BATS_TEST_TMPDIR/github_output"
    
    # Create the test script
    cat > "$BATS_TEST_TMPDIR/test_missing_prp.sh" << 'EOF'
#!/usr/bin/env bash
# Test missing PRP file handling

COMMENT_BODY="$1"
cd "$BATS_TEST_TMPDIR"

# Extract PRP path from comment body
prp_match=$(echo "$COMMENT_BODY" | grep -oE 'PRPs/[^[:space:]\)]+\.md' | head -1)

if [ -z "$prp_match" ]; then
    echo "has_prp=false" >> "$GITHUB_OUTPUT"
    echo "No PRP file path found in comment"
    exit 0
fi

# Validate PRP file exists
if [ ! -f "$prp_match" ]; then
    echo "has_prp=false" >> "$GITHUB_OUTPUT"
    echo "PRP file does not exist: $prp_match"
    exit 1
fi

echo "PRP file exists"
EOF
    chmod +x "$BATS_TEST_TMPDIR/test_missing_prp.sh"
    
    # Test with non-existent PRP file
    run "$BATS_TEST_TMPDIR/test_missing_prp.sh" "Please implement PRPs/non-existent.md"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "PRP file does not exist" ]]
    
    # Check output
    assert_github_output_contains "has_prp" "false"
}

@test "prp extraction handles no PRP path in comment" {
    # Set up test environment
    setup_github_actions_env
    export GITHUB_OUTPUT="$BATS_TEST_TMPDIR/github_output"
    
    # Create the test script
    cat > "$BATS_TEST_TMPDIR/test_no_prp.sh" << 'EOF'
#!/usr/bin/env bash
# Test no PRP path in comment

COMMENT_BODY="$1"

# Extract PRP path from comment body
prp_match=$(echo "$COMMENT_BODY" | grep -oE 'PRPs/[^[:space:]\)]+\.md' | head -1)

if [ -z "$prp_match" ]; then
    echo "has_prp=false" >> "$GITHUB_OUTPUT"
    echo "No PRP file path found in comment"
    exit 0
fi

echo "PRP found: $prp_match"
EOF
    chmod +x "$BATS_TEST_TMPDIR/test_no_prp.sh"
    
    # Test with comment without PRP path
    run "$BATS_TEST_TMPDIR/test_no_prp.sh" "This is just a regular comment"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "No PRP file path found in comment" ]]
    
    # Check output
    assert_github_output_contains "has_prp" "false"
}

@test "prp extraction handles multiple PRP paths" {
    # Set up test environment
    setup_github_actions_env
    export GITHUB_OUTPUT="$BATS_TEST_TMPDIR/github_output"
    
    # Create test PRP files
    mkdir -p "$BATS_TEST_TMPDIR/PRPs"
    create_sample_prp "$BATS_TEST_TMPDIR/PRPs/first-feature.md"
    create_sample_prp "$BATS_TEST_TMPDIR/PRPs/second-feature.md"
    
    # Create the test script
    cat > "$BATS_TEST_TMPDIR/test_multiple_prps.sh" << 'EOF'
#!/usr/bin/env bash
# Test multiple PRP paths (should use first one)

COMMENT_BODY="$1"
cd "$BATS_TEST_TMPDIR"

# Extract PRP path from comment body (head -1 gets first match)
prp_match=$(echo "$COMMENT_BODY" | grep -oE 'PRPs/[^[:space:]\)]+\.md' | head -1)

if [ -z "$prp_match" ]; then
    echo "has_prp=false" >> "$GITHUB_OUTPUT"
    echo "No PRP file path found in comment"
    exit 0
fi

echo "prp_path=$prp_match" >> "$GITHUB_OUTPUT"
echo "has_prp=true" >> "$GITHUB_OUTPUT"
echo "Selected PRP: $prp_match"
EOF
    chmod +x "$BATS_TEST_TMPDIR/test_multiple_prps.sh"
    
    # Test with multiple PRP paths
    run "$BATS_TEST_TMPDIR/test_multiple_prps.sh" "Please implement PRPs/first-feature.md and PRPs/second-feature.md"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Selected PRP: PRPs/first-feature.md" ]]
    
    # Check that first PRP was selected
    assert_github_output_contains "prp_path" "PRPs/first-feature.md"
}

@test "prp extraction handles PRP paths with special characters" {
    # Set up test environment
    setup_github_actions_env
    export GITHUB_OUTPUT="$BATS_TEST_TMPDIR/github_output"
    
    # Create test PRP files with special characters
    mkdir -p "$BATS_TEST_TMPDIR/PRPs"
    create_sample_prp "$BATS_TEST_TMPDIR/PRPs/feature-with-dashes.md"
    create_sample_prp "$BATS_TEST_TMPDIR/PRPs/feature_with_underscores.md"
    
    # Create the test script
    cat > "$BATS_TEST_TMPDIR/test_special_chars.sh" << 'EOF'
#!/usr/bin/env bash
# Test PRP paths with special characters

COMMENT_BODY="$1"
cd "$BATS_TEST_TMPDIR"

# Extract PRP path from comment body
prp_match=$(echo "$COMMENT_BODY" | grep -oE 'PRPs/[^[:space:]\)]+\.md' | head -1)

if [ -z "$prp_match" ]; then
    echo "has_prp=false" >> "$GITHUB_OUTPUT"
    echo "No PRP file path found in comment"
    exit 0
fi

# Validate PRP file exists
if [ ! -f "$prp_match" ]; then
    echo "has_prp=false" >> "$GITHUB_OUTPUT"
    echo "PRP file does not exist: $prp_match"
    exit 1
fi

echo "prp_path=$prp_match" >> "$GITHUB_OUTPUT"
echo "has_prp=true" >> "$GITHUB_OUTPUT"
echo "Found PRP with special chars: $prp_match"
EOF
    chmod +x "$BATS_TEST_TMPDIR/test_special_chars.sh"
    
    # Test with dashes
    run "$BATS_TEST_TMPDIR/test_special_chars.sh" "Please implement PRPs/feature-with-dashes.md"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Found PRP with special chars: PRPs/feature-with-dashes.md" ]]
    
    # Test with underscores
    run "$BATS_TEST_TMPDIR/test_special_chars.sh" "Please implement PRPs/feature_with_underscores.md"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Found PRP with special chars: PRPs/feature_with_underscores.md" ]]
}

@test "prp extraction generates unique branch names" {
    # Set up test environment
    setup_github_actions_env
    export GITHUB_OUTPUT="$BATS_TEST_TMPDIR/github_output"
    
    # Create test PRP file
    mkdir -p "$BATS_TEST_TMPDIR/PRPs"
    create_sample_prp "$BATS_TEST_TMPDIR/PRPs/test-feature.md"
    
    # Create the test script
    cat > "$BATS_TEST_TMPDIR/test_branch_names.sh" << 'EOF'
#!/usr/bin/env bash
# Test branch name generation

COMMENT_BODY="$1"
cd "$BATS_TEST_TMPDIR"

# Extract PRP path from comment body
prp_match=$(echo "$COMMENT_BODY" | grep -oE 'PRPs/[^[:space:]\)]+\.md' | head -1)

if [ -z "$prp_match" ]; then
    echo "has_prp=false" >> "$GITHUB_OUTPUT"
    exit 0
fi

# Extract PRP name and generate branch name with timestamp
prp_name=$(basename "$prp_match" .md)
timestamp=$(date +%s)
branch_name="implement/${prp_name}-${timestamp}"

echo "branch_name=$branch_name" >> "$GITHUB_OUTPUT"
echo "Generated branch name: $branch_name"
EOF
    chmod +x "$BATS_TEST_TMPDIR/test_branch_names.sh"
    
    # Run twice to ensure different timestamps
    run "$BATS_TEST_TMPDIR/test_branch_names.sh" "Please implement PRPs/test-feature.md"
    [ "$status" -eq 0 ]
    first_branch=$(grep "branch_name=" "$GITHUB_OUTPUT" | cut -d'=' -f2)
    
    # Clear output and run again
    echo "" > "$GITHUB_OUTPUT"
    sleep 1  # Ensure different timestamp
    run "$BATS_TEST_TMPDIR/test_branch_names.sh" "Please implement PRPs/test-feature.md"
    [ "$status" -eq 0 ]
    second_branch=$(grep "branch_name=" "$GITHUB_OUTPUT" | cut -d'=' -f2)
    
    # Branch names should be different due to timestamp
    [[ "$first_branch" != "$second_branch" ]]
    [[ "$first_branch" =~ implement/test-feature- ]]
    [[ "$second_branch" =~ implement/test-feature- ]]
}