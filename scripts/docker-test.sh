#!/usr/bin/env bash
# Docker testing wrapper script for GitHub Actions library

set -e

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPOSE_FILE="$PROJECT_DIR/docker-compose.test.yml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Help function
show_help() {
    cat << EOF
🐳 Docker Testing Script for GitHub Actions Library

USAGE:
    $0 [COMMAND] [OPTIONS]

COMMANDS:
    build                Build the test container image
    test                 Run all tests (default)
    unit                 Run unit tests only
    integration          Run integration tests only
    security             Run security scans
    performance          Run performance benchmarks
    reports              Generate test reports
    shell                Start interactive development shell
    clean                Clean up containers and volumes
    logs [SERVICE]       Show logs for service
    status               Show status of all services
    validate             Validate Docker setup

OPTIONS:
    -h, --help           Show this help message
    -v, --verbose        Enable verbose output
    -d, --detach         Run in detached mode
    --no-cache           Build without using cache
    --parallel           Run tests in parallel
    --rebuild            Force rebuild of containers

EXAMPLES:
    $0 build                    # Build test container
    $0 test                     # Run all tests
    $0 unit --verbose           # Run unit tests with verbose output
    $0 shell                    # Start interactive shell
    $0 clean                    # Clean up everything
    $0 logs test-runner         # Show logs for test-runner service
    $0 test --parallel          # Run tests in parallel

ENVIRONMENT VARIABLES:
    GITHUB_TOKEN               GitHub API token for E2E tests
    CLAUDE_CODE_OAUTH_TOKEN    Claude Code OAuth token
    RUN_E2E_TESTS             Set to 'true' to enable E2E tests
    DOCKER_BUILDKIT           Set to '1' for faster builds

For more information, see docs/DOCKER_TESTING.md
EOF
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    local errors=0
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed or not in PATH"
        ((errors++))
    else
        log_info "Docker: $(docker --version)"
    fi
    
    # Check Docker Compose
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        log_error "Docker Compose is not installed or not in PATH"
        ((errors++))
    else
        if command -v docker-compose &> /dev/null; then
            log_info "Docker Compose: $(docker-compose --version)"
        else
            log_info "Docker Compose: $(docker compose version)"
        fi
    fi
    
    # Check Docker daemon
    if ! docker info &> /dev/null; then
        log_error "Docker daemon is not running"
        ((errors++))
    fi
    
    # Check disk space
    local available_space=$(df "$PROJECT_DIR" | awk 'NR==2 {print $4}')
    local required_space=2000000  # 2GB in KB
    
    if [ "$available_space" -lt "$required_space" ]; then
        log_warning "Low disk space: $(($available_space / 1024))MB available, 2GB recommended"
    fi
    
    if [ $errors -gt 0 ]; then
        log_error "Prerequisites check failed. Please install missing dependencies."
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Get Docker Compose command
get_compose_cmd() {
    if command -v docker-compose &> /dev/null; then
        echo "docker-compose"
    else
        echo "docker compose"
    fi
}

# Build container
build_container() {
    local no_cache=""
    if [[ "$1" == "--no-cache" ]]; then
        no_cache="--no-cache"
    fi
    
    log_info "Building test container..."
    
    cd "$PROJECT_DIR"
    
    # Use BuildKit for faster builds
    export DOCKER_BUILDKIT=1
    
    if docker build $no_cache -f Dockerfile.test -t actions-test .; then
        log_success "Container built successfully"
    else
        log_error "Container build failed"
        exit 1
    fi
}

# Run tests
run_tests() {
    local service="$1"
    local detach=""
    local verbose=""
    
    shift
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -d|--detach)
                detach="-d"
                shift
                ;;
            -v|--verbose)
                verbose="--verbose"
                shift
                ;;
            --parallel)
                run_parallel_tests
                return
                ;;
            *)
                shift
                ;;
        esac
    done
    
    local compose_cmd=$(get_compose_cmd)
    
    log_info "Running $service tests..."
    
    cd "$PROJECT_DIR"
    
    if $compose_cmd -f "$COMPOSE_FILE" up $detach --abort-on-container-exit $service; then
        if [[ -z "$detach" ]]; then
            log_success "$service tests completed successfully"
        else
            log_info "$service tests started in background"
        fi
    else
        log_error "$service tests failed"
        exit 1
    fi
}

# Run parallel tests
run_parallel_tests() {
    local compose_cmd=$(get_compose_cmd)
    
    log_info "Running tests in parallel..."
    
    cd "$PROJECT_DIR"
    
    # Start all test services in parallel
    $compose_cmd -f "$COMPOSE_FILE" up -d \
        unit-tests \
        integration-tests \
        security-scan \
        performance-tests
    
    # Wait for completion
    log_info "Waiting for parallel tests to complete..."
    
    $compose_cmd -f "$COMPOSE_FILE" wait \
        unit-tests \
        integration-tests \
        security-scan \
        performance-tests
    
    # Check exit codes
    local failed_services=()
    
    for service in unit-tests integration-tests security-scan performance-tests; do
        local exit_code=$($compose_cmd -f "$COMPOSE_FILE" ps -q $service | xargs docker inspect --format='{{.State.ExitCode}}')
        if [[ "$exit_code" != "0" ]]; then
            failed_services+=($service)
        fi
    done
    
    if [[ ${#failed_services[@]} -eq 0 ]]; then
        log_success "All parallel tests completed successfully"
        
        # Generate reports
        log_info "Generating test reports..."
        $compose_cmd -f "$COMPOSE_FILE" up test-reports
    else
        log_error "The following services failed: ${failed_services[*]}"
        
        # Show logs for failed services
        for service in "${failed_services[@]}"; do
            log_error "Logs for failed service: $service"
            $compose_cmd -f "$COMPOSE_FILE" logs $service
        done
        
        exit 1
    fi
}

# Start interactive shell
start_shell() {
    local compose_cmd=$(get_compose_cmd)
    
    log_info "Starting interactive development shell..."
    log_info "Available commands:"
    log_info "  make test-unit              # Run unit tests"
    log_info "  bats tests/unit/...         # Run specific test file"
    log_info "  act --dryrun               # Test with act CLI"
    log_info "  exit                       # Exit shell"
    
    cd "$PROJECT_DIR"
    
    $compose_cmd -f "$COMPOSE_FILE" run --rm dev-shell
}

# Clean up
cleanup() {
    local compose_cmd=$(get_compose_cmd)
    
    log_info "Cleaning up containers and volumes..."
    
    cd "$PROJECT_DIR"
    
    # Stop and remove containers
    $compose_cmd -f "$COMPOSE_FILE" down --remove-orphans
    
    # Remove volumes
    $compose_cmd -f "$COMPOSE_FILE" down -v
    
    # Remove test image
    if docker image inspect actions-test &> /dev/null; then
        docker rmi actions-test
        log_info "Removed test image"
    fi
    
    # Clean up Docker system
    docker system prune -f
    
    log_success "Cleanup completed"
}

# Show logs
show_logs() {
    local service="$1"
    local compose_cmd=$(get_compose_cmd)
    
    cd "$PROJECT_DIR"
    
    if [[ -n "$service" ]]; then
        log_info "Showing logs for service: $service"
        $compose_cmd -f "$COMPOSE_FILE" logs $service
    else
        log_info "Showing logs for all services"
        $compose_cmd -f "$COMPOSE_FILE" logs
    fi
}

# Show status
show_status() {
    local compose_cmd=$(get_compose_cmd)
    
    log_info "Showing status of all services..."
    
    cd "$PROJECT_DIR"
    
    $compose_cmd -f "$COMPOSE_FILE" ps
    
    echo ""
    log_info "Docker system info:"
    docker system df
}

# Validate setup
validate_setup() {
    log_info "Validating Docker setup..."
    
    check_prerequisites
    
    # Check compose file
    if [[ ! -f "$COMPOSE_FILE" ]]; then
        log_error "Docker Compose file not found: $COMPOSE_FILE"
        exit 1
    fi
    
    local compose_cmd=$(get_compose_cmd)
    
    # Validate compose file
    cd "$PROJECT_DIR"
    if $compose_cmd -f "$COMPOSE_FILE" config > /dev/null; then
        log_success "Docker Compose file is valid"
    else
        log_error "Docker Compose file validation failed"
        exit 1
    fi
    
    # Check Dockerfile
    if [[ ! -f "$PROJECT_DIR/Dockerfile.test" ]]; then
        log_error "Dockerfile.test not found"
        exit 1
    fi
    
    log_success "Docker setup validation completed"
}

# Main function
main() {
    local command="test"
    local options=()
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            build|test|unit|integration|security|performance|reports|shell|clean|logs|status|validate)
                command="$1"
                shift
                ;;
            *)
                options+=("$1")
                shift
                ;;
        esac
    done
    
    # Change to project directory
    cd "$PROJECT_DIR"
    
    # Execute command
    case $command in
        build)
            check_prerequisites
            build_container "${options[@]}"
            ;;
        test)
            check_prerequisites
            build_container
            run_tests "test-runner" "${options[@]}"
            ;;
        unit)
            check_prerequisites
            build_container
            run_tests "unit-tests" "${options[@]}"
            ;;
        integration)
            check_prerequisites
            build_container
            run_tests "integration-tests" "${options[@]}"
            ;;
        security)
            check_prerequisites
            build_container
            run_tests "security-scan" "${options[@]}"
            ;;
        performance)
            check_prerequisites
            build_container
            run_tests "performance-tests" "${options[@]}"
            ;;
        reports)
            check_prerequisites
            run_tests "test-reports" "${options[@]}"
            ;;
        shell)
            check_prerequisites
            build_container
            start_shell
            ;;
        clean)
            cleanup
            ;;
        logs)
            show_logs "${options[0]}"
            ;;
        status)
            show_status
            ;;
        validate)
            validate_setup
            ;;
        *)
            log_error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"