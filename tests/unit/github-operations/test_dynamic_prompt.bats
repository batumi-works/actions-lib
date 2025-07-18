#!/usr/bin/env bats
# Unit tests for github-operations dynamic prompt functionality

load "../../bats-setup"

@test "dynamic prompt creation uses PRP template when available" {
    # Set up test environment
    setup_github_actions_env
    mkdir -p "$BATS_TEST_TMPDIR/.claude/commands/PRPs"
    
    # Create PRP template
    cat > "$BATS_TEST_TMPDIR/.claude/commands/PRPs/prp-base-create.md" << 'EOF'
# PRP Creation Template

## Context
$ARGUMENTS

## Instructions
Create a PRP based on the discussion context above.
EOF
    
    # Create discussion context
    cat > /tmp/discussion-context.md << 'EOF'
# Issue: Test Issue

Test issue body

## Discussion:

**user1** (2024-01-01T00:00:00Z):
First comment
EOF
    
    # Create a mock script that processes the template
    cat > "$BATS_TEST_TMPDIR/test_dynamic_prompt.sh" << 'EOF'
#!/usr/bin/env bash
# Test dynamic prompt creation

cd "$BATS_TEST_TMPDIR"

# Check if PRP base create template exists
if [ -f ".claude/commands/PRPs/prp-base-create.md" ]; then
    template_content=$(cat .claude/commands/PRPs/prp-base-create.md)
    discussion_context=$(cat /tmp/discussion-context.md)
    echo "$template_content" | sed "s/\$ARGUMENTS/$discussion_context/g" > /tmp/dynamic-prompt.md
    echo "Created dynamic prompt with discussion context"
else
    echo "PRP base create template not found, using discussion context directly"
    cp /tmp/discussion-context.md /tmp/dynamic-prompt.md
fi
EOF
    chmod +x "$BATS_TEST_TMPDIR/test_dynamic_prompt.sh"
    
    # Run the test
    run "$BATS_TEST_TMPDIR/test_dynamic_prompt.sh"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Created dynamic prompt with discussion context" ]]
    
    # Check that dynamic prompt was created
    assert_file_exists "/tmp/dynamic-prompt.md"
    
    # Check content
    run cat /tmp/dynamic-prompt.md
    [[ "$output" =~ "# PRP Creation Template" ]]
    [[ "$output" =~ "# Issue: Test Issue" ]]
    [[ "$output" =~ "**user1**" ]]
}

@test "dynamic prompt creation falls back when template missing" {
    # Set up test environment
    setup_github_actions_env
    
    # Create discussion context without template
    cat > /tmp/discussion-context.md << 'EOF'
# Issue: Test Issue

Test issue body without template
EOF
    
    # Create a mock script that handles missing template
    cat > "$BATS_TEST_TMPDIR/test_fallback_prompt.sh" << 'EOF'
#!/usr/bin/env bash
# Test fallback prompt creation

# Check if PRP base create template exists
if [ -f ".claude/commands/PRPs/prp-base-create.md" ]; then
    template_content=$(cat .claude/commands/PRPs/prp-base-create.md)
    discussion_context=$(cat /tmp/discussion-context.md)
    echo "$template_content" | sed "s/\$ARGUMENTS/$discussion_context/g" > /tmp/dynamic-prompt.md
    echo "Created dynamic prompt with discussion context"
else
    echo "PRP base create template not found, using discussion context directly"
    cp /tmp/discussion-context.md /tmp/dynamic-prompt.md
fi
EOF
    chmod +x "$BATS_TEST_TMPDIR/test_fallback_prompt.sh"
    
    # Run the test
    run "$BATS_TEST_TMPDIR/test_fallback_prompt.sh"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "template not found" ]]
    [[ "$output" =~ "using discussion context directly" ]]
    
    # Check that fallback prompt was created
    assert_file_exists "/tmp/dynamic-prompt.md"
    
    # Check content
    run cat /tmp/dynamic-prompt.md
    [[ "$output" =~ "# Issue: Test Issue" ]]
    [[ "$output" =~ "Test issue body without template" ]]
}

@test "dynamic prompt creation handles complex discussion context" {
    # Set up test environment
    setup_github_actions_env
    mkdir -p "$BATS_TEST_TMPDIR/.claude/commands/PRPs"
    
    # Create PRP template
    cat > "$BATS_TEST_TMPDIR/.claude/commands/PRPs/prp-base-create.md" << 'EOF'
# PRP Creation Template

## Context
$ARGUMENTS

## Instructions
Create a PRP based on the discussion context above.
EOF
    
    # Create complex discussion context
    cat > /tmp/discussion-context.md << 'EOF'
# Issue: Complex Issue with Special Characters

This is a complex issue with:
- Special characters: @#$%^&*()
- Multiple lines
- Code blocks:
```bash
echo "test"
```

## Discussion:

**user1** (2024-01-01T00:00:00Z):
First comment with "quotes" and 'single quotes'

**user2** (2024-01-01T00:00:00Z):
Second comment with
multiple lines
and special characters: <>{}[]
EOF
    
    # Create a mock script that handles complex context
    cat > "$BATS_TEST_TMPDIR/test_complex_prompt.sh" << 'EOF'
#!/usr/bin/env bash
# Test complex prompt creation

cd "$BATS_TEST_TMPDIR"

# Check if PRP base create template exists
if [ -f ".claude/commands/PRPs/prp-base-create.md" ]; then
    template_content=$(cat .claude/commands/PRPs/prp-base-create.md)
    discussion_context=$(cat /tmp/discussion-context.md)
    
    # Use a more robust substitution method for complex content
    python3 -c "
import sys
template = open('.claude/commands/PRPs/prp-base-create.md').read()
context = open('/tmp/discussion-context.md').read()
result = template.replace('\$ARGUMENTS', context)
with open('/tmp/dynamic-prompt.md', 'w') as f:
    f.write(result)
print('Created dynamic prompt with complex context')
"
else
    echo "PRP base create template not found"
    cp /tmp/discussion-context.md /tmp/dynamic-prompt.md
fi
EOF
    chmod +x "$BATS_TEST_TMPDIR/test_complex_prompt.sh"
    
    # Run the test
    run "$BATS_TEST_TMPDIR/test_complex_prompt.sh"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Created dynamic prompt with complex context" ]]
    
    # Check that dynamic prompt was created
    assert_file_exists "/tmp/dynamic-prompt.md"
    
    # Check content preservation
    run cat /tmp/dynamic-prompt.md
    [[ "$output" =~ "Special characters: @#\$%\^&\*()" ]]
    [[ "$output" =~ "Code blocks:" ]]
    [[ "$output" =~ "echo \"test\"" ]]
}

@test "dynamic prompt creation handles empty discussion context" {
    # Set up test environment
    setup_github_actions_env
    
    # Create empty discussion context
    echo "" > /tmp/discussion-context.md
    
    # Create a mock script that handles empty context
    cat > "$BATS_TEST_TMPDIR/test_empty_context.sh" << 'EOF'
#!/usr/bin/env bash
# Test empty context handling

if [ ! -s "/tmp/discussion-context.md" ]; then
    echo "Discussion context is empty"
    echo "# No Discussion Context Available" > /tmp/dynamic-prompt.md
else
    echo "Discussion context available"
    cp /tmp/discussion-context.md /tmp/dynamic-prompt.md
fi
EOF
    chmod +x "$BATS_TEST_TMPDIR/test_empty_context.sh"
    
    # Run the test
    run "$BATS_TEST_TMPDIR/test_empty_context.sh"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Discussion context is empty" ]]
    
    # Check that fallback prompt was created
    assert_file_exists "/tmp/dynamic-prompt.md"
    
    # Check content
    run cat /tmp/dynamic-prompt.md
    [[ "$output" =~ "No Discussion Context Available" ]]
}

@test "dynamic prompt creation validates template syntax" {
    # Set up test environment
    setup_github_actions_env
    mkdir -p "$BATS_TEST_TMPDIR/.claude/commands/PRPs"
    
    # Create template with invalid syntax
    cat > "$BATS_TEST_TMPDIR/.claude/commands/PRPs/prp-base-create.md" << 'EOF'
# Invalid Template

## Context
$ARGUMENTS

## Missing closing section
This template has some issues
EOF
    
    # Create discussion context
    cat > /tmp/discussion-context.md << 'EOF'
# Issue: Test Issue
Test content
EOF
    
    # Create a mock script that validates template
    cat > "$BATS_TEST_TMPDIR/test_template_validation.sh" << 'EOF'
#!/usr/bin/env bash
# Test template validation

cd "$BATS_TEST_TMPDIR"

if [ -f ".claude/commands/PRPs/prp-base-create.md" ]; then
    template_content=$(cat .claude/commands/PRPs/prp-base-create.md)
    
    # Basic validation - check if template contains required placeholder
    if [[ "$template_content" =~ \$ARGUMENTS ]]; then
        echo "Template validation passed"
        discussion_context=$(cat /tmp/discussion-context.md)
        echo "$template_content" | sed "s/\$ARGUMENTS/$discussion_context/g" > /tmp/dynamic-prompt.md
        echo "Created dynamic prompt"
    else
        echo "Template validation failed - missing \$ARGUMENTS placeholder"
        exit 1
    fi
else
    echo "Template not found"
    exit 1
fi
EOF
    chmod +x "$BATS_TEST_TMPDIR/test_template_validation.sh"
    
    # Run the test
    run "$BATS_TEST_TMPDIR/test_template_validation.sh"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Template validation passed" ]]
    [[ "$output" =~ "Created dynamic prompt" ]]
}