#!/usr/bin/env bats
# Unit tests for prp-management implementation prompt functionality

load "../../bats-setup"

@test "implementation prompt uses PRP execute template when available" {
    # Set up test environment
    setup_github_actions_env
    mkdir -p "$BATS_TEST_TMPDIR/.claude/commands/PRPs"
    
    # Create PRP execute template
    cat > "$BATS_TEST_TMPDIR/.claude/commands/PRPs/prp-base-execute.md" << 'EOF'
# PRP Implementation Template

## PRP to Implement
$ARGUMENTS

## Instructions
Please implement the PRP specified above following these guidelines:
1. Read and understand the requirements
2. Implement the solution
3. Test thoroughly
4. Update documentation
EOF
    
    # Create test PRP file
    mkdir -p "$BATS_TEST_TMPDIR/PRPs"
    create_sample_prp "$BATS_TEST_TMPDIR/PRPs/test-feature.md"
    
    # Create the test script
    cat > "$BATS_TEST_TMPDIR/test_implementation_prompt.sh" << 'EOF'
#!/usr/bin/env bash
# Test implementation prompt creation

PRP_PATH="$1"
HAS_PRP="$2"

cd "$BATS_TEST_TMPDIR"

if [[ "$HAS_PRP" == "true" ]]; then
    # Check if PRP base execute template exists
    if [ -f ".claude/commands/PRPs/prp-base-execute.md" ]; then
        template_content=$(cat .claude/commands/PRPs/prp-base-execute.md)
        echo "$template_content" | sed "s/\$ARGUMENTS/$PRP_PATH/g" > /tmp/prp-implementation-prompt.md
        echo "Created implementation prompt for: $PRP_PATH"
    else
        echo "PRP base execute template not found, creating basic prompt"
        echo "Please implement the PRP located at: $PRP_PATH" > /tmp/prp-implementation-prompt.md
    fi
else
    echo "No PRP to create implementation prompt for"
fi
EOF
    chmod +x "$BATS_TEST_TMPDIR/test_implementation_prompt.sh"
    
    # Test with template available
    run "$BATS_TEST_TMPDIR/test_implementation_prompt.sh" "PRPs/test-feature.md" "true"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Created implementation prompt for: PRPs/test-feature.md" ]]
    
    # Check that prompt was created
    assert_file_exists "/tmp/prp-implementation-prompt.md"
    
    # Check content
    run cat /tmp/prp-implementation-prompt.md
    [[ "$output" =~ "# PRP Implementation Template" ]]
    [[ "$output" =~ "PRPs/test-feature.md" ]]
    [[ "$output" =~ "Please implement the PRP specified above" ]]
}

@test "implementation prompt falls back when template missing" {
    # Set up test environment
    setup_github_actions_env
    
    # Create test PRP file (no template)
    mkdir -p "$BATS_TEST_TMPDIR/PRPs"
    create_sample_prp "$BATS_TEST_TMPDIR/PRPs/test-feature.md"
    
    # Create the test script
    cat > "$BATS_TEST_TMPDIR/test_fallback_prompt.sh" << 'EOF'
#!/usr/bin/env bash
# Test fallback prompt creation

PRP_PATH="$1"
HAS_PRP="$2"

cd "$BATS_TEST_TMPDIR"

if [[ "$HAS_PRP" == "true" ]]; then
    # Check if PRP base execute template exists
    if [ -f ".claude/commands/PRPs/prp-base-execute.md" ]; then
        template_content=$(cat .claude/commands/PRPs/prp-base-execute.md)
        echo "$template_content" | sed "s/\$ARGUMENTS/$PRP_PATH/g" > /tmp/prp-implementation-prompt.md
        echo "Created implementation prompt for: $PRP_PATH"
    else
        echo "PRP base execute template not found, creating basic prompt"
        echo "Please implement the PRP located at: $PRP_PATH" > /tmp/prp-implementation-prompt.md
    fi
else
    echo "No PRP to create implementation prompt for"
fi
EOF
    chmod +x "$BATS_TEST_TMPDIR/test_fallback_prompt.sh"
    
    # Test with no template
    run "$BATS_TEST_TMPDIR/test_fallback_prompt.sh" "PRPs/test-feature.md" "true"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "template not found" ]]
    [[ "$output" =~ "creating basic prompt" ]]
    
    # Check that basic prompt was created
    assert_file_exists "/tmp/prp-implementation-prompt.md"
    
    # Check content
    run cat /tmp/prp-implementation-prompt.md
    [[ "$output" =~ "Please implement the PRP located at: PRPs/test-feature.md" ]]
}

@test "implementation prompt handles complex PRP paths" {
    # Set up test environment
    setup_github_actions_env
    mkdir -p "$BATS_TEST_TMPDIR/.claude/commands/PRPs"
    
    # Create PRP execute template
    cat > "$BATS_TEST_TMPDIR/.claude/commands/PRPs/prp-base-execute.md" << 'EOF'
# PRP Implementation Template

## PRP to Implement
$ARGUMENTS

## Instructions
Implement the PRP above.
EOF
    
    # Create test PRP file with complex path
    mkdir -p "$BATS_TEST_TMPDIR/PRPs/features/auth"
    create_sample_prp "$BATS_TEST_TMPDIR/PRPs/features/auth/user-login-system.md"
    
    # Create the test script
    cat > "$BATS_TEST_TMPDIR/test_complex_path.sh" << 'EOF'
#!/usr/bin/env bash
# Test complex PRP path handling

PRP_PATH="$1"
HAS_PRP="$2"

cd "$BATS_TEST_TMPDIR"

if [[ "$HAS_PRP" == "true" ]]; then
    # Check if PRP base execute template exists
    if [ -f ".claude/commands/PRPs/prp-base-execute.md" ]; then
        template_content=$(cat .claude/commands/PRPs/prp-base-execute.md)
        # Use more robust substitution for complex paths
        python3 -c "
import sys
template = open('.claude/commands/PRPs/prp-base-execute.md').read()
result = template.replace('\$ARGUMENTS', '$PRP_PATH')
with open('/tmp/prp-implementation-prompt.md', 'w') as f:
    f.write(result)
print('Created implementation prompt for: $PRP_PATH')
"
    else
        echo "PRP base execute template not found, creating basic prompt"
        echo "Please implement the PRP located at: $PRP_PATH" > /tmp/prp-implementation-prompt.md
    fi
else
    echo "No PRP to create implementation prompt for"
fi
EOF
    chmod +x "$BATS_TEST_TMPDIR/test_complex_path.sh"
    
    # Test with complex path
    run "$BATS_TEST_TMPDIR/test_complex_path.sh" "PRPs/features/auth/user-login-system.md" "true"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Created implementation prompt for: PRPs/features/auth/user-login-system.md" ]]
    
    # Check content
    run cat /tmp/prp-implementation-prompt.md
    [[ "$output" =~ "PRPs/features/auth/user-login-system.md" ]]
}

@test "implementation prompt skips when no PRP" {
    # Set up test environment
    setup_github_actions_env
    
    # Create the test script
    cat > "$BATS_TEST_TMPDIR/test_no_prp_prompt.sh" << 'EOF'
#!/usr/bin/env bash
# Test no PRP prompt creation

PRP_PATH="$1"
HAS_PRP="$2"

cd "$BATS_TEST_TMPDIR"

if [[ "$HAS_PRP" == "true" ]]; then
    # Check if PRP base execute template exists
    if [ -f ".claude/commands/PRPs/prp-base-execute.md" ]; then
        template_content=$(cat .claude/commands/PRPs/prp-base-execute.md)
        echo "$template_content" | sed "s/\$ARGUMENTS/$PRP_PATH/g" > /tmp/prp-implementation-prompt.md
        echo "Created implementation prompt for: $PRP_PATH"
    else
        echo "PRP base execute template not found, creating basic prompt"
        echo "Please implement the PRP located at: $PRP_PATH" > /tmp/prp-implementation-prompt.md
    fi
else
    echo "No PRP to create implementation prompt for"
fi
EOF
    chmod +x "$BATS_TEST_TMPDIR/test_no_prp_prompt.sh"
    
    # Test with no PRP
    run "$BATS_TEST_TMPDIR/test_no_prp_prompt.sh" "" "false"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "No PRP to create implementation prompt for" ]]
    
    # Check that no prompt was created
    [[ ! -f "/tmp/prp-implementation-prompt.md" ]]
}

@test "implementation prompt handles template with special characters" {
    # Set up test environment
    setup_github_actions_env
    mkdir -p "$BATS_TEST_TMPDIR/.claude/commands/PRPs"
    
    # Create PRP execute template with special characters
    cat > "$BATS_TEST_TMPDIR/.claude/commands/PRPs/prp-base-execute.md" << 'EOF'
# PRP Implementation Template

## PRP to Implement
$ARGUMENTS

## Special Instructions
- Use `backticks` for code
- Handle "quotes" properly
- Process ${variables} correctly
- Escape $ARGUMENTS properly
EOF
    
    # Create test PRP file
    mkdir -p "$BATS_TEST_TMPDIR/PRPs"
    create_sample_prp "$BATS_TEST_TMPDIR/PRPs/test-feature.md"
    
    # Create the test script using Python for robust handling
    cat > "$BATS_TEST_TMPDIR/test_special_chars.sh" << 'EOF'
#!/usr/bin/env bash
# Test special characters in template

PRP_PATH="$1"
HAS_PRP="$2"

cd "$BATS_TEST_TMPDIR"

if [[ "$HAS_PRP" == "true" ]]; then
    # Check if PRP base execute template exists
    if [ -f ".claude/commands/PRPs/prp-base-execute.md" ]; then
        # Use Python for robust text processing
        python3 -c "
import sys
template = open('.claude/commands/PRPs/prp-base-execute.md').read()
result = template.replace('\$ARGUMENTS', '$PRP_PATH')
with open('/tmp/prp-implementation-prompt.md', 'w') as f:
    f.write(result)
print('Created implementation prompt with special characters')
"
    else
        echo "PRP base execute template not found"
    fi
else
    echo "No PRP to create implementation prompt for"
fi
EOF
    chmod +x "$BATS_TEST_TMPDIR/test_special_chars.sh"
    
    # Test with special characters
    run "$BATS_TEST_TMPDIR/test_special_chars.sh" "PRPs/test-feature.md" "true"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Created implementation prompt with special characters" ]]
    
    # Check content preservation
    run cat /tmp/prp-implementation-prompt.md
    [[ "$output" =~ "Use \`backticks\` for code" ]]
    [[ "$output" =~ "Handle \"quotes\" properly" ]]
    [[ "$output" =~ "Process \${variables} correctly" ]]
    [[ "$output" =~ "PRPs/test-feature.md" ]]
}

@test "implementation prompt validates template format" {
    # Set up test environment
    setup_github_actions_env
    mkdir -p "$BATS_TEST_TMPDIR/.claude/commands/PRPs"
    
    # Create invalid template (missing $ARGUMENTS)
    cat > "$BATS_TEST_TMPDIR/.claude/commands/PRPs/prp-base-execute.md" << 'EOF'
# Invalid PRP Template

## Instructions
This template is missing the required placeholder.
EOF
    
    # Create test PRP file
    mkdir -p "$BATS_TEST_TMPDIR/PRPs"
    create_sample_prp "$BATS_TEST_TMPDIR/PRPs/test-feature.md"
    
    # Create the test script
    cat > "$BATS_TEST_TMPDIR/test_template_validation.sh" << 'EOF'
#!/usr/bin/env bash
# Test template validation

PRP_PATH="$1"
HAS_PRP="$2"

cd "$BATS_TEST_TMPDIR"

if [[ "$HAS_PRP" == "true" ]]; then
    # Check if PRP base execute template exists
    if [ -f ".claude/commands/PRPs/prp-base-execute.md" ]; then
        template_content=$(cat .claude/commands/PRPs/prp-base-execute.md)
        
        # Validate template contains required placeholder
        if [[ "$template_content" =~ \$ARGUMENTS ]]; then
            echo "$template_content" | sed "s/\$ARGUMENTS/$PRP_PATH/g" > /tmp/prp-implementation-prompt.md
            echo "Created implementation prompt with valid template"
        else
            echo "Template validation failed - missing \$ARGUMENTS placeholder"
            echo "Please implement the PRP located at: $PRP_PATH" > /tmp/prp-implementation-prompt.md
            echo "Created fallback prompt due to invalid template"
        fi
    else
        echo "PRP base execute template not found"
    fi
else
    echo "No PRP to create implementation prompt for"
fi
EOF
    chmod +x "$BATS_TEST_TMPDIR/test_template_validation.sh"
    
    # Test with invalid template
    run "$BATS_TEST_TMPDIR/test_template_validation.sh" "PRPs/test-feature.md" "true"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Template validation failed" ]]
    [[ "$output" =~ "Created fallback prompt due to invalid template" ]]
    
    # Check that fallback prompt was created
    assert_file_exists "/tmp/prp-implementation-prompt.md"
    
    # Check content
    run cat /tmp/prp-implementation-prompt.md
    [[ "$output" =~ "Please implement the PRP located at: PRPs/test-feature.md" ]]
}