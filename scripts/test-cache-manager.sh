#!/usr/bin/env bash
# Test cache management for faster test execution

set -e

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CACHE_DIR="$PROJECT_DIR/.test-cache"
CACHE_MANIFEST="$CACHE_DIR/manifest.json"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Initialize cache directory
init_cache() {
    mkdir -p "$CACHE_DIR"/{bats,act,deps,results}
    
    # Create manifest if it doesn't exist
    if [[ ! -f "$CACHE_MANIFEST" ]]; then
        echo '{"version": "1.0", "entries": {}}' > "$CACHE_MANIFEST"
    fi
    
    echo -e "${BLUE}Test cache initialized at: $CACHE_DIR${NC}"
}

# Calculate checksum for a file or directory
calculate_checksum() {
    local path="$1"
    
    if [[ -f "$path" ]]; then
        # Single file
        sha256sum "$path" | cut -d' ' -f1
    elif [[ -d "$path" ]]; then
        # Directory - checksum all files
        find "$path" -type f -exec sha256sum {} \; | \
            sort | sha256sum | cut -d' ' -f1
    else
        echo "NOTFOUND"
    fi
}

# Get cache key for a test file
get_cache_key() {
    local test_file="$1"
    local test_checksum=$(calculate_checksum "$test_file")
    
    # Include dependencies in cache key
    local deps_checksum=""
    
    # Check for test helper files
    local test_dir=$(dirname "$test_file")
    if [[ -f "$test_dir/../utils/test_helpers.bash" ]]; then
        deps_checksum=$(calculate_checksum "$test_dir/../utils/test_helpers.bash")
    fi
    
    # Combine checksums
    echo "${test_checksum}_${deps_checksum}"
}

# Check if test results are cached
is_cached() {
    local test_file="$1"
    local cache_key=$(get_cache_key "$test_file")
    local cache_file="$CACHE_DIR/results/${cache_key}.tap"
    
    if [[ -f "$cache_file" ]]; then
        # Check if cache is still valid (not older than 1 hour)
        local cache_age=$(($(date +%s) - $(stat -f %m "$cache_file" 2>/dev/null || stat -c %Y "$cache_file")))
        if [[ $cache_age -lt 3600 ]]; then
            return 0
        fi
    fi
    
    return 1
}

# Cache test results
cache_results() {
    local test_file="$1"
    local results_file="$2"
    local exit_code="$3"
    
    local cache_key=$(get_cache_key "$test_file")
    local cache_file="$CACHE_DIR/results/${cache_key}.tap"
    local meta_file="$CACHE_DIR/results/${cache_key}.meta"
    
    # Copy results to cache
    cp "$results_file" "$cache_file"
    
    # Save metadata
    cat > "$meta_file" <<EOF
{
    "test_file": "$test_file",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "exit_code": $exit_code,
    "duration": "${TEST_DURATION:-0}"
}
EOF
    
    echo -e "${GREEN}Cached results for: $test_file${NC}"
}

# Retrieve cached results
get_cached_results() {
    local test_file="$1"
    local cache_key=$(get_cache_key "$test_file")
    local cache_file="$CACHE_DIR/results/${cache_key}.tap"
    
    if [[ -f "$cache_file" ]]; then
        cat "$cache_file"
        return 0
    fi
    
    return 1
}

# Cache Docker build layers
cache_docker_layers() {
    local image_name="$1"
    local cache_key="$2"
    
    # Export Docker image layers
    local cache_file="$CACHE_DIR/docker/${cache_key}.tar"
    
    echo -e "${BLUE}Caching Docker layers for: $image_name${NC}"
    docker save "$image_name" | gzip > "${cache_file}.gz"
}

# Restore Docker build layers
restore_docker_layers() {
    local cache_key="$1"
    local cache_file="$CACHE_DIR/docker/${cache_key}.tar.gz"
    
    if [[ -f "$cache_file" ]]; then
        echo -e "${BLUE}Restoring Docker layers from cache${NC}"
        gunzip -c "$cache_file" | docker load
        return 0
    fi
    
    return 1
}

# Cache dependencies
cache_dependencies() {
    local deps_type="$1"  # npm, pip, etc.
    local deps_file="$2"  # package.json, requirements.txt, etc.
    
    local deps_checksum=$(calculate_checksum "$deps_file")
    local cache_key="${deps_type}_${deps_checksum}"
    local cache_dir="$CACHE_DIR/deps/$cache_key"
    
    case "$deps_type" in
        "bats")
            if [[ -d "/usr/lib/bats" ]]; then
                cp -r /usr/lib/bats "$cache_dir"
                echo -e "${GREEN}Cached BATS dependencies${NC}"
            fi
            ;;
        "act")
            if command -v act &> /dev/null; then
                local act_path=$(which act)
                mkdir -p "$cache_dir"
                cp "$act_path" "$cache_dir/"
                echo -e "${GREEN}Cached act CLI${NC}"
            fi
            ;;
    esac
}

# Clear cache
clear_cache() {
    local cache_type="${1:-all}"
    
    case "$cache_type" in
        "all")
            rm -rf "$CACHE_DIR"
            init_cache
            echo -e "${YELLOW}Cleared all cache${NC}"
            ;;
        "results")
            rm -rf "$CACHE_DIR/results"/*
            echo -e "${YELLOW}Cleared test results cache${NC}"
            ;;
        "docker")
            rm -rf "$CACHE_DIR/docker"/*
            echo -e "${YELLOW}Cleared Docker cache${NC}"
            ;;
        "deps")
            rm -rf "$CACHE_DIR/deps"/*
            echo -e "${YELLOW}Cleared dependencies cache${NC}"
            ;;
        *)
            echo "Unknown cache type: $cache_type"
            echo "Valid types: all, results, docker, deps"
            return 1
            ;;
    esac
}

# Show cache statistics
show_cache_stats() {
    echo -e "${BLUE}=== Test Cache Statistics ===${NC}"
    
    # Cache size
    local cache_size=$(du -sh "$CACHE_DIR" 2>/dev/null | cut -f1)
    echo "Total cache size: $cache_size"
    
    # Results cache
    local results_count=$(find "$CACHE_DIR/results" -name "*.tap" 2>/dev/null | wc -l)
    echo "Cached test results: $results_count"
    
    # Docker cache
    local docker_count=$(find "$CACHE_DIR/docker" -name "*.tar.gz" 2>/dev/null | wc -l)
    echo "Cached Docker images: $docker_count"
    
    # Age of oldest cache entry
    if [[ $results_count -gt 0 ]]; then
        local oldest=$(find "$CACHE_DIR/results" -name "*.tap" -exec stat -f %m {} \; 2>/dev/null | \
                      sort -n | head -1)
        if [[ -n "$oldest" ]]; then
            local age=$(($(date +%s) - oldest))
            echo "Oldest cache entry: $((age / 3600)) hours ago"
        fi
    fi
}

# Main function
main() {
    local command="${1:-help}"
    shift || true
    
    case "$command" in
        "init")
            init_cache
            ;;
        "check")
            if is_cached "$1"; then
                echo "CACHED"
                exit 0
            else
                echo "NOT_CACHED"
                exit 1
            fi
            ;;
        "get")
            get_cached_results "$1"
            ;;
        "save")
            cache_results "$1" "$2" "${3:-0}"
            ;;
        "clear")
            clear_cache "$1"
            ;;
        "stats")
            show_cache_stats
            ;;
        "help"|*)
            echo "Test Cache Manager"
            echo "Usage: $0 <command> [args]"
            echo ""
            echo "Commands:"
            echo "  init          Initialize cache directory"
            echo "  check <file>  Check if test results are cached"
            echo "  get <file>    Get cached test results"
            echo "  save <file> <results> [exit_code]  Save test results to cache"
            echo "  clear [type]  Clear cache (all|results|docker|deps)"
            echo "  stats         Show cache statistics"
            ;;
    esac
}

# Run main function
main "$@"