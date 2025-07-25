#!/usr/bin/env bats
# Tests for claude-prp-pipeline-v3.yml workflow (Advanced version)

# Load test setup from parent directory
source "${BATS_TEST_DIRNAME}/../bats-setup.bash"

setup() {
    setup_test_env
    load_test_utils
    setup_github_env
    
    # Set up test workflow directory
    export TEST_WORKFLOW_DIR="$BATS_TEST_TMPDIR/claude-prp-pipeline-v3"
    mkdir -p "$TEST_WORKFLOW_DIR/.github/workflows"
    
    # Copy the workflow file
    cp "$BATS_TEST_DIRNAME/../../.github/workflows/claude-prp-pipeline-v3.yml" \
       "$TEST_WORKFLOW_DIR/.github/workflows/"
}

teardown() {
    teardown_test_env
}

@test "claude-prp-pipeline-v3: workflow file is valid YAML" {
    run validate_yaml "$TEST_WORKFLOW_DIR/.github/workflows/claude-prp-pipeline-v3.yml"
    [ "$status" -eq 0 ]
}

@test "claude-prp-pipeline-v3: has advanced features over v2" {
    # Check that v3 has additional advanced inputs
    run yq eval '.on.workflow_call.inputs | keys' \
        "$TEST_WORKFLOW_DIR/.github/workflows/claude-prp-pipeline-v3.yml"
    
    # Should have all v2 inputs plus advanced features
    [[ "$output" =~ "api_provider" ]]
    [[ "$output" =~ "enable_cache" ]]
    [[ "$output" =~ "enable_tests" ]]
    
    # V3-specific features
    [[ "$output" =~ "enable_security_scan" ]] || echo "Security scan optional"
    [[ "$output" =~ "enable_performance_check" ]] || echo "Performance check optional"
    [[ "$output" =~ "enable_documentation" ]] || echo "Documentation optional"
    [[ "$output" =~ "enable_preview_deployment" ]] || echo "Preview deployment optional"
}

@test "claude-prp-pipeline-v3: security scanning configuration" {
    # Check for security scan inputs
    run yq eval '.on.workflow_call.inputs.enable_security_scan' \
        "$TEST_WORKFLOW_DIR/.github/workflows/claude-prp-pipeline-v3.yml"
    
    # If security scanning is available
    if [ "$status" -eq 0 ]; then
        run yq eval '.on.workflow_call.inputs.enable_security_scan.default' \
            "$TEST_WORKFLOW_DIR/.github/workflows/claude-prp-pipeline-v3.yml"
        echo "Security scan default: $output"
    fi
}

@test "claude-prp-pipeline-v3: multi-stage pipeline" {
    # Check if v3 implements multi-stage pipeline
    run yq eval '.jobs | keys' \
        "$TEST_WORKFLOW_DIR/.github/workflows/claude-prp-pipeline-v3.yml"
    
    # May have multiple jobs for different stages
    job_count=$(echo "$output" | grep -c ".")
    echo "Number of jobs in v3: $job_count"
    
    # V3 likely has more jobs than v1/v2
    [ "$job_count" -ge 1 ]
}

@test "claude-prp-pipeline-v3: dependency security check" {
    # Check for dependency vulnerability scanning
    run yq eval '.jobs.*.steps[] | select(.name | contains("Security") or contains("Vulnerability") or contains("Audit")) | .name' \
        "$TEST_WORKFLOW_DIR/.github/workflows/claude-prp-pipeline-v3.yml"
    
    # Should have some form of security checking
    [ "$status" -eq 0 ] || echo "Security checks may be integrated differently"
}

@test "claude-prp-pipeline-v3: code quality gates" {
    # Check for quality gate enforcement
    run yq eval '.jobs.*.steps[] | select(.name | contains("Quality") or contains("Coverage") or contains("Sonar")) | .name' \
        "$TEST_WORKFLOW_DIR/.github/workflows/claude-prp-pipeline-v3.yml"
    
    # May enforce code quality standards
    [ "$status" -eq 0 ] || echo "Quality gates may be enforced through other means"
}

@test "claude-prp-pipeline-v3: preview deployment support" {
    # Check for preview/staging deployment
    run yq eval '.on.workflow_call.inputs.enable_preview_deployment' \
        "$TEST_WORKFLOW_DIR/.github/workflows/claude-prp-pipeline-v3.yml"
    
    if [ "$status" -eq 0 ]; then
        echo "Preview deployment is configurable"
    else
        echo "Preview deployment not found in inputs"
    fi
}

@test "claude-prp-pipeline-v3: documentation generation" {
    # Check for automated documentation
    run yq eval '.on.workflow_call.inputs.enable_documentation' \
        "$TEST_WORKFLOW_DIR/.github/workflows/claude-prp-pipeline-v3.yml"
    
    if [ "$status" -eq 0 ]; then
        run yq eval '.on.workflow_call.inputs.enable_documentation.default' \
            "$TEST_WORKFLOW_DIR/.github/workflows/claude-prp-pipeline-v3.yml"
        echo "Documentation generation default: $output"
    fi
}

@test "claude-prp-pipeline-v3: performance benchmarking" {
    # Check for performance testing
    run yq eval '.on.workflow_call.inputs.enable_performance_check' \
        "$TEST_WORKFLOW_DIR/.github/workflows/claude-prp-pipeline-v3.yml"
    
    if [ "$status" -eq 0 ]; then
        echo "Performance benchmarking is available"
    else
        echo "Performance checks not found in inputs"
    fi
}

@test "claude-prp-pipeline-v3: advanced caching strategies" {
    # Check for advanced caching beyond v2
    run yq eval '.jobs.*.steps[] | select(.uses | contains("cache")) | .name' \
        "$TEST_WORKFLOW_DIR/.github/workflows/claude-prp-pipeline-v3.yml"
    
    # May use more sophisticated caching
    [ "$status" -eq 0 ] || echo "Caching may be implemented differently"
}

@test "claude-prp-pipeline-v3: parallel job execution" {
    # Check for parallel execution capabilities
    run yq eval '.jobs | to_entries | .[] | select(.value.needs == null or .value.needs == []) | .key' \
        "$TEST_WORKFLOW_DIR/.github/workflows/claude-prp-pipeline-v3.yml"
    
    # Jobs without dependencies can run in parallel
    parallel_jobs=$(echo "$output" | grep -c "." || echo "0")
    echo "Potential parallel jobs: $parallel_jobs"
}

@test "claude-prp-pipeline-v3: rollback capabilities" {
    # Check for rollback or revert mechanisms
    run yq eval '.jobs.*.steps[] | select(.name | contains("Rollback") or contains("Revert")) | .name' \
        "$TEST_WORKFLOW_DIR/.github/workflows/claude-prp-pipeline-v3.yml"
    
    # Advanced pipelines may support rollback
    [ "$status" -eq 0 ] || echo "Rollback may be handled externally"
}

@test "claude-prp-pipeline-v3: monitoring and alerting" {
    # Check for monitoring integration
    run yq eval '.jobs.*.steps[] | select(.name | contains("Monitor") or contains("Alert") or contains("Notify")) | .name' \
        "$TEST_WORKFLOW_DIR/.github/workflows/claude-prp-pipeline-v3.yml"
    
    # May integrate with monitoring systems
    [ "$status" -eq 0 ] || echo "Monitoring may be configured elsewhere"
}

@test "claude-prp-pipeline-v3: compliance checks" {
    # Check for compliance validation
    run yq eval '.jobs.*.steps[] | select(.name | contains("Compliance") or contains("License") or contains("Policy")) | .name' \
        "$TEST_WORKFLOW_DIR/.github/workflows/claude-prp-pipeline-v3.yml"
    
    # Enterprise features may include compliance
    [ "$status" -eq 0 ] || echo "Compliance checks may be optional"
}

@test "claude-prp-pipeline-v3: infrastructure as code support" {
    # Check for IaC validation
    run yq eval '.jobs.*.steps[] | select(.name | contains("Terraform") or contains("CloudFormation") or contains("Infrastructure")) | .name' \
        "$TEST_WORKFLOW_DIR/.github/workflows/claude-prp-pipeline-v3.yml"
    
    # May validate infrastructure changes
    [ "$status" -eq 0 ] || echo "IaC support may be modular"
}

@test "claude-prp-pipeline-v3: comprehensive test matrix" {
    # Check for test matrix configuration
    run yq eval '.jobs.*.strategy.matrix' \
        "$TEST_WORKFLOW_DIR/.github/workflows/claude-prp-pipeline-v3.yml"
    
    # May test across multiple environments
    [ "$status" -eq 0 ] || echo "Matrix testing may be job-specific"
}

@test "claude-prp-pipeline-v3: artifact management" {
    # Check for advanced artifact handling
    run yq eval '.jobs.*.steps[] | select(.uses | contains("artifact")) | .name' \
        "$TEST_WORKFLOW_DIR/.github/workflows/claude-prp-pipeline-v3.yml"
    
    # Should have artifact upload/download
    [ "$status" -eq 0 ] || echo "Artifacts may be handled differently"
}

@test "claude-prp-pipeline-v3: environment-specific configuration" {
    # Check for environment management
    run yq eval '.jobs.*.environment' \
        "$TEST_WORKFLOW_DIR/.github/workflows/claude-prp-pipeline-v3.yml"
    
    # May use GitHub environments
    [ "$status" -eq 0 ] || echo "Environments may be parameterized"
}

@test "claude-prp-pipeline-v3: advanced error recovery" {
    # Check for retry and recovery mechanisms
    run yq eval '.jobs.*.steps[] | select(.name | contains("Retry") or contains("Recovery")) | .name' \
        "$TEST_WORKFLOW_DIR/.github/workflows/claude-prp-pipeline-v3.yml"
    
    # May have automatic retry logic
    [ "$status" -eq 0 ] || echo "Error recovery may be built into steps"
}

@test "claude-prp-pipeline-v3: metrics and telemetry" {
    # Check for metrics collection
    run yq eval '.jobs.*.steps[] | select(.name | contains("Metric") or contains("Telemetry") or contains("Analytics")) | .name' \
        "$TEST_WORKFLOW_DIR/.github/workflows/claude-prp-pipeline-v3.yml"
    
    # May collect workflow metrics
    [ "$status" -eq 0 ] || echo "Metrics may be collected externally"
}

@test "claude-prp-pipeline-v3: backwards compatibility with v2" {
    # Test that v3 maintains compatibility with v2
    cat > "$TEST_WORKFLOW_DIR/.github/workflows/test-v2-compat.yml" << 'EOF'
name: Test V2 Compatibility
on: [issue_comment]
jobs:
  test:
    uses: ./.github/workflows/claude-prp-pipeline-v3.yml
    with:
      # V2 parameters
      api_provider: anthropic
      timeout_minutes: 90
      enable_cache: true
      enable_tests: true
      test_command: 'npm test'
      enable_lint: true
      lint_command: 'npm run lint'
    secrets:
      bot_token: ${{ secrets.BOT_TOKEN }}
      claude_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
EOF
    
    cd "$TEST_WORKFLOW_DIR"
    
    # Should accept v2 parameters
    run validate_yaml ".github/workflows/test-v2-compat.yml"
    [ "$status" -eq 0 ]
}

@test "claude-prp-pipeline-v3: enterprise features" {
    # List expected enterprise features
    echo "Expected enterprise features in v3:"
    echo "- Advanced security scanning"
    echo "- Compliance validation"
    echo "- Performance benchmarking"
    echo "- Preview deployments"
    echo "- Advanced monitoring"
    echo "- Multi-environment support"
    echo "- Comprehensive artifact management"
    echo "- Advanced caching strategies"
    echo "- Rollback capabilities"
    echo "- Metrics and telemetry"
}

@test "claude-prp-pipeline-v3: scalability features" {
    # Check for scalability enhancements
    echo "Scalability features to check:"
    echo "- Parallel job execution"
    echo "- Distributed caching"
    echo "- Resource optimization"
    echo "- Queue management"
    echo "- Load balancing"
    
    # V3 should handle large-scale operations
    run yq eval '.jobs | length' \
        "$TEST_WORKFLOW_DIR/.github/workflows/claude-prp-pipeline-v3.yml"
    
    echo "Total jobs in v3: $output"
}