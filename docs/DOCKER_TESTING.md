# Docker Testing Guide

This guide explains how to use Docker for running the GitHub Actions test suite in a containerized environment.

## 🐳 Overview

The Docker testing setup provides:
- **Isolated Environment**: Consistent testing environment across different systems
- **Reproducible Results**: Same results regardless of host system configuration
- **Easy Setup**: No need to install dependencies on host system
- **Parallel Testing**: Multiple test types can run simultaneously
- **CI/CD Ready**: Perfect for automated testing pipelines

## 📁 Docker Files Structure

```
actions-lib/
├── Dockerfile.test           # Main test container image
├── docker-compose.test.yml   # Multi-service test orchestration
├── .dockerignore            # Files to exclude from Docker context
└── docs/
    └── DOCKER_TESTING.md    # This documentation
```

## 🚀 Quick Start

### Prerequisites
- Docker Engine 20.10+
- Docker Compose 2.0+
- 4GB+ available RAM
- 2GB+ available disk space

### Basic Usage

```bash
# Build test container
docker build -f Dockerfile.test -t actions-test .

# Run all tests
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock actions-test

# Run with docker-compose (recommended)
docker-compose -f docker-compose.test.yml up test-runner
```

## 🛠️ Docker Compose Services

### Available Services

#### `test-runner` (Default)
Runs the complete test suite including unit, integration, and security tests.

```bash
# Run all tests
docker-compose -f docker-compose.test.yml up test-runner

# Run in background
docker-compose -f docker-compose.test.yml up -d test-runner

# View logs
docker-compose -f docker-compose.test.yml logs test-runner
```

#### `unit-tests`
Runs only unit tests for faster feedback during development.

```bash
# Run unit tests only
docker-compose -f docker-compose.test.yml up unit-tests
```

#### `integration-tests`
Runs integration tests using act CLI with Docker-in-Docker.

```bash
# Run integration tests
docker-compose -f docker-compose.test.yml up integration-tests
```

#### `security-scan`
Performs security scanning with ShellCheck and other security tools.

```bash
# Run security scan
docker-compose -f docker-compose.test.yml up security-scan
```

#### `performance-tests`
Runs performance benchmarks and timing analysis.

```bash
# Run performance tests
docker-compose -f docker-compose.test.yml up performance-tests
```

#### `test-reports`
Generates comprehensive test reports from all test results.

```bash
# Generate reports (after running other tests)
docker-compose -f docker-compose.test.yml up test-reports
```

#### `dev-shell`
Interactive development environment for debugging and manual testing.

```bash
# Start interactive shell
docker-compose -f docker-compose.test.yml run dev-shell

# Inside the container
make test-unit
bats tests/unit/claude-setup/test_checkout.bats
act --dryrun
```

### Running Multiple Services

```bash
# Run all test types in parallel
docker-compose -f docker-compose.test.yml up \
  unit-tests \
  integration-tests \
  security-scan \
  performance-tests

# Run complete pipeline with reports
docker-compose -f docker-compose.test.yml up \
  unit-tests \
  integration-tests \
  security-scan \
  performance-tests \
  test-reports
```

## 📊 Volume Management

### Persistent Volumes

The setup uses named volumes for better performance and persistence:

- **`test-cache`**: Stores temporary test files and cache
- **`test-reports`**: Persists test reports and artifacts

```bash
# View volumes
docker volume ls | grep actions

# Inspect volume
docker volume inspect actions-lib_test-reports

# Clean up volumes
docker-compose -f docker-compose.test.yml down -v
```

### Host Mounts

- **Source Code**: `.:/workspace` (live reload for development)
- **Docker Socket**: `/var/run/docker.sock` (for act CLI integration)
- **Reports**: Local `./reports` directory

## 🔧 Configuration

### Environment Variables

Set these variables to customize test behavior:

```bash
# In docker-compose.test.yml or .env file
GITHUB_ACTIONS=false          # Disable GitHub Actions mode
CI=true                       # Enable CI mode
BATS_LIB_PATH=/usr/lib/bats  # BATS library path
TEST_TMPDIR=/workspace/.test-cache  # Temporary directory
RUN_E2E_TESTS=false          # Skip E2E tests by default
GITHUB_TOKEN=your_token      # For E2E tests (if needed)
```

### Test Configuration

Create a `.env` file for custom configuration:

```bash
# .env
GITHUB_TOKEN=your_github_token_here
CLAUDE_CODE_OAUTH_TOKEN=your_claude_token_here
RUN_E2E_TESTS=true
TEST_PARALLEL=true
BATS_TEST_TIMEOUT=300
```

Then run with:
```bash
docker-compose -f docker-compose.test.yml --env-file .env up test-runner
```

## 🚦 Common Workflows

### Development Workflow

```bash
# 1. Start development shell
docker-compose -f docker-compose.test.yml run dev-shell

# 2. Inside container - run specific tests
bats tests/unit/claude-setup/
make test-unit

# 3. Test changes with act
act --dryrun --verbose

# 4. Exit and run full test suite
exit
docker-compose -f docker-compose.test.yml up test-runner
```

### CI/CD Pipeline

```bash
#!/bin/bash
# ci-test.sh

set -e

echo "🚀 Starting CI test pipeline..."

# Build test image
docker build -f Dockerfile.test -t actions-test:$BUILD_ID .

# Run test pipeline
docker-compose -f docker-compose.test.yml up --abort-on-container-exit \
  unit-tests \
  integration-tests \
  security-scan \
  performance-tests

# Generate reports
docker-compose -f docker-compose.test.yml up test-reports

# Extract reports
docker cp $(docker-compose -f docker-compose.test.yml ps -q test-reports):/workspace/reports ./ci-reports

echo "✅ CI test pipeline completed"
```

### Debug Failed Tests

```bash
# 1. Run tests and keep container for debugging
docker-compose -f docker-compose.test.yml up --no-deps unit-tests

# 2. Access the container
docker-compose -f docker-compose.test.yml exec unit-tests bash

# 3. Run specific failing test
bats -t tests/unit/claude-setup/test_specific_failure.bats

# 4. Examine logs and state
cat /workspace/.test-cache/bats-test/mock_git_calls
ls -la /workspace/reports/
```

## 📈 Performance Optimization

### Build Optimization

```bash
# Use BuildKit for faster builds
DOCKER_BUILDKIT=1 docker build -f Dockerfile.test -t actions-test .

# Multi-stage build for smaller images
docker build --target test-runner -f Dockerfile.test -t actions-test:slim .
```

### Resource Limits

```yaml
# In docker-compose.test.yml
services:
  test-runner:
    deploy:
      resources:
        limits:
          memory: 2G
          cpus: '2.0'
        reservations:
          memory: 1G
          cpus: '1.0'
```

### Parallel Testing

```bash
# Run tests in parallel
docker-compose -f docker-compose.test.yml up -d \
  unit-tests \
  security-scan \
  performance-tests

# Wait for completion
docker-compose -f docker-compose.test.yml wait unit-tests security-scan performance-tests
```

## 🔍 Troubleshooting

### Common Issues

#### **Permission Denied Errors**
```bash
# Fix: Run with proper user mapping
docker run --rm -v "$(pwd)":/workspace --user "$(id -u):$(id -g)" actions-test
```

#### **Docker Socket Issues**
```bash
# Fix: Ensure Docker socket is accessible
ls -la /var/run/docker.sock
sudo chmod 666 /var/run/docker.sock  # Temporary fix
sudo usermod -aG docker $USER        # Permanent fix (requires re-login)
```

#### **Out of Space**
```bash
# Clean up Docker resources
docker system prune -a
docker volume prune
docker-compose -f docker-compose.test.yml down -v --remove-orphans
```

#### **Build Failures**
```bash
# Build with verbose output
docker build --progress=plain --no-cache -f Dockerfile.test -t actions-test .

# Check build logs
docker-compose -f docker-compose.test.yml build --no-cache test-runner
```

### Debug Commands

```bash
# Check container health
docker-compose -f docker-compose.test.yml ps
docker-compose -f docker-compose.test.yml logs test-runner

# Inspect container
docker inspect $(docker-compose -f docker-compose.test.yml ps -q test-runner)

# Check resource usage
docker stats $(docker-compose -f docker-compose.test.yml ps -q)

# Access running container
docker-compose -f docker-compose.test.yml exec test-runner bash
```

## 🔒 Security Considerations

### Container Security

- **Non-root User**: Tests run as `testuser` (non-root)
- **Read-only Filesystem**: Most directories are read-only
- **Resource Limits**: Memory and CPU limits prevent resource exhaustion
- **Network Isolation**: Tests run in isolated network

### Secret Management

```bash
# Never build secrets into images
echo "GITHUB_TOKEN=secret" > .env
echo ".env" >> .gitignore

# Use Docker secrets for sensitive data
echo "my_secret" | docker secret create github_token -
```

### Security Scanning

```bash
# Scan container for vulnerabilities
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  -v "$PWD":/workspace \
  aquasec/trivy image actions-test
```

## 📚 Advanced Usage

### Custom Test Images

```dockerfile
# Dockerfile.custom-test
FROM actions-test:latest

# Add custom tools
RUN apt-get update && apt-get install -y your-custom-tool

# Custom configuration
COPY custom-test-config.sh /usr/local/bin/
```

### Multi-Architecture Builds

```bash
# Build for multiple architectures
docker buildx create --use
docker buildx build --platform linux/amd64,linux/arm64 -f Dockerfile.test -t actions-test:multi .
```

### Integration with CI Systems

#### GitHub Actions
```yaml
# .github/workflows/docker-tests.yml
- name: Run Docker Tests
  run: |
    docker-compose -f docker-compose.test.yml up --abort-on-container-exit test-runner
```

#### GitLab CI
```yaml
# .gitlab-ci.yml
test:
  image: docker:latest
  services:
    - docker:dind
  script:
    - docker-compose -f docker-compose.test.yml up --abort-on-container-exit test-runner
```

## 📝 Best Practices

1. **Use Specific Tags**: Pin Docker image versions for reproducibility
2. **Layer Caching**: Order Dockerfile commands to maximize cache hits
3. **Multi-stage Builds**: Separate build and runtime environments
4. **Health Checks**: Always include health checks for services
5. **Resource Limits**: Set appropriate memory and CPU limits
6. **Volume Management**: Use named volumes for persistent data
7. **Security**: Run as non-root user, scan for vulnerabilities
8. **Documentation**: Keep Docker documentation up to date

## 🤝 Contributing

When modifying Docker configuration:

1. Test changes locally with `docker build` and `docker-compose up`
2. Update documentation in this file
3. Verify changes work on different platforms
4. Test with various Docker versions
5. Update CI/CD pipelines if needed

## 📞 Support

For Docker-related issues:

1. Check this documentation
2. Review Docker and Docker Compose logs
3. Verify system requirements
4. Check GitHub Issues for known problems
5. Create new issue with Docker version and error details

---

🐳 **Happy Dockerized Testing!** 🧪