# Makefile for GitHub Actions Library Testing

.PHONY: help test test-unit test-integration test-e2e test-coverage test-cached test-cache-clear setup-test-env clean-test-env install-deps docker-build docker-test docker-unit docker-integration docker-security docker-performance docker-shell docker-clean docker-logs docker-status

# Configuration
TEST_TMPDIR ?= $(shell mktemp -d 2>/dev/null || echo "/tmp")/bats-actions-test

# Default target
help:
	@echo "Available targets:"
	@echo ""
	@echo "Native Testing:"
	@echo "  test              - Run all tests"
	@echo "  test-unit         - Run unit tests only"
	@echo "  test-integration  - Run integration tests only"
	@echo "  test-e2e          - Run end-to-end tests only"
	@echo "  test-coverage     - Run tests with coverage"
	@echo "  test-cached       - Run tests with caching (faster)"
	@echo "  test-cache-clear  - Clear test cache"
	@echo "  setup-test-env    - Set up test environment"
	@echo "  clean-test-env    - Clean up test environment"
	@echo "  install-deps      - Install test dependencies"
	@echo ""
	@echo "Docker Testing:"
	@echo "  docker-build      - Build Docker test container"
	@echo "  docker-test       - Run all tests in Docker"
	@echo "  docker-unit       - Run unit tests in Docker"
	@echo "  docker-integration - Run integration tests in Docker"
	@echo "  docker-security   - Run security scans in Docker"
	@echo "  docker-performance - Run performance tests in Docker"
	@echo "  docker-shell      - Start interactive Docker shell"
	@echo "  docker-clean      - Clean up Docker containers and volumes"
	@echo "  docker-logs       - Show Docker container logs"
	@echo "  docker-status     - Show Docker container status"

# Test directories
TEST_DIR := tests
UNIT_DIR := $(TEST_DIR)/unit
INTEGRATION_DIR := $(TEST_DIR)/integration
E2E_DIR := $(TEST_DIR)/e2e

# Install test dependencies
install-deps:
	@echo "Installing test dependencies..."
	@which bats >/dev/null 2>&1 || { \
		echo "Installing BATS..."; \
		if command -v npm >/dev/null 2>&1; then \
			npm install -g bats; \
		elif command -v brew >/dev/null 2>&1; then \
			brew install bats-core; \
		else \
			echo "Please install BATS manually"; \
			exit 1; \
		fi; \
	}
	@which act >/dev/null 2>&1 || { \
		echo "Installing act CLI..."; \
		OS=$$(uname -s | tr '[:upper:]' '[:lower:]'); \
		ARCH=$$(uname -m); \
		if [ "$$ARCH" = "x86_64" ]; then ARCH="x86_64"; \
		elif [ "$$ARCH" = "aarch64" ] || [ "$$ARCH" = "arm64" ]; then ARCH="arm64"; \
		else echo "Unsupported architecture: $$ARCH"; exit 1; fi; \
		if [ "$$OS" = "darwin" ]; then OS="Darwin"; \
		elif [ "$$OS" = "linux" ]; then OS="Linux"; \
		else echo "Unsupported OS: $$OS"; exit 1; fi; \
		URL="https://github.com/nektos/act/releases/latest/download/act_$${OS}_$${ARCH}.tar.gz"; \
		echo "Downloading act from: $$URL"; \
		curl -L "$$URL" | tar -xz; \
		sudo mv act /usr/local/bin/ 2>/dev/null || { \
			mkdir -p ~/bin && mv act ~/bin/ && \
			echo "Installed act to ~/bin. Please ensure ~/bin is in your PATH."; \
		}; \
	}
	@echo "Dependencies installed successfully"

# Set up test environment
setup-test-env:
	@echo "Setting up test environment..."
	@mkdir -p "$(TEST_TMPDIR)"
	@mkdir -p $(TEST_DIR)/fixtures/sample_prp_files
	@mkdir -p $(TEST_DIR)/fixtures/mock_github_responses
	@mkdir -p $(TEST_DIR)/fixtures/test_repositories
	@echo "Test environment set up"

# Clean up test environment
clean-test-env:
	@echo "Cleaning up test environment..."
	@rm -rf "$(TEST_TMPDIR)"
	@echo "Test environment cleaned"

# Run all tests
test: setup-test-env
	@echo "Running all tests..."
	@cd $(TEST_DIR) && bats --recursive .
	@$(MAKE) clean-test-env

# Run unit tests only
test-unit: setup-test-env
	@echo "Running unit tests..."
	@cd $(UNIT_DIR) && bats --recursive .
	@$(MAKE) clean-test-env

# Run integration tests only
test-integration: setup-test-env
	@echo "Running integration tests..."
	@cd $(INTEGRATION_DIR) && bats --recursive .
	@$(MAKE) clean-test-env

# Run end-to-end tests only
test-e2e: setup-test-env
	@echo "Running end-to-end tests..."
	@cd $(E2E_DIR) && bats --recursive .
	@$(MAKE) clean-test-env

# Run tests with coverage (requires additional tooling)
test-coverage: setup-test-env
	@echo "Running tests with coverage..."
	@echo "Note: Coverage reporting for shell scripts requires additional setup"
	@cd $(TEST_DIR) && bats --recursive --tap .
	@$(MAKE) clean-test-env

# Run tests with caching for faster execution
test-cached: setup-test-env
	@echo "Running tests with caching..."
	@./scripts/cached-test-runner.sh $(TEST_DIR)
	@$(MAKE) clean-test-env

# Clear test cache
test-cache-clear:
	@echo "Clearing test cache..."
	@./scripts/test-cache-manager.sh clear all

# Validate test files syntax
validate-tests:
	@echo "Validating test files..."
	@find $(TEST_DIR) -name "*.bats" -exec bash -n {} \;
	@echo "Test files validation complete"

# Run specific test file
test-file:
	@if [ -z "$(FILE)" ]; then \
		echo "Usage: make test-file FILE=path/to/test.bats"; \
		exit 1; \
	fi
	@$(MAKE) setup-test-env
	@echo "Running test file: $(FILE)"
	@cd $(TEST_DIR) && bats $(FILE)
	@$(MAKE) clean-test-env

# Run tests in watch mode (requires entr)
test-watch:
	@which entr >/dev/null 2>&1 || { \
		echo "Please install entr for watch mode"; \
		exit 1; \
	}
	@echo "Running tests in watch mode..."
	@find $(TEST_DIR) -name "*.bats" -o -name "*.bash" | entr -c make test

# Generate test report
test-report: setup-test-env
	@echo "Generating test report..."
	@mkdir -p reports
	@cd $(TEST_DIR) && bats --recursive --formatter tap . > ../reports/test-results.tap
	@cd $(TEST_DIR) && bats --recursive --formatter pretty . > ../reports/test-results.txt
	@./scripts/format-test-results.sh --format all
	@echo "Test reports generated in reports/ (Markdown, HTML, JUnit XML)"
	@$(MAKE) clean-test-env

# Docker testing targets
docker-build:
	@echo "Building Docker test container..."
	@test -f scripts/docker-test.sh || { echo "Error: scripts/docker-test.sh not found"; exit 1; }
	@./scripts/docker-test.sh build

docker-test:
	@echo "Running all tests in Docker..."
	@test -f scripts/docker-test.sh || { echo "Error: scripts/docker-test.sh not found"; exit 1; }
	@./scripts/docker-test.sh test

docker-unit:
	@echo "Running unit tests in Docker..."
	@test -f scripts/docker-test.sh || { echo "Error: scripts/docker-test.sh not found"; exit 1; }
	@./scripts/docker-test.sh unit

docker-integration:
	@echo "Running integration tests in Docker..."
	@test -f scripts/docker-test.sh || { echo "Error: scripts/docker-test.sh not found"; exit 1; }
	@./scripts/docker-test.sh integration

docker-security:
	@echo "Running security scans in Docker..."
	@test -f scripts/docker-test.sh || { echo "Error: scripts/docker-test.sh not found"; exit 1; }
	@./scripts/docker-test.sh security

docker-performance:
	@echo "Running performance tests in Docker..."
	@test -f scripts/docker-test.sh || { echo "Error: scripts/docker-test.sh not found"; exit 1; }
	@./scripts/docker-test.sh performance

docker-shell:
	@echo "Starting interactive Docker shell..."
	@test -f scripts/docker-test.sh || { echo "Error: scripts/docker-test.sh not found"; exit 1; }
	@./scripts/docker-test.sh shell

docker-clean:
	@echo "Cleaning up Docker containers and volumes..."
	@test -f scripts/docker-test.sh || { echo "Error: scripts/docker-test.sh not found"; exit 1; }
	@./scripts/docker-test.sh clean

docker-logs:
	@echo "Showing Docker container logs..."
	@test -f scripts/docker-test.sh || { echo "Error: scripts/docker-test.sh not found"; exit 1; }
	@./scripts/docker-test.sh logs

docker-status:
	@echo "Showing Docker container status..."
	@test -f scripts/docker-test.sh || { echo "Error: scripts/docker-test.sh not found"; exit 1; }
	@./scripts/docker-test.sh status

# Docker convenience targets
docker-parallel:
	@echo "Running tests in parallel with Docker..."
	@test -f scripts/docker-test.sh || { echo "Error: scripts/docker-test.sh not found"; exit 1; }
	@./scripts/docker-test.sh test --parallel

docker-validate:
	@echo "Validating Docker setup..."
	@test -f scripts/docker-test.sh || { echo "Error: scripts/docker-test.sh not found"; exit 1; }
	@./scripts/docker-test.sh validate

docker-rebuild:
	@echo "Rebuilding Docker container..."
	@test -f scripts/docker-test.sh || { echo "Error: scripts/docker-test.sh not found"; exit 1; }
	@./scripts/docker-test.sh build --no-cache