# Complete Testing Guide

This comprehensive guide covers all testing approaches for the GitHub Actions Library, including native testing, Docker-based testing, and CI/CD integration.

## 📋 Table of Contents

1. [Overview](#overview)
2. [Quick Start](#quick-start)
3. [Native Testing](#native-testing)
4. [Docker Testing](#docker-testing)
5. [Test Types](#test-types)
6. [CI/CD Integration](#cicd-integration)
7. [Troubleshooting](#troubleshooting)
8. [Best Practices](#best-practices)

## 🎯 Overview

The testing suite provides multiple approaches to ensure the reliability and quality of GitHub Actions:

- **Native Testing**: Run tests directly on your system
- **Docker Testing**: Containerized testing for consistency
- **Multi-layer Testing**: Unit, Integration, and E2E tests
- **Automated Testing**: CI/CD pipeline integration
- **Security Testing**: Static analysis and vulnerability scanning

## 🚀 Quick Start

### Choose Your Testing Approach

#### Option 1: Docker Testing (Recommended)
```bash
# Quick start with Docker
./scripts/docker-test.sh validate    # Check prerequisites
./scripts/docker-test.sh build      # Build test container
./scripts/docker-test.sh test       # Run all tests
```

#### Option 2: Native Testing
```bash
# Quick start with native tools
./scripts/setup-test-env.sh         # Install dependencies
make test                           # Run all tests
```

### Verify Setup
```bash
# Check what's installed
bats --version
act --version
docker --version

# Run a quick test
make test-unit                      # Native
# OR
make docker-unit                    # Docker
```

## 🔧 Native Testing

### Prerequisites
- BATS (Bash Automated Testing System)
- act CLI (GitHub Actions runner)
- Docker (for act integration)
- ShellCheck (for security scanning)
- Python 3 (for text processing)

### Installation

#### Automated Setup
```bash
# Install all dependencies automatically
./scripts/setup-test-env.sh
```

#### Manual Installation
```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install -y bats shellcheck python3 docker.io gh

# macOS
brew install bats-core shellcheck python3 docker gh act

# Install act CLI manually
curl -L https://github.com/nektos/act/releases/latest/download/act_Linux_x86_64.tar.gz | tar -xz
sudo mv act /usr/local/bin/
```

### Running Native Tests

```bash
# All tests
make test

# Specific test types
make test-unit              # Unit tests only
make test-integration       # Integration tests only
make test-e2e              # End-to-end tests only

# Specific test files
bats tests/unit/claude-setup/test_checkout.bats
bats tests/integration/test_composite_actions.bats

# With coverage
make test-coverage

# Generate reports
make test-report
```

### Test Configuration

Create `.env` file for custom settings:
```bash
# .env
GITHUB_TOKEN=your_github_token
CLAUDE_CODE_OAUTH_TOKEN=your_claude_token
RUN_E2E_TESTS=true
BATS_TEST_TIMEOUT=300
```

## 🐳 Docker Testing

### Why Docker Testing?

- **Consistency**: Same environment across different systems
- **Isolation**: No interference with host system
- **Reproducibility**: Exact same results every time
- **CI/CD Ready**: Perfect for automated pipelines
- **Clean Environment**: Fresh state for each test run

### Docker Setup

#### Quick Setup
```bash
# Validate Docker setup
./scripts/docker-test.sh validate

# Build test container
./scripts/docker-test.sh build
```

#### Manual Docker Commands
```bash
# Build container
docker build -f Dockerfile.test -t actions-test .

# Run tests
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock actions-test

# Interactive shell
docker run --rm -it -v "$(pwd)":/workspace actions-test bash
```

### Docker Compose Services

#### Available Services

**`test-runner`** - Complete test suite
```bash
./scripts/docker-test.sh test
# OR
docker-compose -f docker-compose.test.yml up test-runner
```

**`unit-tests`** - Unit tests only
```bash
./scripts/docker-test.sh unit
# OR
docker-compose -f docker-compose.test.yml up unit-tests
```

**`integration-tests`** - Integration tests with act CLI
```bash
./scripts/docker-test.sh integration
# OR
docker-compose -f docker-compose.test.yml up integration-tests
```

**`security-scan`** - Security analysis
```bash
./scripts/docker-test.sh security
# OR
docker-compose -f docker-compose.test.yml up security-scan
```

**`performance-tests`** - Performance benchmarks
```bash
./scripts/docker-test.sh performance
# OR
docker-compose -f docker-compose.test.yml up performance-tests
```

**`dev-shell`** - Interactive development environment
```bash
./scripts/docker-test.sh shell
# OR
docker-compose -f docker-compose.test.yml run dev-shell
```

### Docker Testing Workflows

#### Development Workflow
```bash
# 1. Start development shell
./scripts/docker-test.sh shell

# 2. Inside container - run specific tests
make test-unit
bats tests/unit/claude-setup/
act --dryrun

# 3. Exit and run full suite
exit
./scripts/docker-test.sh test
```

#### Parallel Testing
```bash
# Run multiple test types simultaneously
./scripts/docker-test.sh test --parallel

# Or manually
docker-compose -f docker-compose.test.yml up -d \
  unit-tests \
  integration-tests \
  security-scan \
  performance-tests
```

#### Debugging Failed Tests
```bash
# View logs
./scripts/docker-test.sh logs unit-tests

# Access container for debugging
docker-compose -f docker-compose.test.yml exec unit-tests bash

# Run specific failing test
bats tests/unit/claude-setup/test_specific_failure.bats
```

## 🧪 Test Types

### Unit Tests (70% of coverage)

**Purpose**: Test individual functions and components in isolation

**Location**: `tests/unit/`

**Examples**:
```bash
# Test token validation
bats tests/unit/claude-setup/test_validate_token.bats

# Test git configuration
bats tests/unit/claude-setup/test_configure_git.bats

# Test PRP extraction
bats tests/unit/prp-management/test_prp_extraction.bats
```

**What's Tested**:
- Input validation
- Error handling
- Output generation
- Edge cases
- Command mocking

### Integration Tests (20% of coverage)

**Purpose**: Test complete composite actions and their interactions

**Location**: `tests/integration/`

**Examples**:
```bash
# Test complete action workflows
bats tests/integration/test_composite_actions.bats

# Test act CLI integration
bats tests/integration/test_with_act.bats
```

**What's Tested**:
- Action orchestration
- Data flow between steps
- Environment setup
- Error propagation
- State consistency

### End-to-End Tests (10% of coverage)

**Purpose**: Test real-world workflows with actual GitHub API

**Location**: `tests/e2e/`

**Examples**:
```bash
# Test complete workflows
bats tests/e2e/test_full_workflow.bats
```

**What's Tested**:
- Real GitHub API integration
- Complete user workflows
- Performance characteristics
- External tool integration

## 🔄 CI/CD Integration

### GitHub Actions Workflow

The project includes a comprehensive CI/CD pipeline in `.github/workflows/test-actions.yml`:

**Triggered by**:
- Push to main/develop branches
- Pull requests
- Daily scheduled runs
- Manual workflow dispatch

**Test Jobs**:
- **Validate Tests**: Syntax validation and structure check
- **Unit Tests**: Fast feedback unit testing
- **Integration Tests**: act CLI and composite action testing
- **E2E Tests**: Real GitHub API testing (limited)
- **Security Scan**: ShellCheck and security analysis
- **Performance Tests**: Benchmarking and timing analysis
- **Test Coverage**: Coverage reporting
- **Test Reports**: Comprehensive result reporting

### Local CI Testing

```bash
# Test the CI workflow locally with act
act -W .github/workflows/test-actions.yml

# Test specific job
act -j unit-tests

# Test with secrets
act --secret-file .secrets
```

### Custom CI Integration

#### GitLab CI Example
```yaml
# .gitlab-ci.yml
test:
  image: docker:latest
  services:
    - docker:dind
  script:
    - ./scripts/docker-test.sh test
  artifacts:
    reports:
      junit: reports/test-results.xml
    paths:
      - reports/
```

#### Jenkins Example
```groovy
// Jenkinsfile
pipeline {
    agent any
    stages {
        stage('Test') {
            steps {
                sh './scripts/docker-test.sh test'
            }
        }
    }
    post {
        always {
            publishTestResults testResultsPattern: 'reports/*.xml'
            archiveArtifacts artifacts: 'reports/**/*'
        }
    }
}
```

## 🐛 Troubleshooting

### Common Issues

#### Native Testing Issues

**BATS not found**
```bash
# Solution 1: Install via package manager
sudo apt-get install bats  # Ubuntu/Debian
brew install bats-core     # macOS

# Solution 2: Install via npm
npm install -g bats
```

**act permission denied**
```bash
# Add user to docker group
sudo usermod -aG docker $USER
# Log out and back in

# Or temporarily fix permissions
sudo chmod 666 /var/run/docker.sock
```

**Tests fail with "command not found"**
```bash
# Check PATH and dependencies
echo $PATH
which bats act git python3

# Run setup script
./scripts/setup-test-env.sh
```

#### Docker Testing Issues

**Docker daemon not running**
```bash
# Start Docker service
sudo systemctl start docker

# Or start Docker Desktop (macOS/Windows)
```

**Permission denied with Docker**
```bash
# Add user to docker group
sudo usermod -aG docker $USER

# Or use sudo
sudo ./scripts/docker-test.sh test
```

**Out of disk space**
```bash
# Clean up Docker resources
docker system prune -a
./scripts/docker-test.sh clean
```

**Container build fails**
```bash
# Build with verbose output
./scripts/docker-test.sh build --no-cache

# Check build logs
docker build --progress=plain -f Dockerfile.test .
```

### Debug Commands

```bash
# Check system status
./scripts/docker-test.sh validate     # Docker setup
./scripts/setup-test-env.sh          # Native setup

# View detailed logs
./scripts/docker-test.sh logs test-runner
docker-compose -f docker-compose.test.yml logs

# Interactive debugging
./scripts/docker-test.sh shell
make test-unit  # Inside container

# Performance analysis
time make test-unit
/usr/bin/time -v make test-unit
```

### Environment Issues

**GitHub API rate limiting**
```bash
# Use authentication
export GITHUB_TOKEN=your_token

# Skip E2E tests
export RUN_E2E_TESTS=false
```

**Network connectivity**
```bash
# Test basic connectivity
curl -I https://github.com
ping google.com

# Use proxy if needed
export HTTP_PROXY=http://proxy:port
export HTTPS_PROXY=http://proxy:port
```

## 📝 Best Practices

### Test Development

1. **Write Tests First**: Test-driven development approach
2. **Isolate Tests**: Each test should be independent
3. **Mock External Dependencies**: Use mocks for git, APIs, etc.
4. **Test Edge Cases**: Include error conditions and boundary cases
5. **Clear Test Names**: Descriptive test function names
6. **Proper Setup/Teardown**: Clean environment for each test

### Test Organization

1. **Logical Structure**: Group related tests together
2. **Consistent Naming**: Follow naming conventions
3. **Documentation**: Comment complex test logic
4. **Fixtures**: Reuse test data and mocks
5. **Helper Functions**: Extract common test utilities

### Performance

1. **Fast Unit Tests**: Keep unit tests under 1 second each
2. **Parallel Execution**: Use parallel testing where possible
3. **Resource Management**: Clean up test artifacts
4. **Efficient Mocking**: Use lightweight mocks
5. **Test Optimization**: Profile and optimize slow tests

### Security

1. **No Hardcoded Secrets**: Use environment variables
2. **Safe Test Data**: Use dummy/test data only
3. **Permission Testing**: Test permission scenarios
4. **Input Validation**: Test malicious inputs
5. **Security Scanning**: Regular security analysis

### CI/CD

1. **Fast Feedback**: Prioritize unit tests for speed
2. **Comprehensive Coverage**: Include all test types
3. **Artifact Management**: Save test reports and logs
4. **Failure Analysis**: Clear error reporting
5. **Resource Efficiency**: Optimize CI resource usage

## 📊 Test Metrics and Reporting

### Coverage Targets
- **Unit Tests**: 70% of total test effort
- **Integration Tests**: 20% of total test effort
- **E2E Tests**: 10% of total test effort
- **Code Coverage**: 80%+ for critical paths

### Performance Benchmarks
- **Unit Test Suite**: < 2 minutes
- **Integration Test Suite**: < 5 minutes
- **Complete Test Suite**: < 10 minutes
- **Individual Tests**: < 10 seconds each

### Quality Gates
- All unit tests must pass
- No security vulnerabilities (high/critical)
- Code coverage above threshold
- Performance within acceptable limits
- No test flakiness

## 🤝 Contributing to Tests

### Adding New Tests

1. **Choose Test Type**: Unit, integration, or E2E
2. **Follow Structure**: Use existing patterns
3. **Include Documentation**: Explain test purpose
4. **Test Coverage**: Ensure adequate coverage
5. **Update CI**: Add to appropriate CI jobs

### Test Maintenance

1. **Regular Updates**: Keep tests current with changes
2. **Flakiness Fixes**: Address intermittent failures
3. **Performance Optimization**: Monitor and improve speed
4. **Documentation Updates**: Keep guides current
5. **Tool Updates**: Update testing dependencies

## 📚 Additional Resources

- [BATS Documentation](https://bats-core.readthedocs.io/)
- [act CLI Documentation](https://github.com/nektos/act)
- [Docker Documentation](https://docs.docker.com/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Docker Testing Guide](./DOCKER_TESTING.md)

---

🧪 **Happy Testing!** 🚀

This comprehensive testing suite ensures the reliability and quality of your GitHub Actions library. Choose the approach that best fits your development workflow and environment.