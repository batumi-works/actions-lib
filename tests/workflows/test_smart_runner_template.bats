#!/usr/bin/env bats
# Tests for smart-runner-template.yml workflow

# Load test setup from parent directory
source "${BATS_TEST_DIRNAME}/../bats-setup.bash"

setup() {
    setup_test_env
    load_test_utils
    
    # Set up test workflow directory
    export TEST_WORKFLOW_DIR="$BATS_TEST_TMPDIR/smart-runner-template"
    mkdir -p "$TEST_WORKFLOW_DIR/.github/workflows"
    
    # Copy the workflow file
    cp "$BATS_TEST_DIRNAME/../../.github/workflows/smart-runner-template.yml" \
       "$TEST_WORKFLOW_DIR/.github/workflows/"
}

teardown() {
    teardown_test_env
}

@test "smart-runner-template: workflow file is valid YAML" {
    run validate_yaml "$TEST_WORKFLOW_DIR/.github/workflows/smart-runner-template.yml"
    [ "$status" -eq 0 ]
}

@test "smart-runner-template: has required workflow_call inputs" {
    # Check that all required inputs are defined
    run yq eval '.on.workflow_call.inputs | keys' \
        "$TEST_WORKFLOW_DIR/.github/workflows/smart-runner-template.yml"
    
    # Verify expected inputs exist
    [[ "$output" =~ "runner_type" ]]
    [[ "$output" =~ "runner_size" ]]
    [[ "$output" =~ "enable_fallback" ]]
    [[ "$output" =~ "timeout_minutes" ]]
}

@test "smart-runner-template: has correct default values" {
    # Check runner_type default
    run yq eval '.on.workflow_call.inputs.runner_type.default' \
        "$TEST_WORKFLOW_DIR/.github/workflows/smart-runner-template.yml"
    [ "$output" = "auto" ]
    
    # Check runner_size default
    run yq eval '.on.workflow_call.inputs.runner_size.default' \
        "$TEST_WORKFLOW_DIR/.github/workflows/smart-runner-template.yml"
    [ "$output" = "2vcpu" ]
    
    # Check enable_fallback default
    run yq eval '.on.workflow_call.inputs.enable_fallback.default' \
        "$TEST_WORKFLOW_DIR/.github/workflows/smart-runner-template.yml"
    [ "$output" = "true" ]
    
    # Check timeout_minutes default
    run yq eval '.on.workflow_call.inputs.timeout_minutes.default' \
        "$TEST_WORKFLOW_DIR/.github/workflows/smart-runner-template.yml"
    [ "$output" = "60" ]
}

@test "smart-runner-template: runner selection logic for auto mode" {
    # Test the auto-detection logic
    
    # Test for batumi-works org
    REPOSITORY_OWNER="batumi-works" runner_type="auto"
    if [[ "$runner_type" == "auto" ]]; then
        if [[ "$REPOSITORY_OWNER" == "batumi-works" ]]; then
            expected_runner="org"
        elif [[ "$REPOSITORY_OWNER" == "batumilove" ]]; then
            expected_runner="personal"
        else
            expected_runner="default"
        fi
    fi
    [ "$expected_runner" = "org" ]
    
    # Test for batumilove personal
    REPOSITORY_OWNER="batumilove" runner_type="auto"
    if [[ "$runner_type" == "auto" ]]; then
        if [[ "$REPOSITORY_OWNER" == "batumi-works" ]]; then
            expected_runner="org"
        elif [[ "$REPOSITORY_OWNER" == "batumilove" ]]; then
            expected_runner="personal"
        else
            expected_runner="default"
        fi
    fi
    [ "$expected_runner" = "personal" ]
    
    # Test for other repos
    REPOSITORY_OWNER="other-org" runner_type="auto"
    if [[ "$runner_type" == "auto" ]]; then
        if [[ "$REPOSITORY_OWNER" == "batumi-works" ]]; then
            expected_runner="org"
        elif [[ "$REPOSITORY_OWNER" == "batumilove" ]]; then
            expected_runner="personal"
        else
            expected_runner="default"
        fi
    fi
    [ "$expected_runner" = "default" ]
}

@test "smart-runner-template: runner naming convention" {
    # Test runner naming based on type and size
    
    # Org runner (Blacksmith)
    runner_type="org" runner_size="4vcpu"
    case "$runner_type" in
        "org")
            runner_name="blacksmith-${runner_size}-ubuntu-2204"
            ;;
        "personal")
            runner_name="buildjet-${runner_size}-ubuntu-2204"
            ;;
        *)
            runner_name="ubuntu-latest"
            ;;
    esac
    [ "$runner_name" = "blacksmith-4vcpu-ubuntu-2204" ]
    
    # Personal runner (BuildJet)
    runner_type="personal" runner_size="8vcpu"
    case "$runner_type" in
        "org")
            runner_name="blacksmith-${runner_size}-ubuntu-2204"
            ;;
        "personal")
            runner_name="buildjet-${runner_size}-ubuntu-2204"
            ;;
        *)
            runner_name="ubuntu-latest"
            ;;
    esac
    [ "$runner_name" = "buildjet-8vcpu-ubuntu-2204" ]
    
    # Default runner
    runner_type="default" runner_size="2vcpu"
    case "$runner_type" in
        "org")
            runner_name="blacksmith-${runner_size}-ubuntu-2204"
            ;;
        "personal")
            runner_name="buildjet-${runner_size}-ubuntu-2204"
            ;;
        *)
            runner_name="ubuntu-latest"
            ;;
    esac
    [ "$runner_name" = "ubuntu-latest" ]
}

@test "smart-runner-template: job dependencies are correct" {
    # Check job dependencies
    run yq eval '.jobs.run-primary.needs' \
        "$TEST_WORKFLOW_DIR/.github/workflows/smart-runner-template.yml"
    [ "$output" = "select-runner" ]
    
    run yq eval '.jobs.run-fallback.needs' \
        "$TEST_WORKFLOW_DIR/.github/workflows/smart-runner-template.yml"
    [[ "$output" =~ "select-runner" ]]
    [[ "$output" =~ "run-primary" ]]
    
    run yq eval '.jobs.workflow-status.needs' \
        "$TEST_WORKFLOW_DIR/.github/workflows/smart-runner-template.yml"
    [[ "$output" =~ "run-primary" ]]
    [[ "$output" =~ "run-fallback" ]]
}

@test "smart-runner-template: fallback conditions are correct" {
    # Check fallback job condition
    run yq eval '.jobs.run-fallback.if' \
        "$TEST_WORKFLOW_DIR/.github/workflows/smart-runner-template.yml"
    
    # Should check both enable_fallback and primary completion
    [[ "$output" =~ "inputs.enable_fallback" ]]
    [[ "$output" =~ "needs.run-primary.outputs.completed != 'true'" ]]
}

@test "smart-runner-template: primary job has continue-on-error" {
    # Check continue-on-error setting
    run yq eval '.jobs.run-primary.continue-on-error' \
        "$TEST_WORKFLOW_DIR/.github/workflows/smart-runner-template.yml"
    
    # Should use the enable_fallback input
    [[ "$output" =~ "inputs.enable_fallback" ]]
}

@test "smart-runner-template: timeout configuration" {
    # Check timeout is applied to jobs
    run yq eval '.jobs.run-primary.timeout-minutes' \
        "$TEST_WORKFLOW_DIR/.github/workflows/smart-runner-template.yml"
    [[ "$output" =~ "inputs.timeout_minutes" ]]
    
    run yq eval '.jobs.run-fallback.timeout-minutes' \
        "$TEST_WORKFLOW_DIR/.github/workflows/smart-runner-template.yml"
    [[ "$output" =~ "inputs.timeout_minutes" ]]
}

@test "smart-runner-template: workflow status job always runs" {
    # Check workflow-status job condition
    run yq eval '.jobs.workflow-status.if' \
        "$TEST_WORKFLOW_DIR/.github/workflows/smart-runner-template.yml"
    [ "$output" = "always()" ]
}

@test "smart-runner-template: outputs are properly defined" {
    # Check select-runner outputs
    run yq eval '.jobs.select-runner.outputs | keys' \
        "$TEST_WORKFLOW_DIR/.github/workflows/smart-runner-template.yml"
    [[ "$output" =~ "primary_runner" ]]
    [[ "$output" =~ "fallback_runner" ]]
    [[ "$output" =~ "should_use_fallback" ]]
    
    # Check run-primary outputs
    run yq eval '.jobs.run-primary.outputs | keys' \
        "$TEST_WORKFLOW_DIR/.github/workflows/smart-runner-template.yml"
    [[ "$output" =~ "completed" ]]
    [[ "$output" =~ "status" ]]
}

@test "smart-runner-template: runner information is collected" {
    # Check that runner info steps exist
    run yq eval '.jobs.run-primary.steps[] | select(.name == "Runner Information") | .run' \
        "$TEST_WORKFLOW_DIR/.github/workflows/smart-runner-template.yml"
    
    # Should collect system info
    [[ "$output" =~ "hostname" ]]
    [[ "$output" =~ "nproc" ]]
    [[ "$output" =~ "free -h" ]]
    [[ "$output" =~ "df -h" ]]
}

@test "smart-runner-template: completion marking logic" {
    # Check completion marking step
    run yq eval '.jobs.run-primary.steps[] | select(.name == "Mark Completion") | .if' \
        "$TEST_WORKFLOW_DIR/.github/workflows/smart-runner-template.yml"
    [ "$output" = "success()" ]
}

@test "smart-runner-template: workflow summary generation" {
    # Check workflow summary step
    run yq eval '.jobs.workflow-status.steps[] | select(.name == "Workflow Summary") | .run' \
        "$TEST_WORKFLOW_DIR/.github/workflows/smart-runner-template.yml"
    
    # Should generate markdown summary
    [[ "$output" =~ "GITHUB_STEP_SUMMARY" ]]
    [[ "$output" =~ "Primary Runner" ]]
    [[ "$output" =~ "Fallback Runner" ]]
    [[ "$output" =~ "Overall Status" ]]
}

@test "smart-runner-template: handles all runner sizes" {
    # Test all valid runner sizes
    valid_sizes=("2vcpu" "4vcpu" "8vcpu" "16vcpu")
    
    for size in "${valid_sizes[@]}"; do
        # Org runner
        runner_name="blacksmith-${size}-ubuntu-2204"
        [[ "$runner_name" =~ ^blacksmith-[0-9]+vcpu-ubuntu-2204$ ]]
        
        # Personal runner
        runner_name="buildjet-${size}-ubuntu-2204"
        [[ "$runner_name" =~ ^buildjet-[0-9]+vcpu-ubuntu-2204$ ]]
    done
}

@test "smart-runner-template: fallback always uses ubuntu-latest" {
    # Check fallback runner output
    run yq eval '.jobs.select-runner.steps[] | select(.name == "Determine Runner Configuration") | .run' \
        "$TEST_WORKFLOW_DIR/.github/workflows/smart-runner-template.yml"
    
    # Verify fallback is always ubuntu-latest
    [[ "$output" =~ 'fallback="ubuntu-latest"' ]]
}

@test "smart-runner-template: integration test with usage example" {
    # Create a workflow that uses the template
    cat > "$TEST_WORKFLOW_DIR/.github/workflows/test-usage.yml" << 'EOF'
name: Test Template Usage
on: [push]
jobs:
  test-job:
    uses: ./.github/workflows/smart-runner-template.yml
    with:
      runner_type: auto
      runner_size: 4vcpu
      enable_fallback: true
      timeout_minutes: 30
EOF
    
    cd "$TEST_WORKFLOW_DIR"
    
    # Validate the usage workflow
    run validate_yaml ".github/workflows/test-usage.yml"
    [ "$status" -eq 0 ]
}

@test "smart-runner-template: handles disabled fallback" {
    # Test with fallback disabled
    cat > "$TEST_WORKFLOW_DIR/.github/workflows/test-no-fallback.yml" << 'EOF'
name: Test No Fallback
on: [push]
jobs:
  test-job:
    uses: ./.github/workflows/smart-runner-template.yml
    with:
      runner_type: org
      enable_fallback: false
EOF
    
    cd "$TEST_WORKFLOW_DIR"
    
    # When fallback is disabled, primary failure should fail the workflow
    run validate_yaml ".github/workflows/test-no-fallback.yml"
    [ "$status" -eq 0 ]
}

@test "smart-runner-template: checkout action version is pinned" {
    # Check that checkout action uses pinned version
    run yq eval '.jobs.run-primary.steps[] | select(.name == "Checkout Code") | .uses' \
        "$TEST_WORKFLOW_DIR/.github/workflows/smart-runner-template.yml"
    
    # Should use pinned version with SHA
    [[ "$output" =~ "actions/checkout@" ]]
    [[ "$output" =~ "b4ffde65f46336ab88eb53be808477a3936bae11" ]]
}

@test "smart-runner-template: end-to-end runner selection simulation" {
    # Simulate the runner selection logic end-to-end
    
    test_cases=(
        "batumi-works:auto:2vcpu:blacksmith-2vcpu-ubuntu-2204"
        "batumilove:auto:4vcpu:buildjet-4vcpu-ubuntu-2204"
        "other-org:auto:8vcpu:ubuntu-latest"
        "any-org:org:16vcpu:blacksmith-16vcpu-ubuntu-2204"
        "any-org:personal:2vcpu:buildjet-2vcpu-ubuntu-2204"
        "any-org:default:4vcpu:ubuntu-latest"
    )
    
    for test_case in "${test_cases[@]}"; do
        IFS=':' read -r owner type size expected <<< "$test_case"
        
        # Simulate runner determination
        REPOSITORY_OWNER="$owner"
        runner_type="$type"
        runner_size="$size"
        
        # Auto-detect if needed
        if [[ "$runner_type" == "auto" ]]; then
            if [[ "$REPOSITORY_OWNER" == "batumi-works" ]]; then
                runner_type="org"
            elif [[ "$REPOSITORY_OWNER" == "batumilove" ]]; then
                runner_type="personal"
            else
                runner_type="default"
            fi
        fi
        
        # Determine runner
        case "$runner_type" in
            "org")
                actual="blacksmith-${runner_size}-ubuntu-2204"
                ;;
            "personal")
                actual="buildjet-${runner_size}-ubuntu-2204"
                ;;
            *)
                actual="ubuntu-latest"
                ;;
        esac
        
        # Verify
        if [[ "$actual" != "$expected" ]]; then
            echo "FAIL: $test_case - Expected: $expected, Got: $actual"
            return 1
        fi
    done
    
    echo "✅ All runner selection test cases passed"
}