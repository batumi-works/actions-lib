#!/usr/bin/env bats
# Integration tests using act CLI

load "../bats-setup"

@test "act CLI is installed and working" {
    run act --version
    [ "$status" -eq 0 ]
    [[ "$output" =~ "act version" ]]
}

@test "can run simple workflow with act" {
    # Create a simple test workflow
    mkdir -p "$BATS_TEST_TMPDIR/test_workflow/.github/workflows"
    
    cat > "$BATS_TEST_TMPDIR/test_workflow/.github/workflows/test.yml" << 'EOF'
name: Test Workflow
on: [push]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - name: Echo test
        run: echo "Test successful"
EOF
    
    cd "$BATS_TEST_TMPDIR/test_workflow"
    
    # Run the workflow with act
    run act --dryrun
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Test Workflow" ]]
}

@test "can test composite action with act" {
    # Create a test workflow that uses our composite action
    mkdir -p "$BATS_TEST_TMPDIR/test_composite/.github/workflows"
    
    cat > "$BATS_TEST_TMPDIR/test_composite/.github/workflows/test-composite.yml" << 'EOF'
name: Test Composite Action
on: [push]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4
      
      - name: Test Claude Setup
        uses: ./actions/claude-setup
        with:
          claude_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
          github_token: ${{ secrets.GITHUB_TOKEN }}
          configure_git: 'false'
EOF
    
    cd "$BATS_TEST_TMPDIR/test_composite"
    
    # Copy our actions to the test directory
    cp -r "$BATS_TEST_DIRNAME/../../actions" .
    
    # Run with act in dry-run mode
    run act --dryrun
    [ "$status" -eq 0 ]
}