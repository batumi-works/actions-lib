#!/usr/bin/env bash
# Cached test runner for faster test execution

set -e

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CACHE_MANAGER="$SCRIPT_DIR/test-cache-manager.sh"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Initialize cache
"$CACHE_MANAGER" init

# Function to run a single test with caching
run_cached_test() {
    local test_file="$1"
    local output_file="${2:-/tmp/test-output.tap}"
    
    # Check if results are cached
    if "$CACHE_MANAGER" check "$test_file" 2>/dev/null; then
        echo -e "${CYAN}⚡ Using cached results for: $test_file${NC}"
        "$CACHE_MANAGER" get "$test_file" > "$output_file"
        return 0
    fi
    
    # Run the test
    echo -e "${BLUE}🔄 Running test: $test_file${NC}"
    
    local start_time=$(date +%s)
    local exit_code=0
    
    # Run BATS test
    if bats "$test_file" > "$output_file" 2>&1; then
        echo -e "${GREEN}✅ Test passed: $test_file${NC}"
    else
        exit_code=$?
        echo -e "${YELLOW}❌ Test failed: $test_file${NC}"
    fi
    
    local end_time=$(date +%s)
    export TEST_DURATION=$((end_time - start_time))
    
    # Cache the results
    "$CACHE_MANAGER" save "$test_file" "$output_file" "$exit_code"
    
    return $exit_code
}

# Function to run tests in parallel with caching
run_parallel_cached() {
    local test_files=("$@")
    local max_jobs=${MAX_PARALLEL_JOBS:-4}
    local pids=()
    local results_dir="/tmp/cached-test-results-$$"
    
    mkdir -p "$results_dir"
    
    echo -e "${BLUE}Running ${#test_files[@]} tests with caching (max $max_jobs parallel)${NC}"
    
    # Start tests in parallel
    for i in "${!test_files[@]}"; do
        local test_file="${test_files[$i]}"
        local output_file="$results_dir/result-$i.tap"
        
        # Run test in background
        (run_cached_test "$test_file" "$output_file") &
        pids+=($!)
        
        # Limit parallel jobs
        if [[ ${#pids[@]} -ge $max_jobs ]]; then
            # Wait for any job to complete
            wait -n
            # Remove completed PIDs
            local new_pids=()
            for pid in "${pids[@]}"; do
                if kill -0 "$pid" 2>/dev/null; then
                    new_pids+=("$pid")
                fi
            done
            pids=("${new_pids[@]}")
        fi
    done
    
    # Wait for all remaining jobs
    for pid in "${pids[@]}"; do
        wait "$pid"
    done
    
    # Combine results
    echo -e "${BLUE}Combining test results...${NC}"
    cat "$results_dir"/*.tap > "$PROJECT_DIR/reports/cached-results.tap" 2>/dev/null || true
    
    # Clean up
    rm -rf "$results_dir"
}

# Function to run tests by directory with caching
run_directory_cached() {
    local test_dir="$1"
    local pattern="${2:-*.bats}"
    
    echo -e "${BLUE}Scanning directory: $test_dir${NC}"
    
    # Find all test files
    local test_files=()
    while IFS= read -r -d '' file; do
        test_files+=("$file")
    done < <(find "$test_dir" -name "$pattern" -type f -print0 | sort -z)
    
    if [[ ${#test_files[@]} -eq 0 ]]; then
        echo -e "${YELLOW}No test files found in: $test_dir${NC}"
        return 0
    fi
    
    # Show cache statistics
    "$CACHE_MANAGER" stats
    echo ""
    
    # Run tests with caching
    run_parallel_cached "${test_files[@]}"
}

# Main function
main() {
    local test_target="${1:-.}"
    
    # Ensure reports directory exists
    mkdir -p "$PROJECT_DIR/reports"
    
    if [[ -f "$test_target" ]]; then
        # Single file
        run_cached_test "$test_target"
    elif [[ -d "$test_target" ]]; then
        # Directory
        run_directory_cached "$test_target"
    else
        echo "Error: Invalid test target: $test_target"
        exit 1
    fi
    
    # Generate formatted reports
    if [[ -f "$PROJECT_DIR/scripts/format-test-results.sh" ]]; then
        "$PROJECT_DIR/scripts/format-test-results.sh" "$PROJECT_DIR/reports/cached-results.tap"
    fi
    
    # Show final cache statistics
    echo ""
    "$CACHE_MANAGER" stats
}

# Handle cleanup on exit
trap 'echo -e "\n${YELLOW}Test run interrupted${NC}"' INT TERM

# Run main function
main "$@"