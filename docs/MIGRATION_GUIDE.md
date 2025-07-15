# Migration Guide

This guide helps you migrate from individual workflow files to the centralized `batumi-works/actions-lib` approach.

## 🎯 Migration Benefits

- **90% reduction** in workflow code duplication
- **Single source of truth** for all Claude Code integrations
- **Consistent error handling** and patterns
- **Easier maintenance** - one change updates all repositories
- **Better testing** of reusable components
- **Faster onboarding** for new repositories

## 📋 Pre-Migration Checklist

- [ ] Review current workflow files
- [ ] Identify required secrets (CLAUDE_CODE_OAUTH_TOKEN, ANTHROPIC_AUTH_TOKEN)
- [ ] Test workflows in a development environment
- [ ] Create backup of existing workflows

## 🔄 Automatic Migration

Use the provided migration script:

```bash
# Clone the actions-lib repository
git clone https://github.com/batumi-works/actions-lib.git

# Run migration script on your repository
./actions-lib/scripts/migrate-workflows.sh /path/to/your/repository
```

The script will:
1. Create backups of existing workflows
2. Replace workflow files with thin wrappers
3. Create Dependabot configuration
4. Provide migration summary

## 🛠️ Manual Migration

### Before: Complex Workflow (100+ lines)

```yaml
name: Claude PRP Implementation

on:
  issue_comment:
    types: [created]

jobs:
  implement-prp:
    runs-on: ubuntu-latest
    if: contains(github.event.comment.body, 'PRPs/') && contains(github.event.comment.body, '.md')
    env:
      CLAUDE_CODE_OAUTH_TOKEN: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
      GITHUB_TOKEN: ${{ github.token }}
    steps:
      - uses: actions/checkout@v4
        with: 
          fetch-depth: 0
          token: ${{ github.token }}
      # ... 80+ more lines of complex logic
```

### After: Thin Wrapper (8 lines)

```yaml
name: Claude PRP Implementation

on:
  issue_comment:
    types: [created]

jobs:
  implement-prp:
    if: contains(github.event.comment.body, 'PRPs/') && contains(github.event.comment.body, '.md')
    uses: batumi-works/actions-lib/.github/workflows/claude-prp-pipeline.yml@v1
    with:
      api_provider: "anthropic"
    secrets:
      claude_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
      github_token: ${{ secrets.GITHUB_TOKEN }}
```

## 📝 Migration Mapping

| Original Workflow | New Wrapper | API Provider |
|------------------|-------------|--------------|
| `claude-prp-implementation.yml` | `claude-prp-pipeline.yml@v1` | `anthropic` |
| `kimi-implementation.yml` | `claude-prp-pipeline.yml@v1` | `moonshot` |
| `claude-agents.yml` | `claude-agent-pipeline.yml@v1` | `anthropic` |
| `kimi-create-prp.yml` | `claude-agent-pipeline.yml@v1` | `moonshot` |
| `claude.yml` | No change (already optimized) | N/A |
| `claude-code-review.yml` | No change (already optimized) | N/A |

## 🔧 Configuration Options

### Claude PRP Pipeline

```yaml
uses: batumi-works/actions-lib/.github/workflows/claude-prp-pipeline.yml@v1
with:
  api_provider: "anthropic"        # or "moonshot"
  anthropic_base_url: ""           # for Moonshot: "https://api.moonshot.ai/anthropic"
  timeout_minutes: 90              # default: 90
  claude_model: "claude-sonnet-4-20250514"  # default
  skip_pr_check: false             # default: false
  git_user_name: "Custom Bot Name" # default: "Claude PRP Implementation Bot"
  git_user_email: "bot@example.com"  # default: "claude-prp-bot@users.noreply.github.com"
```

### Claude Agent Pipeline

```yaml
uses: batumi-works/actions-lib/.github/workflows/claude-agent-pipeline.yml@v1
with:
  api_provider: "anthropic"        # or "moonshot"
  anthropic_base_url: ""           # for Moonshot: "https://api.moonshot.ai/anthropic"
  timeout_minutes: 60              # default: 60
  claude_model: "claude-sonnet-4-20250514"  # default
  bot_username: "My Bot"           # default: "Claude Multi-Agent Bot"
  git_user_name: "Custom Bot Name" # default: "Claude Multi-Agent Bot"
  git_user_email: "bot@example.com"  # default: "claude-agents@users.noreply.github.com"
  commit_message_prefix: "feat: create PRP for issue"  # default
```

## 🔐 Required Secrets

Make sure these secrets are configured in your repository:

### For Anthropic API
- `CLAUDE_CODE_OAUTH_TOKEN`: Claude Code OAuth token
- `GITHUB_TOKEN`: Automatically provided by GitHub Actions

### For Moonshot API
- `ANTHROPIC_AUTH_TOKEN`: Anthropic API token (for Moonshot)
- `GITHUB_TOKEN`: Automatically provided by GitHub Actions

## 🚀 Post-Migration Steps

1. **Test workflows** in development environment
2. **Update repository permissions** if needed
3. **Configure Dependabot** for automated updates
4. **Document custom configurations** for your team
5. **Monitor workflow execution** for any issues

## 📊 Expected Results

### Code Reduction
- **Before**: 6 workflows with 300+ lines total
- **After**: 6 workflows with ~50 lines total
- **Reduction**: 90% less code to maintain

### Maintenance Benefits
- **Centralized updates**: One change affects all repositories
- **Consistent behavior**: Same logic everywhere
- **Better testing**: Reusable components are tested once
- **Faster debugging**: Common issues fixed in one place

## 🔍 Troubleshooting

### Common Issues

**Issue**: Workflow not triggering
**Solution**: Check if conditions match (PRP path in comment)

**Issue**: Permission denied
**Solution**: Ensure repository has required permissions

**Issue**: Secret not found
**Solution**: Verify secret names and availability

**Issue**: API rate limits
**Solution**: Adjust timeout_minutes or schedule intervals

### Debug Mode

Enable debug logging:
```yaml
env:
  ACTIONS_STEP_DEBUG: true
```

## 📚 Additional Resources

- [Actions Library README](../README.md)
- [Claude Code Action Troubleshooting](./claude-code-action-troubleshooting.md)
- [Workflow Templates](../.github/workflow-templates/)
- [Dependabot Example](./dependabot-example.yml)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)

## 🆘 Getting Help

If you encounter issues during migration:

1. Check the [troubleshooting section](../README.md#troubleshooting)
2. Review workflow execution logs
3. Create an issue in the [actions-lib repository](https://github.com/batumi-works/actions-lib/issues)
4. Include relevant logs and configuration details