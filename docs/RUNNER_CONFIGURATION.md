# Runner Configuration Guide

This guide explains how to configure GitHub Actions runners with fallback support for better reliability and performance.

## Overview

The actions-lib supports multiple runner providers with automatic fallback:
- **Organization Repos (batumi-works)**: Blacksmith runners with GitHub-hosted fallback
- **Personal Repos (batumilove)**: BuildJet runners with GitHub-hosted fallback

## Runner Providers

### 1. Blacksmith (Organization Repos)
Blacksmith provides high-performance runners for organization repositories.

**Available Runners:**
- `blacksmith-2vcpu-ubuntu-2204` (2 vCPU, Ubuntu 22.04)
- `blacksmith-4vcpu-ubuntu-2204` (4 vCPU, Ubuntu 22.04)
- `blacksmith-8vcpu-ubuntu-2204` (8 vCPU, Ubuntu 22.04)
- `blacksmith-16vcpu-ubuntu-2204` (16 vCPU, Ubuntu 22.04)

### 2. BuildJet (Personal Repos)
BuildJet provides fast runners for personal repositories.

**Available Runners:**
- `buildjet-2vcpu-ubuntu-2204` (2 vCPU, Ubuntu 22.04)
- `buildjet-4vcpu-ubuntu-2204` (4 vCPU, Ubuntu 22.04)
- `buildjet-8vcpu-ubuntu-2204` (8 vCPU, Ubuntu 22.04)
- `buildjet-16vcpu-ubuntu-2204` (16 vCPU, Ubuntu 22.04)

### 3. GitHub-Hosted (Fallback)
Standard GitHub-hosted runners used as fallback.

**Available Runners:**
- `ubuntu-latest` (Ubuntu 22.04)
- `ubuntu-22.04`
- `ubuntu-20.04`
- `windows-latest`
- `macos-latest`

## Configuration Methods

### Method 1: Direct Runner Configuration (Simple)

```yaml
jobs:
  build:
    # For organization repos
    runs-on: blacksmith-2vcpu-ubuntu-2204
    
    # For personal repos
    # runs-on: buildjet-2vcpu-ubuntu-2204
```

### Method 2: Fallback with Conditional Jobs (Recommended)

```yaml
jobs:
  # Primary job with preferred runner
  build-primary:
    runs-on: ${{ vars.PREFERRED_RUNNER || 'blacksmith-2vcpu-ubuntu-2204' }}
    continue-on-error: true
    outputs:
      success: ${{ steps.check.outputs.success }}
    steps:
      - name: Checkout
        uses: actions/checkout@v4
      
      - name: Build
        id: build
        run: |
          # Your build commands here
          echo "Building on preferred runner"
      
      - name: Check Success
        id: check
        if: success()
        run: echo "success=true" >> $GITHUB_OUTPUT

  # Fallback job if primary fails
  build-fallback:
    needs: build-primary
    if: needs.build-primary.outputs.success != 'true'
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4
      
      - name: Build
        run: |
          echo "::warning::Running on fallback runner"
          # Same build commands here
```

### Method 3: Matrix Strategy with Fallback

```yaml
jobs:
  build:
    strategy:
      fail-fast: false
      matrix:
        include:
          - runner: blacksmith-2vcpu-ubuntu-2204
            type: primary
          - runner: ubuntu-latest
            type: fallback
    runs-on: ${{ matrix.runner }}
    continue-on-error: ${{ matrix.type == 'primary' }}
    steps:
      - name: Checkout
        uses: actions/checkout@v4
      
      - name: Build
        run: |
          echo "Running on ${{ matrix.type }} runner: ${{ matrix.runner }}"
          # Your build commands
```

### Method 4: Reusable Workflow with Smart Runner Selection

```yaml
# In .github/workflows/reusable-build.yml
on:
  workflow_call:
    inputs:
      runner_type:
        description: 'Runner type: org, personal, or default'
        type: string
        default: 'default'
      runner_size:
        description: 'Runner size: 2vcpu, 4vcpu, 8vcpu, or 16vcpu'
        type: string
        default: '2vcpu'

jobs:
  determine-runner:
    runs-on: ubuntu-latest
    outputs:
      runner: ${{ steps.select.outputs.runner }}
    steps:
      - name: Select Runner
        id: select
        run: |
          if [[ "${{ inputs.runner_type }}" == "org" ]]; then
            echo "runner=blacksmith-${{ inputs.runner_size }}-ubuntu-2204" >> $GITHUB_OUTPUT
          elif [[ "${{ inputs.runner_type }}" == "personal" ]]; then
            echo "runner=buildjet-${{ inputs.runner_size }}-ubuntu-2204" >> $GITHUB_OUTPUT
          else
            echo "runner=ubuntu-latest" >> $GITHUB_OUTPUT
          fi

  build:
    needs: determine-runner
    runs-on: ${{ needs.determine-runner.outputs.runner }}
    steps:
      - name: Build
        run: echo "Building on ${{ needs.determine-runner.outputs.runner }}"
```

## Repository Variables Configuration

Configure these variables in your repository settings:

```yaml
# Organization repos (Settings > Secrets and variables > Actions > Variables)
PREFERRED_RUNNER: blacksmith-2vcpu-ubuntu-2204
FALLBACK_RUNNER: ubuntu-latest
ENABLE_RUNNER_FALLBACK: true

# Personal repos
PREFERRED_RUNNER: buildjet-2vcpu-ubuntu-2204
FALLBACK_RUNNER: ubuntu-latest
ENABLE_RUNNER_FALLBACK: true
```

## Migration Guide

### For Organization Repositories (Blacksmith)

1. **Update existing workflows:**
   ```bash
   # Simple replacement
   sed -i 's/runs-on: ubuntu-latest/runs-on: blacksmith-2vcpu-ubuntu-2204/g' .github/workflows/*.yml
   ```

2. **Or use the migration script:**
   ```bash
   ./scripts/migrate-to-blacksmith.sh
   ```

### For Personal Repositories (BuildJet)

1. **Update existing workflows:**
   ```bash
   # Simple replacement
   sed -i 's/runs-on: ubuntu-latest/runs-on: buildjet-2vcpu-ubuntu-2204/g' .github/workflows/*.yml
   ```

2. **Or use the migration script:**
   ```bash
   ./scripts/migrate-to-buildjet.sh
   ```

## Performance Comparison

| Runner Type | vCPUs | RAM | Storage | Build Time (avg) | Cost |
|------------|-------|-----|---------|------------------|------|
| GitHub-hosted | 2 | 7GB | 14GB | 100% (baseline) | Free* |
| Blacksmith 2vcpu | 2 | 8GB | 50GB | 70% | $$ |
| Blacksmith 4vcpu | 4 | 16GB | 50GB | 40% | $$$ |
| BuildJet 2vcpu | 2 | 8GB | 50GB | 65% | $$ |
| BuildJet 4vcpu | 4 | 16GB | 50GB | 35% | $$$ |

*Free for public repos, limited minutes for private repos

## Best Practices

1. **Always use fallback for critical workflows**
   - Production deployments should have fallback runners
   - CI/CD pipelines should not fail due to runner unavailability

2. **Choose appropriate runner size**
   - Use 2vcpu for simple builds and tests
   - Use 4vcpu for complex builds or parallel tests
   - Use 8vcpu+ for resource-intensive tasks

3. **Monitor runner usage**
   - Track build times and costs
   - Optimize runner selection based on workload

4. **Cache aggressively**
   - Blacksmith and BuildJet have better cache performance
   - Use actions/cache for dependencies

## Troubleshooting

### Runner Not Available
```yaml
Error: No runner matching the specified labels was found: blacksmith-2vcpu-ubuntu-2204
```
**Solution**: Ensure Blacksmith/BuildJet is configured for your organization/account, or use fallback configuration.

### Slow Performance on Fallback
```yaml
Warning: Running on fallback runner, performance may be degraded
```
**Solution**: This is expected. Consider upgrading to ensure primary runners are available.

### Authentication Issues
```yaml
Error: Blacksmith runner authentication failed
```
**Solution**: Check organization settings and runner registration.

## Related Documentation

- [GitHub Actions Best Practices](./GITHUB_ACTIONS_BEST_PRACTICES.md)
- [Blacksmith Documentation](https://docs.blacksmith.sh)
- [BuildJet Documentation](https://docs.buildjet.com)
- [GitHub-Hosted Runners](https://docs.github.com/en/actions/using-github-hosted-runners)