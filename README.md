# Batumi Works Actions Library

Centralized GitHub Actions library for Batumi Works repositories, providing reusable workflows and composite actions for AI-driven development workflows.

## 🚀 Quick Start

### For PRP Implementation
```yaml
name: Claude PRP Implementation
on:
  issue_comment:
    types: [created]
jobs:
  implement-prp:
    uses: batumi-works/actions-lib/.github/workflows/claude-prp-pipeline.yml@v1
    with:
      api_provider: "anthropic"
    secrets:
      claude_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
      github_token: ${{ secrets.GITHUB_TOKEN }}
```

### For PRP Creation
```yaml
name: Claude Agent Pipeline
on:
  issues:
    types: [opened, labeled]
  issue_comment:
    types: [created]
  schedule:
    - cron: '*/30 * * * *'
jobs:
  create-prp:
    uses: batumi-works/actions-lib/.github/workflows/claude-agent-pipeline.yml@v1
    with:
      api_provider: "anthropic"
    secrets:
      claude_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
      github_token: ${{ secrets.GITHUB_TOKEN }}
```

## 📂 Library Structure

```
batumi-works/actions-lib/
├── .github/workflows/           # Reusable workflows
│   ├── claude-prp-pipeline.yml     # PRP implementation workflow
│   └── claude-agent-pipeline.yml   # PRP creation workflow
├── actions/                     # Composite actions
│   ├── claude-setup/               # Common Claude setup
│   ├── prp-management/             # PRP file operations
│   └── github-operations/          # GitHub API operations
└── .github/workflow-templates/  # Workflow templates
```

## 🔧 Composite Actions

### Claude Setup (`actions/claude-setup`)
Common setup steps for Claude Code workflows.

**Inputs:**
- `claude_oauth_token` (required): Claude Code OAuth token
- `github_token` (required): GitHub token for repository access
- `fetch_depth` (default: '0'): Number of commits to fetch
- `git_user_name` (default: 'Claude AI Bot'): Git user name
- `git_user_email` (default: 'claude-ai@users.noreply.github.com'): Git user email
- `configure_git` (default: 'true'): Whether to configure git user

**Outputs:**
- `repository_path`: Path to the checked out repository

### PRP Management (`actions/prp-management`)
PRP file and branch management operations.

**Inputs:**
- `comment_body` (required): GitHub comment body containing PRP path
- `issue_number` (required): GitHub issue number
- `create_branch` (default: 'true'): Whether to create implementation branch
- `move_to_done` (default: 'true'): Whether to move PRP to done folder

**Outputs:**
- `prp_path`: Path to the PRP file
- `prp_name`: Name of the PRP file (without extension)
- `branch_name`: Name of the implementation branch
- `has_prp`: Whether a valid PRP was found

### GitHub Operations (`actions/github-operations`)
GitHub API operations for PRs, issues, and comments.

**Inputs:**
- `github_token` (required): GitHub token for API operations
- `operation` (required): Type of operation: `create-pr`, `comment-issue`, `check-bot-status`
- `issue_number`: GitHub issue number
- `pr_title`: Pull request title
- `pr_body`: Pull request body
- `pr_head`: Pull request head branch
- `pr_base` (default: 'main'): Pull request base branch
- `comment_body`: Comment body text
- `bot_username` (default: 'Claude AI Bot'): Bot username to check for existing comments
- `draft_pr` (default: 'false'): Create PR as draft

**Outputs:**
- `pr_number`: Created PR number
- `pr_url`: Created PR URL
- `should_process`: Whether bot should process (for bot status check)
- `comment_id`: Created comment ID

## 🔄 Reusable Workflows

### Claude PRP Pipeline (`claude-prp-pipeline.yml`)
Implements PRPs from GitHub issue comments. Consolidates functionality from multiple similar workflows.

**Supported API Providers:**
- **Anthropic**: Direct Claude API integration
- **Moonshot**: Anthropic-compatible API endpoint

**Inputs:**
- `api_provider` (default: 'anthropic'): API provider to use
- `anthropic_base_url`: Base URL for Anthropic API (for Moonshot)
- `timeout_minutes` (default: 90): Timeout for Claude Code execution
- `allowed_tools` (default: 'Bash,Read,Write,Edit,Glob,Grep,Task,LS,MultiEdit,NotebookRead,NotebookEdit,WebFetch,WebSearch,TodoWrite'): Allowed tools for Claude Code (**Note**: Do not use wildcards like `Bash(git:*)` as they break parsing)
- `claude_model` (default: 'claude-sonnet-4-20250514'): Claude model to use
- `skip_pr_check` (default: false): Skip PR reference check
- `git_user_name`: Git user name for commits
- `git_user_email`: Git user email for commits

**Secrets:**
- `claude_oauth_token`: Claude Code OAuth token (for Anthropic)
- `anthropic_auth_token`: Anthropic API token (for Moonshot)
- `github_token`: GitHub token

### Claude Agent Pipeline (`claude-agent-pipeline.yml`)
Creates PRPs from GitHub issues and comments. Supports scheduled runs and manual triggers.

**Inputs:**
- `api_provider` (default: 'anthropic'): API provider to use
- `anthropic_base_url`: Base URL for Anthropic API (for Moonshot)
- `timeout_minutes` (default: 60): Timeout for Claude Code execution
- `allowed_tools` (default: 'Bash,Read,Write,Edit,Glob,Grep,Task,LS,MultiEdit,NotebookRead,NotebookEdit,WebFetch,WebSearch,TodoWrite'): Allowed tools for Claude Code (**Note**: Do not use wildcards like `Bash(git:*)` as they break parsing)
- `claude_model` (default: 'claude-sonnet-4-20250514'): Claude model to use
- `bot_username` (default: 'Claude Multi-Agent Bot'): Bot username for duplicate check
- `git_user_name`: Git user name for commits
- `git_user_email`: Git user email for commits
- `commit_message_prefix` (default: 'feat: create PRP for issue'): Prefix for commit messages

**Secrets:**
- `claude_oauth_token`: Claude Code OAuth token (for Anthropic)
- `anthropic_auth_token`: Anthropic API token (for Moonshot)
- `github_token`: GitHub token

## 🏷️ Versioning

This library uses semantic versioning. Pin to major versions for stability:

```yaml
uses: batumi-works/actions-lib/.github/workflows/claude-prp-pipeline.yml@v1
```

Available versions:
- `@v1`: Latest v1.x.x (recommended)
- `@v1.0.0`: Specific version
- `@main`: Latest development version (not recommended for production)

## 🔐 Security

### Required Secrets
- `CLAUDE_CODE_OAUTH_TOKEN`: For Anthropic API access
- `ANTHROPIC_AUTH_TOKEN`: For Moonshot API access (alternative)
- `GITHUB_TOKEN`: Automatically provided by GitHub Actions

### Permissions
Workflows require these permissions:
```yaml
permissions:
  contents: write    # For repository operations
  issues: write      # For issue comments
  pull-requests: write  # For PR creation
```

## 🎯 Migration Guide

### From Individual Workflows
Replace your existing workflow files with thin wrappers:

**Before:**
```yaml
# 100+ lines of workflow code
```

**After:**
```yaml
name: Claude PRP Implementation
on:
  issue_comment:
    types: [created]
jobs:
  implement-prp:
    uses: batumi-works/actions-lib/.github/workflows/claude-prp-pipeline.yml@v1
    with:
      api_provider: "anthropic"
    secrets:
      claude_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
      github_token: ${{ secrets.GITHUB_TOKEN }}
```

### Configuration Migration
1. Update secret names if needed
2. Adjust input parameters for your specific use case
3. Test with a single repository first
4. Roll out to all repositories

## 📋 Workflow Templates

Pre-configured templates are available in `.github/workflow-templates/` for:
- PRP implementation workflows
- PRP creation workflows
- Code review workflows
- Basic Claude integration

## 🔄 Dependabot Configuration

Add to your repository's `.github/dependabot.yml`:

```yaml
version: 2
updates:
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
    allow:
      - dependency-name: "batumi-works/actions-lib"
```

## 🐛 Troubleshooting

### Common Issues

**1. Missing Required Secrets**
```
Error: claude_oauth_token is required for Anthropic API
```
Solution: Add the required secret to your repository settings.

**2. Permission Denied**
```
Error: Resource not accessible by integration
```
Solution: Ensure your workflow has the required permissions.

**3. API Provider Configuration**
```
Error: anthropic_auth_token is required for Moonshot API
```
Solution: Configure the correct API provider and corresponding secret.

**4. Bash Permissions Not Granted** ⚠️ **Critical**
```
Error: permissions not granted for bash commands
```
Solution: Do not use wildcards in `allowed_tools`. Use simple tool names:
```yaml
# ❌ INCORRECT - breaks parsing
allowed_tools: "Bash(git:*),Read,Write"

# ✅ CORRECT - use simple tool names
allowed_tools: "Bash,Read,Write,Edit,Glob,Grep,Task,LS,MultiEdit,NotebookRead,NotebookEdit,WebFetch,WebSearch,TodoWrite"
```

**5. Git Submodule Exit Code 128**
```
Error: fatal: No url found for submodule path 'claude-sessions' in .gitmodules
```
Solution: Remove orphaned submodule references:
```bash
git rm --cached claude-sessions
rm -rf claude-sessions
git add -A
git commit -m "fix: remove orphaned claude-sessions submodule reference"
```

### Debug Mode
Enable debug logging by setting `ACTIONS_STEP_DEBUG=true` in your repository secrets.

## 🤝 Contributing

1. Fork this repository
2. Create a feature branch
3. Test your changes with a pilot repository
4. Submit a pull request with detailed description

### Development Guidelines
- Follow semantic versioning
- Test all composite actions independently
- Document input/output parameters
- Include error handling and validation

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

For issues and questions:
1. Check the [troubleshooting section](#troubleshooting)
2. Search existing GitHub issues
3. Create a new issue with detailed information

---

**Generated with Claude Code** 🤖