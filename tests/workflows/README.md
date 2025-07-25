# GitHub Actions Workflow Tests

This directory contains comprehensive tests for all GitHub Actions workflows in the repository.

## Test Coverage

### Workflow Files Tested

1. **claude-agent-pipeline.yml**
   - API configuration validation
   - Event handling (issues, issue_comment, schedule, workflow_dispatch)
   - Bot status checking
   - PRP creation and management
   - Git operations and commenting

2. **claude-prp-pipeline.yml**
   - PRP implementation workflow
   - Branch management
   - Pull request creation
   - Conditional execution
   - Integration with Claude Code action

3. **claude-prp-pipeline-v2.yml** (Enhanced)
   - All v1 features plus:
   - Dependency caching
   - Automated testing
   - Linting integration
   - Enhanced error reporting
   - Performance optimizations

4. **claude-prp-pipeline-v3.yml** (Advanced)
   - All v2 features plus:
   - Security scanning
   - Performance benchmarking
   - Preview deployments
   - Documentation generation
   - Enterprise features

5. **smart-runner-template.yml**
   - Runner selection logic
   - Fallback mechanisms
   - Auto-detection based on repository owner
   - Support for Blacksmith and BuildJet runners

## Running Tests

### Prerequisites

```bash
# Install BATS (required)
npm install -g bats

# Install yq (recommended for YAML validation)
# macOS
brew install yq
# Linux
wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/local/bin/yq
chmod +x /usr/local/bin/yq

# Install act CLI (optional, for integration tests)
curl -L https://github.com/nektos/act/releases/latest/download/act_Linux_x86_64.tar.gz | tar -xz
sudo mv act /usr/local/bin/
```

### Running All Workflow Tests

```bash
# From the repository root
make test-workflows

# Or directly
./tests/workflows/run_workflow_tests.sh
```

### Running Individual Test Files

```bash
# Test a specific workflow
bats tests/workflows/test_claude_agent_pipeline.bats
bats tests/workflows/test_smart_runner_template.bats

# Run with verbose output
bats -v tests/workflows/test_claude_prp_pipeline_v2.bats
```

## Test Structure

Each test file follows this pattern:

```bash
#!/usr/bin/env bats

# Setup function - runs before each test
setup() {
    # Initialize test environment
    # Copy workflow files
    # Set up mocks
}

# Teardown function - runs after each test
teardown() {
    # Clean up test environment
}

# Individual tests
@test "workflow-name: test description" {
    # Test implementation
    # Assertions
}
```

## Test Categories

### 1. Syntax and Structure Tests
- YAML validation
- Required inputs/secrets validation
- Default values verification
- Job dependencies

### 2. Logic Tests
- Conditional execution
- Event handling
- Runner selection
- Error handling

### 3. Integration Tests
- Workflow composition
- Action usage
- Output passing between steps
- Cache configuration

### 4. Configuration Tests
- Permissions
- Timeouts
- Environment variables
- Secret handling

## Writing New Tests

When adding new workflow tests:

1. Create a new test file: `test_<workflow_name>.bats`
2. Include standard setup/teardown functions
3. Test all inputs, outputs, and conditions
4. Verify error handling
5. Check integration points
6. Validate permissions and security

Example test template:

```bash
@test "workflow-name: validates required inputs" {
    run yq eval '.on.workflow_call.inputs.required_input.required' \
        "$TEST_WORKFLOW_DIR/.github/workflows/workflow-name.yml"
    [ "$output" = "true" ]
}
```

## Common Test Helpers

The tests use several helper functions:

- `validate_yaml` - Validates YAML syntax
- `setup_test_env` - Sets up test environment
- `load_test_utils` - Loads utility functions
- `setup_github_env` - Sets up GitHub environment variables

## Debugging Failed Tests

1. Run tests with verbose flag: `bats -v test_file.bats`
2. Add debug output: `echo "Debug: $variable" >&3`
3. Check test artifacts in `/tmp/bats-*`
4. Use `run` command to capture command output
5. Examine `$status` and `$output` variables

## CI Integration

These tests should run in CI on:
- Pull requests
- Pushes to main branch
- Workflow file changes
- Scheduled runs

## Contributing

When modifying workflows:
1. Update corresponding tests
2. Add tests for new features
3. Ensure all tests pass locally
4. Document any new test patterns

## Test Maintenance

- Review tests when workflows change
- Update test data and mocks as needed
- Remove tests for deprecated features
- Keep tests focused and fast