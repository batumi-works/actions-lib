#!/usr/bin/env bash
# BATS setup file for GitHub Actions testing

# Set up test environment
export BATS_TEST_TMPDIR="${BATS_TEST_TMPDIR:-/tmp/bats-test}"
export GITHUB_WORKSPACE="${BATS_TEST_TMPDIR}/workspace"
export GITHUB_OUTPUT="${BATS_TEST_TMPDIR}/github_output"

# Create test directories
setup_test_env() {
    mkdir -p "$BATS_TEST_TMPDIR"
    mkdir -p "$GITHUB_WORKSPACE"
    
    # Initialize GitHub output file
    echo "" > "$GITHUB_OUTPUT"
    
    # Set up PATH to include mocks
    export PATH="$BATS_TEST_DIRNAME/mocks:$PATH"
}

# Clean up test environment
teardown_test_env() {
    rm -rf "$BATS_TEST_TMPDIR"
}

# Load test utilities
load_test_utils() {
    # Find the tests root directory by looking for bats-setup.bash
    local tests_root
    tests_root="$(cd "$BATS_TEST_DIRNAME" && while [[ ! -f "bats-setup.bash" ]]; do cd ..; done && pwd)"
    
    load "$tests_root/utils/test_helpers.bash"
    load "$tests_root/utils/github_mocks.bash"
    load "$tests_root/utils/git_mocks.bash"
}

# Mock GitHub Actions environment
setup_github_env() {
    export GITHUB_ACTOR="test-actor"
    export GITHUB_REPOSITORY="test-org/test-repo"
    export GITHUB_REF="refs/heads/main"
    export GITHUB_SHA="abc123"
    export GITHUB_REPOSITORY_OWNER="test-org"
    export GITHUB_EVENT_NAME="issue_comment"
    export GITHUB_TOKEN="ghp_test_token"
    
    # Create mock GitHub context
    cat > "$GITHUB_WORKSPACE/github_context.json" << 'EOF'
{
  "repository": {
    "owner": {
      "login": "test-org"
    },
    "name": "test-repo"
  },
  "issue": {
    "number": 123,
    "title": "Test Issue",
    "body": "Test issue body"
  }
}
EOF
}

# Setup function called before each test
setup() {
    setup_test_env
    load_test_utils
    setup_github_env
}

# Teardown function called after each test
teardown() {
    teardown_test_env
}