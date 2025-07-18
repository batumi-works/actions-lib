#!/usr/bin/env bash
# Format test results for better readability and reporting

set -e

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPORT_DIR="$PROJECT_DIR/reports"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Create report directory
mkdir -p "$REPORT_DIR"

# Function to parse TAP output and format it
format_tap_output() {
    local tap_file="$1"
    local output_file="$2"
    
    if [[ ! -f "$tap_file" ]]; then
        echo "TAP file not found: $tap_file"
        return 1
    fi
    
    # Parse TAP format and create formatted report
    {
        echo "# Test Results Summary"
        echo "Generated: $(date)"
        echo "---"
        echo ""
        
        # Extract test counts
        local total_tests=$(grep -c "^ok\|^not ok" "$tap_file" || echo "0")
        local passed_tests=$(grep -c "^ok" "$tap_file" || echo "0")
        local failed_tests=$(grep -c "^not ok" "$tap_file" || echo "0")
        
        echo "## Summary"
        echo "- Total Tests: $total_tests"
        echo "- Passed: $passed_tests"
        echo "- Failed: $failed_tests"
        echo "- Success Rate: $(awk "BEGIN {printf \"%.2f%%\", ($passed_tests/$total_tests)*100}")"
        echo ""
        
        # List failed tests if any
        if [[ $failed_tests -gt 0 ]]; then
            echo "## Failed Tests"
            grep "^not ok" "$tap_file" | while read -r line; do
                echo "- $line"
            done
            echo ""
        fi
        
        echo "## Test Details"
        # Parse each test result
        while IFS= read -r line; do
            if [[ "$line" =~ ^ok\ ([0-9]+)\ (.+) ]]; then
                echo "✅ Test ${BASH_REMATCH[1]}: ${BASH_REMATCH[2]}"
            elif [[ "$line" =~ ^not\ ok\ ([0-9]+)\ (.+) ]]; then
                echo "❌ Test ${BASH_REMATCH[1]}: ${BASH_REMATCH[2]}"
            elif [[ "$line" =~ ^#\ (.+) ]]; then
                echo "   ${BASH_REMATCH[1]}"
            fi
        done < "$tap_file"
        
    } > "$output_file"
    
    echo "Formatted report saved to: $output_file"
}

# Function to generate HTML report
generate_html_report() {
    local tap_file="$1"
    local html_file="$2"
    
    # Extract test data
    local total_tests=$(grep -c "^ok\|^not ok" "$tap_file" || echo "0")
    local passed_tests=$(grep -c "^ok" "$tap_file" || echo "0")
    local failed_tests=$(grep -c "^not ok" "$tap_file" || echo "0")
    local success_rate=$(awk "BEGIN {printf \"%.2f\", ($passed_tests/$total_tests)*100}")
    
    cat > "$html_file" <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>Test Results Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background-color: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        h1 { color: #333; }
        .summary { display: flex; gap: 20px; margin: 20px 0; }
        .stat-card { flex: 1; padding: 20px; border-radius: 8px; text-align: center; }
        .stat-card h3 { margin: 0 0 10px 0; }
        .stat-card .number { font-size: 2em; font-weight: bold; }
        .passed { background-color: #d4edda; color: #155724; }
        .failed { background-color: #f8d7da; color: #721c24; }
        .total { background-color: #cce5ff; color: #004085; }
        .rate { background-color: #fff3cd; color: #856404; }
        .test-list { margin-top: 20px; }
        .test-item { padding: 10px; margin: 5px 0; border-radius: 4px; }
        .test-passed { background-color: #d4edda; border-left: 4px solid #28a745; }
        .test-failed { background-color: #f8d7da; border-left: 4px solid #dc3545; }
        .timestamp { color: #666; font-size: 0.9em; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Test Results Report</h1>
        <p class="timestamp">Generated: $(date)</p>
        
        <div class="summary">
            <div class="stat-card total">
                <h3>Total Tests</h3>
                <div class="number">$total_tests</div>
            </div>
            <div class="stat-card passed">
                <h3>Passed</h3>
                <div class="number">$passed_tests</div>
            </div>
            <div class="stat-card failed">
                <h3>Failed</h3>
                <div class="number">$failed_tests</div>
            </div>
            <div class="stat-card rate">
                <h3>Success Rate</h3>
                <div class="number">$success_rate%</div>
            </div>
        </div>
        
        <div class="test-list">
            <h2>Test Results</h2>
EOF
    
    # Parse and add test results
    while IFS= read -r line; do
        if [[ "$line" =~ ^ok\ ([0-9]+)\ (.+) ]]; then
            echo "            <div class=\"test-item test-passed\">✅ Test ${BASH_REMATCH[1]}: ${BASH_REMATCH[2]}</div>" >> "$html_file"
        elif [[ "$line" =~ ^not\ ok\ ([0-9]+)\ (.+) ]]; then
            echo "            <div class=\"test-item test-failed\">❌ Test ${BASH_REMATCH[1]}: ${BASH_REMATCH[2]}</div>" >> "$html_file"
        fi
    done < "$tap_file"
    
    cat >> "$html_file" <<EOF
        </div>
    </div>
</body>
</html>
EOF
    
    echo "HTML report saved to: $html_file"
}

# Function to generate JUnit XML report
generate_junit_xml() {
    local tap_file="$1"
    local xml_file="$2"
    
    # Extract test data
    local total_tests=$(grep -c "^ok\|^not ok" "$tap_file" || echo "0")
    local failed_tests=$(grep -c "^not ok" "$tap_file" || echo "0")
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S")
    
    cat > "$xml_file" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<testsuites>
    <testsuite name="GitHub Actions Tests" tests="$total_tests" failures="$failed_tests" time="0" timestamp="$timestamp">
EOF
    
    # Parse each test result
    local test_num=0
    while IFS= read -r line; do
        if [[ "$line" =~ ^ok\ ([0-9]+)\ (.+) ]]; then
            test_num=${BASH_REMATCH[1]}
            test_name=${BASH_REMATCH[2]}
            echo "        <testcase name=\"$test_name\" classname=\"actions.test\" time=\"0\"/>" >> "$xml_file"
        elif [[ "$line" =~ ^not\ ok\ ([0-9]+)\ (.+) ]]; then
            test_num=${BASH_REMATCH[1]}
            test_name=${BASH_REMATCH[2]}
            echo "        <testcase name=\"$test_name\" classname=\"actions.test\" time=\"0\">" >> "$xml_file"
            echo "            <failure message=\"Test failed\">$line</failure>" >> "$xml_file"
            echo "        </testcase>" >> "$xml_file"
        fi
    done < "$tap_file"
    
    echo "    </testsuite>" >> "$xml_file"
    echo "</testsuites>" >> "$xml_file"
    
    echo "JUnit XML report saved to: $xml_file"
}

# Main function
main() {
    local format="all"
    local tap_file=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --format)
                format="$2"
                shift 2
                ;;
            --tap-file)
                tap_file="$2"
                shift 2
                ;;
            *)
                tap_file="$1"
                shift
                ;;
        esac
    done
    
    # Default TAP file if not specified
    if [[ -z "$tap_file" ]]; then
        tap_file="$REPORT_DIR/test-results.tap"
    fi
    
    # Generate reports based on format
    case $format in
        markdown|md)
            format_tap_output "$tap_file" "$REPORT_DIR/test-results.md"
            ;;
        html)
            generate_html_report "$tap_file" "$REPORT_DIR/test-results.html"
            ;;
        junit|xml)
            generate_junit_xml "$tap_file" "$REPORT_DIR/test-results.xml"
            ;;
        all)
            format_tap_output "$tap_file" "$REPORT_DIR/test-results.md"
            generate_html_report "$tap_file" "$REPORT_DIR/test-results.html"
            generate_junit_xml "$tap_file" "$REPORT_DIR/test-results.xml"
            ;;
        *)
            echo "Unknown format: $format"
            echo "Supported formats: markdown, html, junit, all"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"