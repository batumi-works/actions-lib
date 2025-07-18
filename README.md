# Batumi Works Actions Library

Centralized GitHub Actions library for Batumi Works repositories, providing reusable workflows and composite actions for AI-driven development workflows.

## 🚀 Quick Start

> **Important**: All workflows require specific permissions to function correctly. See the [Permissions](#permissions) section below.

### For PRP Implementation
```yaml
name: Claude PRP Implementation
on:
  issue_comment:
    types: [created]

# Required permissions for the workflow
permissions:
  contents: write
  issues: write
  pull-requests: write

jobs:
  implement-prp:
    uses: batumi-works/actions-lib/.github/workflows/claude-prp-pipeline.yml@v1.3.0
    with:
      api_provider: "anthropic"
    secrets:
      claude_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
      bot_token: ${{ secrets.GITHUB_TOKEN }}
```

### For PRP Creation
```yaml
name: Claude Agent Pipeline
on:
  issues:
    types: [opened, labeled]
  issue_comment:
    types: [created]

# Required permissions for the workflow
permissions:
  contents: write
  issues: write
  pull-requests: read
  schedule:
    - cron: '*/30 * * * *'
jobs:
  create-prp:
    uses: batumi-works/actions-lib/.github/workflows/claude-agent-pipeline.yml@v1
    with:
      api_provider: "anthropic"
    secrets:
      claude_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
      bot_token: ${{ secrets.GITHUB_TOKEN }}
```

## 🔐 Permissions

All reusable workflows in this library require specific GitHub Actions permissions to function correctly. When calling these workflows, you **must** specify the required permissions in your workflow file.

### Required Permissions

| Workflow | Contents | Issues | Pull Requests |
|----------|----------|---------|---------------|
| `claude-agent-pipeline.yml` | write | write | read |
| `claude-prp-pipeline.yml` | write | write | write |

### Why These Permissions Are Needed

- **contents: write** - Required to create branches, commit changes, and push to the repository
- **issues: write** - Required to comment on issues with status updates and results
- **pull-requests: read/write** - Required to check PR references and create new pull requests

### Common Permission Errors

If you see this error:
```
The nested job 'xyz' is requesting 'contents: write, issues: write', 
but is only allowed 'contents: read, issues: none'
```

It means your calling workflow needs to add the permissions block shown in the examples above.

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
- `bot_token` (required): GitHub token for repository access
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
- `bot_token` (required): GitHub token for API operations
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
      bot_token: ${{ secrets.GITHUB_TOKEN }}
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

## 🧪 Testing

This library includes a comprehensive test suite to ensure reliability and quality.

### Quick Testing

#### Docker Testing (Recommended)
```bash
# Validate setup and run all tests
./scripts/docker-test.sh validate
./scripts/docker-test.sh test

# Run specific test types
./scripts/docker-test.sh unit          # Unit tests only
./scripts/docker-test.sh integration   # Integration tests only
./scripts/docker-test.sh security      # Security scans only

# Interactive development
./scripts/docker-test.sh shell
```

#### Native Testing
```bash
# Install dependencies and run tests
./scripts/setup-test-env.sh
make test

# Run specific test types
make test-unit         # Unit tests only
make test-integration  # Integration tests only
make test-e2e         # End-to-end tests only
```

### Test Architecture

- **Unit Tests (70%)**: Test individual components in isolation
- **Integration Tests (20%)**: Test complete composite actions
- **E2E Tests (10%)**: Test real workflows with GitHub API
- **Security Tests**: Static analysis and vulnerability scanning
- **Performance Tests**: Benchmarking and optimization

### Continuous Integration

Tests automatically run on:
- Every push to main/develop
- Pull requests
- Daily scheduled runs
- Manual workflow dispatch

See [Testing Guide](./docs/TESTING_GUIDE.md) and [Docker Testing Guide](./docs/DOCKER_TESTING.md) for detailed documentation.

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
Solution: Ensure your workflow has the required permissions:
```yaml
permissions:
  contents: write        # For commits
  pull-requests: write   # For PR comments
  issues: write          # For issue comments
  id-token: write
  actions: read
```

**3. API Provider Configuration**
```
Error: anthropic_auth_token is required for Moonshot API
```
Solution: Configure the correct API provider and corresponding secret.

**4. Claude Code Authentication Error** ⚠️ **Critical**
```
Error: User does not have write access
```
Solution: Add `github_token` parameter to force OAuth token usage:
```yaml
# ❌ INCORRECT - may fail with auth error
- name: Run Claude Code
  uses: anthropics/claude-code-action@beta
  with:
    claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}

# ✅ CORRECT - includes github_token parameter
- name: Run Claude Code
  uses: anthropics/claude-code-action@beta
  with:
    claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
    github_token: ${{ secrets.GITHUB_TOKEN }}
```

**5. Bash Permissions Not Granted** ⚠️ **Critical**
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

**6. Git Submodule Exit Code 128**
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

## 📚 Additional Resources

- [Migration Guide](./docs/MIGRATION_GUIDE.md) - Comprehensive guide for migrating from individual workflows
- [Claude Code Action Troubleshooting](./docs/claude-code-action-troubleshooting.md) - Detailed troubleshooting for Claude Code Action issues
- [Workflow Templates](./.github/workflow-templates/) - Pre-configured templates for new repositories
- [Dependabot Example](./docs/dependabot-example.yml) - Example Dependabot configuration
- [GitHub Actions Documentation](https://docs.github.com/en/actions) - Official GitHub Actions documentation

## 🆘 Support

For issues and questions:
1. Check the [troubleshooting section](#troubleshooting)
2. Review the [detailed troubleshooting guide](./docs/claude-code-action-troubleshooting.md)
3. Search existing GitHub issues
4. Create a new issue with detailed information

---

**Generated with Claude Code** 🤖## Documentation

### Troubleshooting Guides
- [GitHub Actions Reusable Workflows Troubleshooting](docs/GITHUB_ACTIONS_REUSABLE_WORKFLOWS_TROUBLESHOOTING.md) - Common issues and solutions for reusable workflows
- [Claude Code Action Troubleshooting](docs/claude-code-action-troubleshooting.md) - Specific issues with Claude Code GitHub Action
