#!/bin/bash
# Validate workflow tests structure

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}Validating Workflow Tests Structure${NC}"
echo "===================================="

# Check for required files
REQUIRED_FILES=(
    "README.md"
    "run_workflow_tests.sh"
    "test_claude_agent_pipeline.bats"
    "test_claude_prp_pipeline.bats"
    "test_smart_runner_template.bats"
    "test_claude_prp_pipeline_v2.bats"
    "test_claude_prp_pipeline_v3.bats"
)

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

echo "Checking required files..."
for file in "${REQUIRED_FILES[@]}"; do
    if [[ -f "$file" ]]; then
        echo -e "${GREEN}✓${NC} $file exists"
    else
        echo -e "${RED}✗${NC} $file missing"
        exit 1
    fi
done

echo ""
echo "Checking test file structure..."

# Check each test file has required sections
for test_file in test_*.bats; do
    echo ""
    echo "Validating $test_file:"
    
    # Check shebang
    if head -1 "$test_file" | grep -q "#!/usr/bin/env bats"; then
        echo -e "  ${GREEN}✓${NC} Has correct shebang"
    else
        echo -e "  ${RED}✗${NC} Missing or incorrect shebang"
    fi
    
    # Check for setup function
    if grep -q "^setup()" "$test_file"; then
        echo -e "  ${GREEN}✓${NC} Has setup function"
    else
        echo -e "  ${YELLOW}!${NC} No setup function (optional)"
    fi
    
    # Check for teardown function
    if grep -q "^teardown()" "$test_file"; then
        echo -e "  ${GREEN}✓${NC} Has teardown function"
    else
        echo -e "  ${YELLOW}!${NC} No teardown function (optional)"
    fi
    
    # Count @test blocks
    test_count=$(grep -c "^@test " "$test_file" || true)
    if [[ $test_count -gt 0 ]]; then
        echo -e "  ${GREEN}✓${NC} Has $test_count test cases"
    else
        echo -e "  ${RED}✗${NC} No test cases found"
    fi
    
    # Check for workflow file reference
    workflow_name=$(echo "$test_file" | sed 's/test_//' | sed 's/_/-/g' | sed 's/.bats/.yml/')
    if grep -q "$workflow_name" "$test_file"; then
        echo -e "  ${GREEN}✓${NC} References workflow file: $workflow_name"
    else
        echo -e "  ${YELLOW}!${NC} No direct reference to $workflow_name"
    fi
done

echo ""
echo "===================================="

# Check for corresponding workflow files
echo ""
echo "Checking for corresponding workflow files..."
WORKFLOW_DIR="../../.github/workflows"

for test_file in test_*.bats; do
    workflow_name=$(echo "$test_file" | sed 's/test_//' | sed 's/_/-/g' | sed 's/.bats/.yml/')
    workflow_path="$WORKFLOW_DIR/$workflow_name"
    
    if [[ -f "$workflow_path" ]]; then
        echo -e "${GREEN}✓${NC} Workflow exists: $workflow_name"
    else
        echo -e "${RED}✗${NC} Missing workflow: $workflow_name"
    fi
done

echo ""
echo "===================================="
echo -e "${GREEN}Validation complete!${NC}"
echo ""
echo "Note: To run the actual tests, install BATS:"
echo "  npm install -g bats"
echo "  make test-workflows"