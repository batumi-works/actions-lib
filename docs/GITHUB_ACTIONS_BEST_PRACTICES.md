# GitHub Actions Best Practices Implementation Guide

This document outlines the best practices implemented in the Batumi Works Actions Library, based on industry standards and the comprehensive guide from the Obsidian vault.

## 🎯 Implementation Status

### ✅ Implemented Best Practices

1. **Modular Design**
   - Separated workflows into reusable components
   - Created composite actions for common tasks
   - Each workflow has a single, clear responsibility

2. **Clear Documentation**
   - Comprehensive README with examples
   - Input/output documentation for all actions
   - Troubleshooting guides for common issues

3. **Workflow Organization**
   - Reusable workflows in `.github/workflows/`
   - Composite actions in `actions/`
   - Templates in `.github/workflow-templates/`

### 🚧 To Be Implemented

The following best practices need to be implemented to align with the standards outlined in the Obsidian vault:

## 1. Security Enhancements

### Pin Third-Party Actions to Commit SHAs
```yaml
# Current (insecure)
- uses: actions/checkout@v3
- uses: anthropics/claude-code-base-action@beta

# Recommended (secure)
- uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11 # v4.1.1
- uses: anthropics/claude-code-base-action@[SHA] # beta
```

### Implement Least Privilege Permissions
```yaml
# Add to all composite actions
permissions:
  contents: read       # Only what's needed
  issues: write        # Only if required
  pull-requests: write # Only if required
```

## 2. Performance Optimizations

### Add Caching for Dependencies
```yaml
# For Node.js projects
- name: Cache node modules
  uses: actions/cache@v3
  with:
    path: ~/.npm
    key: ${{ runner.os }}-node-${{ hashFiles('**/package-lock.json') }}
    restore-keys: |
      ${{ runner.os }}-node-

# For Bats testing
- name: Cache Bats installation
  uses: actions/cache@v3
  with:
    path: |
      /usr/local/bin/bats
      /usr/local/lib/bats
    key: ${{ runner.os }}-bats-${{ hashFiles('tests/bats-setup.bash') }}
```

### Optimize Checkout Operations
```yaml
- uses: actions/checkout@v4
  with:
    fetch-depth: 1      # Shallow clone for faster checkout
    lfs: false         # Skip LFS if not needed
    submodules: false  # Skip submodules if not needed
```

## 3. Error Handling & Retry Logic

### Add Retry Mechanism for Flaky Operations
```yaml
# For GitHub API calls
- name: Create PR with retry
  uses: nick-invision/retry@v2
  with:
    timeout_minutes: 5
    max_attempts: 3
    retry_on: error
    command: |
      # GitHub API call here

# For Claude Code execution
- name: Run Claude Code with retry
  uses: nick-invision/retry@v2
  with:
    timeout_minutes: ${{ inputs.timeout_minutes }}
    max_attempts: 2
    retry_on: timeout
    command: |
      # Claude Code execution
```

### Enhanced Error Handling
```yaml
# Add to all composite actions
- name: Validate Inputs
  run: |
    if [[ -z "${{ inputs.required_param }}" ]]; then
      echo "::error::required_param is required but not provided"
      exit 1
    fi

# Add debug information on failure
- name: Debug Information
  if: failure()
  run: |
    echo "::group::Debug Information"
    echo "Event: ${{ github.event_name }}"
    echo "Ref: ${{ github.ref }}"
    echo "SHA: ${{ github.sha }}"
    echo "::endgroup::"
```

## 4. Workflow Patterns

### Matrix Strategy for Testing
```yaml
strategy:
  matrix:
    test-suite: [unit, integration, e2e]
    os: [ubuntu-latest, windows-latest, macos-latest]
  fail-fast: false  # Continue other jobs if one fails
```

### Job Dependencies with Outputs
```yaml
jobs:
  prepare:
    outputs:
      version: ${{ steps.version.outputs.version }}
    steps:
      - id: version
        run: echo "version=$(date +%Y%m%d%H%M%S)" >> $GITHUB_OUTPUT

  deploy:
    needs: prepare
    steps:
      - run: echo "Deploying version ${{ needs.prepare.outputs.version }}"
```

## 5. Logging and Observability

### Structured Logging
```yaml
# Use GitHub Actions logging commands
- name: Structured Output
  run: |
    echo "::notice title=PRP Found::Processing ${{ steps.prp.outputs.prp_path }}"
    echo "::warning title=No Changes::No implementation changes detected"
    echo "::error title=Auth Failed::Invalid token provided"
    
    # Group related logs
    echo "::group::Configuration Details"
    echo "API Provider: ${{ inputs.api_provider }}"
    echo "Model: ${{ inputs.claude_model }}"
    echo "::endgroup::"
```

### Upload Artifacts for Debugging
```yaml
- name: Upload Debug Artifacts
  if: failure()
  uses: actions/upload-artifact@v3
  with:
    name: debug-logs-${{ github.run_id }}
    path: |
      .github/
      logs/
      test-results/
    retention-days: 7
```

## 6. Composite Action Improvements

### Example: Enhanced Claude Setup Action
```yaml
name: 'Claude Setup (Enhanced)'
description: 'Setup Claude environment with best practices'

inputs:
  claude_oauth_token:
    description: 'Claude Code OAuth token'
    required: true
  bot_token:
    description: 'GitHub token'
    required: true
  cache_key:
    description: 'Cache key prefix'
    required: false
    default: 'claude-setup'

runs:
  using: "composite"
  steps:
    # Input validation
    - name: Validate Inputs
      shell: bash
      run: |
        if [[ -z "${{ inputs.claude_oauth_token }}" ]]; then
          echo "::error::claude_oauth_token is required"
          exit 1
        fi

    # Cache Git configuration
    - name: Cache Git Config
      uses: actions/cache@v3
      with:
        path: ~/.gitconfig
        key: ${{ inputs.cache_key }}-gitconfig-${{ hashFiles('.github/**') }}

    # Checkout with optimization
    - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11 # v4.1.1
      with:
        token: ${{ inputs.bot_token }}
        fetch-depth: 1
        lfs: false

    # Configure with error handling
    - name: Configure Git
      shell: bash
      run: |
        set -euo pipefail
        git config --global user.name "Claude AI Bot" || {
          echo "::error::Failed to configure git user.name"
          exit 1
        }
        git config --global user.email "claude@example.com" || {
          echo "::error::Failed to configure git user.email"
          exit 1
        }
```

## 7. Testing Enhancements

### Parallel Test Execution
```yaml
# Run tests in parallel
jobs:
  test:
    strategy:
      matrix:
        test-type: [unit, integration, e2e, security]
    steps:
      - run: make test-${{ matrix.test-type }}
```

### Test Result Reporting
```yaml
- name: Test Report
  uses: dorny/test-reporter@v1
  if: always()
  with:
    name: Test Results
    path: 'test-results/*.xml'
    reporter: jest-junit
```

## Implementation Checklist

- [ ] Pin all third-party actions to commit SHAs
- [ ] Add caching for all dependencies
- [ ] Implement retry logic for API calls
- [ ] Add comprehensive error handling
- [ ] Optimize checkout operations
- [ ] Add structured logging
- [ ] Implement debug artifact uploads
- [ ] Add input validation to all actions
- [ ] Create matrix strategies for tests
- [ ] Add test result reporting
- [ ] Document all changes

## Migration Path

1. **Phase 1: Security** (Priority: High)
   - Pin all actions to specific commits
   - Review and minimize permissions
   - Add token validation

2. **Phase 2: Performance** (Priority: Medium)
   - Add caching strategies
   - Optimize checkout operations
   - Implement parallel execution

3. **Phase 3: Reliability** (Priority: Medium)
   - Add retry mechanisms
   - Enhance error handling
   - Improve logging

4. **Phase 4: Observability** (Priority: Low)
   - Add structured logging
   - Implement artifact uploads
   - Create dashboards

## Resources

- [GitHub Actions Best Practices (Obsidian Vault)](obsidian-vault/01-Areas/Tech-Stack/DevOps/GitHub-Actions-Best-Practices.md)
- [GitHub Actions Security Guide](https://docs.github.com/en/actions/security-guides)
- [GitHub Actions Performance Guide](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions)