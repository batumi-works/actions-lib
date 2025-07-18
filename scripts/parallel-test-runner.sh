#!/usr/bin/env bash
# Enhanced parallel test runner with progress monitoring and real-time updates

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
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Test services to run in parallel
TEST_SERVICES=(
    "unit-tests"
    "integration-tests"
    "security-scan"
    "performance-tests"
)

# Function to get docker compose command
get_compose_cmd() {
    if command -v docker-compose &> /dev/null; then
        echo "docker-compose"
    else
        echo "docker compose"
    fi
}

# Function to display test progress
show_progress() {
    local compose_cmd=$(get_compose_cmd)
    local all_complete=false
    local start_time=$(date +%s)
    
    echo -e "${BLUE}Starting parallel test execution...${NC}"
    echo ""
    
    # Start services
    $compose_cmd -f "$COMPOSE_FILE" up -d "${TEST_SERVICES[@]}"
    
    # Monitor progress
    while [[ "$all_complete" == "false" ]]; do
        clear
        echo -e "${BOLD}=== Test Progress Monitor ===${NC}"
        echo -e "Elapsed time: $(($(date +%s) - start_time))s"
        echo ""
        
        all_complete=true
        local completed_count=0
        local failed_count=0
        
        for service in "${TEST_SERVICES[@]}"; do
            local container_id=$($compose_cmd -f "$COMPOSE_FILE" ps -q "$service" 2>/dev/null)
            
            if [[ -z "$container_id" ]]; then
                echo -e "${YELLOW}⏳ $service: Starting...${NC}"
                all_complete=false
                continue
            fi
            
            local status=$(docker inspect "$container_id" --format='{{.State.Status}}' 2>/dev/null || echo "unknown")
            local exit_code=$(docker inspect "$container_id" --format='{{.State.ExitCode}}' 2>/dev/null || echo "-1")
            
            case "$status" in
                "running")
                    # Get last log line for progress indicator
                    local last_log=$(docker logs "$container_id" 2>&1 | tail -n 1 | cut -c1-50)
                    echo -e "${BLUE}🔄 $service: Running${NC} - $last_log..."
                    all_complete=false
                    ;;
                "exited")
                    if [[ "$exit_code" == "0" ]]; then
                        echo -e "${GREEN}✅ $service: Completed successfully${NC}"
                        ((completed_count++))
                    else
                        echo -e "${RED}❌ $service: Failed (exit code: $exit_code)${NC}"
                        ((failed_count++))
                    fi
                    ;;
                *)
                    echo -e "${YELLOW}❓ $service: Status unknown ($status)${NC}"
                    all_complete=false
                    ;;
            esac
        done
        
        echo ""
        echo -e "Progress: ${completed_count}/${#TEST_SERVICES[@]} completed, ${failed_count} failed"
        
        if [[ "$all_complete" == "false" ]]; then
            sleep 2
        fi
    done
    
    return $failed_count
}

# Function to collect and display results
collect_results() {
    local compose_cmd=$(get_compose_cmd)
    local failed_services=()
    
    echo ""
    echo -e "${BOLD}=== Test Results Summary ===${NC}"
    echo ""
    
    for service in "${TEST_SERVICES[@]}"; do
        local container_id=$($compose_cmd -f "$COMPOSE_FILE" ps -q "$service" 2>/dev/null)
        local exit_code=$(docker inspect "$container_id" --format='{{.State.ExitCode}}' 2>/dev/null || echo "-1")
        
        if [[ "$exit_code" == "0" ]]; then
            echo -e "${GREEN}✅ $service: PASSED${NC}"
        else
            echo -e "${RED}❌ $service: FAILED (exit code: $exit_code)${NC}"
            failed_services+=("$service")
        fi
    done
    
    echo ""
    
    # Show failed service logs
    if [[ ${#failed_services[@]} -gt 0 ]]; then
        echo -e "${RED}Failed services logs:${NC}"
        for service in "${failed_services[@]}"; do
            echo ""
            echo -e "${YELLOW}=== $service logs ===${NC}"
            $compose_cmd -f "$COMPOSE_FILE" logs --tail=50 "$service"
        done
        return 1
    fi
    
    return 0
}

# Function to generate combined report
generate_combined_report() {
    local compose_cmd=$(get_compose_cmd)
    
    echo ""
    echo -e "${BLUE}Generating combined test report...${NC}"
    
    # Ensure reports directory exists
    mkdir -p "$PROJECT_DIR/reports"
    
    # Combine TAP outputs if they exist
    if ls "$PROJECT_DIR/reports"/*-results.tap 1> /dev/null 2>&1; then
        cat "$PROJECT_DIR/reports"/*-results.tap > "$PROJECT_DIR/reports/combined-results.tap"
        
        # Generate formatted reports
        "$PROJECT_DIR/scripts/format-test-results.sh" "$PROJECT_DIR/reports/combined-results.tap"
    fi
    
    # Run report generator service
    $compose_cmd -f "$COMPOSE_FILE" up test-reports
}

# Main function
main() {
    local start_time=$(date +%s)
    
    # Show progress and wait for completion
    if show_progress; then
        # All tests passed
        echo ""
        echo -e "${GREEN}${BOLD}All tests completed successfully!${NC}"
        
        # Generate reports
        generate_combined_report
        
        local duration=$(($(date +%s) - start_time))
        echo ""
        echo -e "${BLUE}Total execution time: ${duration}s${NC}"
        
        exit 0
    else
        # Some tests failed
        collect_results
        
        local duration=$(($(date +%s) - start_time))
        echo ""
        echo -e "${RED}${BOLD}Some tests failed!${NC}"
        echo -e "${BLUE}Total execution time: ${duration}s${NC}"
        
        exit 1
    fi
}

# Handle interrupts gracefully
trap 'echo -e "\n${YELLOW}Interrupted! Stopping tests...${NC}"; $(get_compose_cmd) -f "$COMPOSE_FILE" stop; exit 130' INT TERM

# Run main function
main "$@"