# Quick Reference Guide

## 🚀 Quick Commands

### Docker Testing (Recommended)
```bash
# Setup and validation
./scripts/docker-test.sh validate    # Check prerequisites
./scripts/docker-test.sh build      # Build test container

# Run tests
./scripts/docker-test.sh test       # All tests
./scripts/docker-test.sh unit       # Unit tests only
./scripts/docker-test.sh integration # Integration tests only
./scripts/docker-test.sh security   # Security scans
./scripts/docker-test.sh performance # Performance tests

# Development
./scripts/docker-test.sh shell      # Interactive shell
./scripts/docker-test.sh logs       # View logs
./scripts/docker-test.sh status     # Container status
./scripts/docker-test.sh clean      # Cleanup

# Advanced
./scripts/docker-test.sh test --parallel  # Parallel execution
./scripts/docker-test.sh build --no-cache # Force rebuild
```

### Native Testing
```bash
# Setup
./scripts/setup-test-env.sh         # Install dependencies
make install-deps                   # Alternative installation

# Run tests
make test                           # All tests
make test-unit                      # Unit tests only
make test-integration               # Integration tests only
make test-e2e                       # End-to-end tests only
make test-coverage                  # With coverage

# Utilities
make setup-test-env                 # Setup environment
make clean-test-env                 # Cleanup environment
make validate-tests                 # Validate test files
make test-report                    # Generate reports
```

### Docker Compose (Direct)
```bash
# Individual services
docker-compose -f docker-compose.test.yml up test-runner
docker-compose -f docker-compose.test.yml up unit-tests
docker-compose -f docker-compose.test.yml up integration-tests
docker-compose -f docker-compose.test.yml up security-scan
docker-compose -f docker-compose.test.yml up performance-tests

# Parallel execution
docker-compose -f docker-compose.test.yml up -d unit-tests integration-tests security-scan

# Interactive development
docker-compose -f docker-compose.test.yml run dev-shell

# Management
docker-compose -f docker-compose.test.yml ps        # Status
docker-compose -f docker-compose.test.yml logs     # Logs
docker-compose -f docker-compose.test.yml down -v  # Cleanup
```

## 📁 File Structure

```
actions-lib/
├── tests/                          # Test suite
│   ├── unit/                       # Unit tests (70% coverage)
│   │   ├── claude-setup/           # Claude setup tests
│   │   ├── github-operations/      # GitHub operations tests
│   │   └── prp-management/         # PRP management tests
│   ├── integration/                # Integration tests (20% coverage)
│   ├── e2e/                        # End-to-end tests (10% coverage)
│   ├── fixtures/                   # Test data and mocks
│   ├── mocks/                      # Mock implementations
│   ├── utils/                      # Test utilities
│   └── README.md                   # Test documentation
├── scripts/                        # Helper scripts
│   ├── setup-test-env.sh           # Native setup script
│   └── docker-test.sh              # Docker testing script
├── docs/                           # Documentation
│   ├── TESTING_GUIDE.md            # Complete testing guide
│   ├── DOCKER_TESTING.md           # Docker-specific guide
│   └── QUICK_REFERENCE.md          # This file
├── Dockerfile.test                 # Test container definition
├── docker-compose.test.yml         # Multi-service orchestration
├── .dockerignore                   # Docker build exclusions
├── Makefile                        # Build automation
└── .github/workflows/test-actions.yml # CI/CD pipeline
```

## 🔧 Prerequisites

### Docker Testing
- Docker Engine 20.10+
- Docker Compose 2.0+
- 4GB+ RAM
- 2GB+ disk space

### Native Testing
- BATS (Bash Automated Testing System)
- act CLI (GitHub Actions runner)
- Docker (for act integration)
- ShellCheck (security scanning)
- Python 3 (text processing)
- Git (version control)

## 🐛 Quick Troubleshooting

### Docker Issues
```bash
# Permission denied
sudo usermod -aG docker $USER  # Add to docker group
sudo chmod 666 /var/run/docker.sock  # Temporary fix

# Out of space
docker system prune -a
./scripts/docker-test.sh clean

# Build failures
./scripts/docker-test.sh build --no-cache
docker build --progress=plain -f Dockerfile.test .
```

### Native Issues
```bash
# BATS not found
sudo apt-get install bats  # Ubuntu
brew install bats-core     # macOS

# act permission denied
sudo usermod -aG docker $USER

# Dependencies missing
./scripts/setup-test-env.sh
```

### Test Failures
```bash
# View detailed logs
./scripts/docker-test.sh logs test-runner
make test-unit --verbose

# Debug specific test
bats tests/unit/claude-setup/test_checkout.bats
./scripts/docker-test.sh shell

# Check environment
./scripts/docker-test.sh validate
./scripts/setup-test-env.sh
```

## 🎯 Common Workflows

### Development Workflow
```bash
# 1. Setup (first time)
./scripts/docker-test.sh validate
./scripts/docker-test.sh build

# 2. Development cycle
./scripts/docker-test.sh shell      # Interactive shell
make test-unit                      # Test changes
bats tests/unit/new-feature/        # Test specific feature
exit                                # Exit shell

# 3. Full validation
./scripts/docker-test.sh test       # Complete test suite
```

### CI/CD Workflow
```bash
# Local CI testing
act -W .github/workflows/test-actions.yml

# Production CI
git push origin feature-branch      # Triggers automated tests
```

### Debugging Workflow
```bash
# 1. Reproduce issue
./scripts/docker-test.sh unit       # Run failing tests

# 2. Debug
./scripts/docker-test.sh logs unit-tests
./scripts/docker-test.sh shell

# 3. Inside container
bats -t tests/unit/failing-test.bats
cat /workspace/.test-cache/debug.log

# 4. Fix and retest
exit
./scripts/docker-test.sh test
```

## 📊 Performance Targets

| Test Type | Target Time | Max Time |
|-----------|-------------|----------|
| Unit Tests | < 2 minutes | < 5 minutes |
| Integration Tests | < 5 minutes | < 10 minutes |
| Security Scans | < 1 minute | < 3 minutes |
| Performance Tests | < 1 minute | < 2 minutes |
| Complete Suite | < 10 minutes | < 15 minutes |
| Individual Test | < 10 seconds | < 30 seconds |

## 🔒 Security Notes

- Tests run as non-root user in containers
- No secrets in test code or images
- Use dummy tokens for testing
- Scan containers for vulnerabilities
- Isolate test networks
- Clean up test artifacts

## 📝 Environment Variables

```bash
# Common configuration
export GITHUB_TOKEN=your_token              # For E2E tests
export CLAUDE_CODE_OAUTH_TOKEN=your_token   # For Claude integration
export RUN_E2E_TESTS=true                   # Enable E2E tests
export BATS_TEST_TIMEOUT=300                # Test timeout
export TEST_PARALLEL=true                   # Parallel execution
export DOCKER_BUILDKIT=1                    # Faster Docker builds

# Debug options
export ACTIONS_STEP_DEBUG=true              # GitHub Actions debug
export BATS_DEBUG=1                         # BATS debug mode
export TEST_VERBOSE=true                    # Verbose output
```

## 🏷️ Test Tags and Organization

### Unit Tests by Component
```bash
# Claude setup tests
bats tests/unit/claude-setup/

# GitHub operations tests  
bats tests/unit/github-operations/

# PRP management tests
bats tests/unit/prp-management/
```

### Tests by Functionality
```bash
# Token validation
bats tests/unit/*/test_*token*.bats

# File operations
bats tests/unit/*/test_*file*.bats

# Git operations
bats tests/unit/*/test_*git*.bats

# Error handling
bats tests/unit/*/test_*error*.bats
```

## 🤝 Contributing

### Adding Tests
1. Choose appropriate test type (unit/integration/e2e)
2. Follow existing patterns and naming conventions
3. Include both success and failure scenarios
4. Update documentation if needed
5. Test locally before submitting

### Test Guidelines
- Write descriptive test names
- Use proper setup/teardown
- Mock external dependencies
- Test edge cases and errors
- Keep tests fast and reliable
- Document complex test logic

---

📖 **For detailed documentation, see:**
- [Complete Testing Guide](./TESTING_GUIDE.md)
- [Docker Testing Guide](./DOCKER_TESTING.md)
- [Test Suite README](../tests/README.md)