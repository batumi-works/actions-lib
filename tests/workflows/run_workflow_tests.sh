#!/bin/bash
# Run workflow tests

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Running GitHub Actions Workflow Tests${NC}"
echo "========================================"

# Check if BATS is installed
if ! command -v bats &> /dev/null; then
    echo -e "${RED}ERROR: BATS is not installed${NC}"
    echo "Please install BATS: npm install -g bats"
    exit 1
fi

# Check if yq is installed (needed for YAML validation)
if ! command -v yq &> /dev/null; then
    echo -e "${YELLOW}WARNING: yq is not installed${NC}"
    echo "Some tests may be skipped. Install yq for full test coverage."
fi

# Check if act is installed (needed for integration tests)
if ! command -v act &> /dev/null; then
    echo -e "${YELLOW}WARNING: act CLI is not installed${NC}"
    echo "Integration tests will be skipped. Install act for full test coverage."
    echo "Install with: curl -L https://github.com/nektos/act/releases/latest/download/act_Linux_x86_64.tar.gz | tar -xz && sudo mv act /usr/local/bin/"
fi

# Find all workflow test files
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
TEST_FILES=("$SCRIPT_DIR"/test_*.bats)

# Run tests
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

for test_file in "${TEST_FILES[@]}"; do
    if [[ -f "$test_file" ]]; then
        echo ""
        echo -e "${YELLOW}Running: $(basename "$test_file")${NC}"
        echo "----------------------------------------"
        
        if bats "$test_file"; then
            ((PASSED_TESTS++))
            echo -e "${GREEN}✓ $(basename "$test_file") passed${NC}"
        else
            ((FAILED_TESTS++))
            echo -e "${RED}✗ $(basename "$test_file") failed${NC}"
        fi
        ((TOTAL_TESTS++))
    fi
done

# Summary
echo ""
echo "========================================"
echo -e "${YELLOW}Test Summary${NC}"
echo "========================================"
echo "Total test files: $TOTAL_TESTS"
echo -e "${GREEN}Passed: $PASSED_TESTS${NC}"
echo -e "${RED}Failed: $FAILED_TESTS${NC}"

# Exit with appropriate code
if [[ $FAILED_TESTS -gt 0 ]]; then
    echo ""
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
else
    echo ""
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
fi