# GitHub Actions Reusable Workflows Troubleshooting Guide

This document outlines common issues and solutions when working with GitHub Actions reusable workflows, based on extensive debugging and research conducted on July 18, 2025.

## Table of Contents

1. [Common Errors](#common-errors)
2. [Root Causes](#root-causes)
3. [Solutions](#solutions)
4. [Best Practices](#best-practices)
5. [Debugging Tips](#debugging-tips)

## Common Errors

### 1. Reserved Name Conflict Error

**Error Message:**
```
secret name `github_token` within `workflow_call` can not be used since it would collide with system reserved name
```

**Symptoms:**
- Workflow fails immediately upon creation
- Error appears when defining secrets in `workflow_call`

### 2. Startup Failure Error

**Error Message:**
```
X This run likely failed because of a workflow file issue.
```

**Symptoms:**
- Workflow shows `startup_failure` status
- No detailed error logs available
- Occurs before workflow execution begins

### 3. Workflow Not Found Error

**Error Message:**
```
workflow was not found
```

**Symptoms:**
- Cannot reference reusable workflow
- Occurs with cross-repository workflow calls

## Root Causes

### 1. GitHub Token Naming Conflict

GitHub Actions reserves certain secret names that cannot be used in `workflow_call` definitions:
- `github_token` - Reserved by GitHub Actions
- `github` - Reserved context name
- Other system-reserved names

**Why it happens:**
- GitHub automatically provides `GITHUB_TOKEN` and `github.token` to all workflows
- Using these names in custom secret definitions creates a naming collision

### 2. Repository Visibility Mismatches

When calling reusable workflows across repositories:
- Private repositories have restrictions on which workflows they can call
- Public repositories cannot use workflows from private repositories
- Internal repositories (Enterprise feature) have specific visibility rules

### 3. Branch Reference Issues

GitHub Actions may have trouble resolving branch references in certain scenarios:
- Using `@main` or other branch names can cause `startup_failure`
- This particularly affects private repositories calling public reusable workflows

## Solutions

### 1. Fix Reserved Name Conflicts

**Before (Incorrect):**
```yaml
on:
  workflow_call:
    secrets:
      github_token:  # ❌ Reserved name
        description: 'GitHub token'
        required: true
```

**After (Correct):**
```yaml
on:
  workflow_call:
    secrets:
      bot_token:  # ✅ Custom name
        description: 'GitHub token for bot operations'
        required: true
```

**In the calling workflow:**
```yaml
jobs:
  call-workflow:
    uses: org/repo/.github/workflows/reusable.yml@main
    secrets:
      bot_token: ${{ github.token }}  # Pass the GitHub token with custom name
```

### 2. Use SHA References Instead of Branch Names

**Before (May cause issues):**
```yaml
uses: org/repo/.github/workflows/reusable.yml@main
```

**After (More reliable):**
```yaml
uses: org/repo/.github/workflows/reusable.yml@646c634  # Use commit SHA
```

**To get the commit SHA:**
```bash
# Get the latest commit SHA for a branch
gh api repos/org/repo/commits/main --jq '.sha'

# Or use git
git ls-remote https://github.com/org/repo.git main
```

### 3. Configure Repository Permissions

For organization-owned repositories:
1. Go to Settings → Actions → General
2. Under "Access", select appropriate permissions:
   - "Accessible from repositories in the 'ORGANIZATION' organization"
   - Or specify allowed repositories

### 4. Handle Repository Visibility

**Repository Visibility Rules:**
- Public → Public: ✅ Works
- Public → Private: ❌ Not allowed
- Private → Public: ✅ Works (with proper reference)
- Private → Private (same owner): ✅ Works
- Internal → Internal/Public: ✅ Works (Enterprise)

## Best Practices

### 1. Naming Conventions

Use descriptive, non-reserved names for secrets:
```yaml
secrets:
  # Good examples
  api_token:
  bot_token:
  deploy_token:
  auth_token:
  
  # Avoid
  github_token:  # Reserved
  token:         # Too generic
  GITHUB_TOKEN:  # Reserved
```

### 2. Version Pinning

Always pin to specific versions for stability:
```yaml
# Good - using SHA
uses: actions/checkout@93ea575cb5d8a053eaa0ac8fa3b40d7e05a33cc8

# Good - using release tag
uses: actions/checkout@v3.1.0

# Acceptable for internal workflows
uses: org/repo/.github/workflows/workflow.yml@main

# Better for external workflows
uses: org/repo/.github/workflows/workflow.yml@sha123456
```

### 3. Documentation

Always document your reusable workflows:
```yaml
name: 'Reusable Workflow Name'
on:
  workflow_call:
    inputs:
      environment:
        description: 'Deployment environment (dev, staging, prod)'
        required: true
        type: string
    secrets:
      api_token:
        description: 'API token for service authentication'
        required: true
```

## Debugging Tips

### 1. Enable Debug Logging

Add these secrets to your repository:
- `ACTIONS_RUNNER_DEBUG`: `true`
- `ACTIONS_STEP_DEBUG`: `true`

### 2. Test Progressively

1. Start with a minimal workflow
2. Test local reusable workflows first (`./.github/workflows/...`)
3. Test with public repositories before private
4. Use SHA references for initial testing

### 3. Validate YAML Syntax

```bash
# Using Python
python3 -c "import yaml; yaml.safe_load(open('workflow.yml'))"

# Using yamllint
yamllint workflow.yml

# Using GitHub CLI
gh workflow view workflow.yml --yaml
```

### 4. Check Workflow Accessibility

```bash
# Verify workflow file exists and is accessible
curl -s https://raw.githubusercontent.com/org/repo/main/.github/workflows/workflow.yml

# Check repository visibility
gh api repos/org/repo --jq '.visibility'

# Check Actions permissions
gh api repos/org/repo/actions/permissions
```

### 5. Common Troubleshooting Steps

1. **For startup_failure:**
   - Check YAML syntax
   - Verify workflow file path
   - Use SHA instead of branch reference
   - Check repository permissions

2. **For secret errors:**
   - Ensure no reserved names are used
   - Verify secret is passed from caller
   - Check secret name matches between caller and callee

3. **For permission errors:**
   - Verify repository Actions settings
   - Check organization-level permissions
   - Ensure workflow has required permissions

## Example: Complete Working Setup

### Reusable Workflow (actions-lib)

```yaml
# .github/workflows/reusable-deploy.yml
name: 'Reusable Deploy Workflow'

on:
  workflow_call:
    inputs:
      environment:
        description: 'Target environment'
        required: true
        type: string
      version:
        description: 'Version to deploy'
        required: false
        type: string
        default: 'latest'
    secrets:
      deploy_token:
        description: 'Token for deployment'
        required: true
      slack_webhook:
        description: 'Slack webhook for notifications'
        required: false

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: ${{ inputs.environment }}
    steps:
      - uses: actions/checkout@v4
      
      - name: Deploy
        env:
          DEPLOY_TOKEN: ${{ secrets.deploy_token }}
        run: |
          echo "Deploying ${{ inputs.version }} to ${{ inputs.environment }}"
          # Deployment logic here
      
      - name: Notify
        if: secrets.slack_webhook != ''
        run: |
          # Notification logic here
```

### Calling Workflow

```yaml
# .github/workflows/deploy-prod.yml
name: Deploy to Production

on:
  push:
    branches: [main]

jobs:
  deploy:
    uses: org/actions-lib/.github/workflows/reusable-deploy.yml@v1.2.0
    with:
      environment: production
      version: ${{ github.sha }}
    secrets:
      deploy_token: ${{ secrets.PRODUCTION_DEPLOY_TOKEN }}
      slack_webhook: ${{ secrets.SLACK_WEBHOOK }}
```

## References

- [GitHub Docs: Reusing workflows](https://docs.github.com/en/actions/using-workflows/reusing-workflows)
- [GitHub Docs: Security hardening for Actions](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions)
- [GitHub Community Discussion: Reusable Workflows](https://github.com/orgs/community/discussions/categories/actions)

## Contributing

If you encounter additional issues or have solutions to share, please:
1. Open an issue in this repository
2. Submit a pull request with your findings
3. Share in GitHub Community Discussions

---

*Last updated: July 18, 2025*
*Based on real-world debugging of GitHub Actions workflows in batumi-works organization*