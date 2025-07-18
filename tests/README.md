# GitHub Actions Test Suite

This directory contains comprehensive tests for the actions-lib GitHub Actions library.

## Test Structure

```
tests/
├── unit/                     # Unit tests for individual components
│   ├── claude-setup/         # Tests for claude-setup composite action
│   ├── github-operations/    # Tests for github-operations composite action
│   └── prp-management/       # Tests for prp-management composite action
├── integration/              # Integration tests for composite actions
├── e2e/                      # End-to-end workflow tests
├── fixtures/                 # Test data and mock responses
│   ├── sample_prp_files/     # Sample PRP files for testing
│   ├── mock_github_responses/ # Mock GitHub API responses
│   └── test_repositories/    # Git repositories for testing
├── mocks/                    # Mock implementations
├── utils/                    # Testing utilities and helpers
└── README.md                 # This file
```

## Testing Strategy

### Unit Tests (70% of test coverage)
- Test individual shell script functions
- Mock external commands (git, github-script, curl)
- Validate input/output handling
- Test error conditions and edge cases

### Integration Tests (20% of test coverage)
- Test complete composite actions using act CLI
- Mock GitHub API responses
- Test action orchestration
- Verify environment setup

### End-to-End Tests (10% of test coverage)
- Test real workflow execution
- Use actual GitHub API (rate-limited)
- Test repository operations
- Validate complete user flows

## Running Tests

### Prerequisites
```bash
# Install BATS
npm install -g bats

# Install act CLI
curl -L https://github.com/nektos/act/releases/latest/download/act_Linux_x86_64.tar.gz | tar -xz
sudo mv act /usr/local/bin/
```

### Test Execution
```bash
# Run all tests
make test

# Run unit tests only
make test-unit

# Run integration tests only
make test-integration

# Run end-to-end tests only
make test-e2e

# Run tests with coverage
make test-coverage
```

## Test Development Guidelines

1. **Test Isolation**: Each test should be independent and not rely on external state
2. **Mocking**: Use mocks for external dependencies (GitHub API, git commands)
3. **Descriptive Names**: Test names should clearly describe what is being tested
4. **Setup/Teardown**: Use proper setup and teardown for test fixtures
5. **Error Testing**: Test both success and failure scenarios

## Mock Strategy

- **GitHub API**: Mock responses using fixture files
- **Git Commands**: Mock git operations to avoid repository state changes
- **File System**: Use temporary directories for file operations
- **Environment**: Mock environment variables and inputs

## Contributing

1. Write tests for new functionality
2. Ensure tests pass locally before submitting PR
3. Follow existing test patterns and conventions
4. Update documentation for new test scenarios