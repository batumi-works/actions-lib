# Claude Code Action Troubleshooting Guide

This document provides a comprehensive guide to resolving common issues with the Anthropic Claude Code Action in GitHub Actions workflows.

## Table of Contents
1. [Overview](#overview)
2. [Critical Issues and Solutions](#critical-issues-and-solutions)
3. [Configuration Best Practices](#configuration-best-practices)
4. [Testing and Validation](#testing-and-validation)
5. [Additional Resources](#additional-resources)

## Overview

The Claude Code Action enables AI-powered code assistance within GitHub Actions workflows. However, several critical issues can prevent it from functioning properly. This guide documents the issues encountered and their solutions.

## Critical Issues and Solutions

### 1. Git Submodule Exit Code 128 Error

**Problem:**
- GitHub Actions workflow fails with `git` exit code 128
- Error: `fatal: No url found for submodule path 'claude-sessions' in .gitmodules`
- Prevents Claude from working in PR environments

**Root Cause:**
Orphaned submodule references exist in the git tree without corresponding `.gitmodules` file entries.

**Solution:**
```bash
# Remove orphaned submodule from git index
git rm --cached claude-sessions

# Remove directory if exists
rm -rf claude-sessions

# Commit and push changes
git add -A
git commit -m "fix: remove orphaned claude-sessions submodule reference"
git push origin <branch-name>
```

**Verification:**
```bash
# Verify no submodule references remain
git ls-tree -r HEAD | grep -i claude-sessions  # Should return nothing
git submodule status  # Should return nothing
```

### 2. Bash Permissions Not Granted Error

**Problem:**
- Claude reports "permissions not granted" for bash commands
- Occurs even when `allowed_tools` includes bash permissions
- Prevents Claude from executing git operations and committing changes

**Root Cause:**
Using wildcard syntax like `Bash(*)` in `allowed_tools` breaks the parsing mechanism.

**Solution:**
Configure `allowed_tools` with simple tool names without wildcards:

```yaml
# ❌ INCORRECT - breaks parsing
allowed_tools: "Bash(*),Bash(git:*),Bash(npm:*)"

# ✅ CORRECT - use simple tool names  
allowed_tools: "Bash,Glob,Grep,LS,exit_plan_mode,Read,Edit,MultiEdit,Write,NotebookRead,NotebookEdit,WebFetch,TodoWrite,WebSearch,Task"
```

**Reference:**
- GitHub Issue: [anthropics/claude-code-action#74](https://github.com/anthropics/claude-code-action/issues/74)
- Solution provided by `ashwin-ant` (Anthropic collaborator)

### 3. Contents Write Permission Missing

**Problem:**
- Claude cannot commit changes to repository
- Error: Access denied for git operations

**Root Cause:**
Default GitHub Actions permissions are read-only.

**Solution:**
Add proper permissions to workflow:

```yaml
permissions:
  contents: write        # ✅ Required for commits
  pull-requests: write   # ✅ Required for PR comments
  issues: write          # ✅ Required for issue comments
  id-token: write
  actions: read
```

### 4. Claude Code Authentication Error (OIDC Token Exchange)

**Problem:**
- Claude Code Action fails with "User does not have write access" error
- Occurs when using `claude-code-action@beta` without `github_token` parameter
- Authentication fails due to OIDC token exchange issues

**Root Cause:**
Claude Code Action tries to use OIDC token exchange by default, which may not have sufficient permissions.

**Solution:**
Add `github_token` parameter to force use of OAuth token:

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

### 5. Detached HEAD State in PR Context

**Problem:**
- GitHub Actions checks out PRs in detached HEAD state
- Can cause issues with git operations

**Root Cause:**
Default behavior of `actions/checkout` for PR triggers.

**Solution:**
The Claude Code Action handles this automatically. No additional configuration needed.

## Configuration Best Practices

### Complete Working Configuration

```yaml
name: Claude Code

on:
  issue_comment:
    types: [created]
  pull_request_review_comment:
    types: [created]
  issues:
    types: [opened, assigned]
  pull_request_review:
    types: [submitted]

jobs:
  claude:
    if: |
      (github.event_name == 'issue_comment' && contains(github.event.comment.body, '@claude')) ||
      (github.event_name == 'pull_request_review_comment' && contains(github.event.comment.body, '@claude')) ||
      (github.event_name == 'pull_request_review' && contains(github.event.review.body, '@claude')) ||
      (github.event_name == 'issues' && (contains(github.event.issue.body, '@claude') || contains(github.event.issue.title, '@claude')))
    runs-on: ubuntu-latest
    permissions:
      contents: write
      pull-requests: write  # Required for PR comments
      issues: write         # Required for issue comments
      id-token: write
      actions: read
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
        with:
          fetch-depth: 1

      - name: Run Claude Code
        id: claude
        uses: anthropics/claude-code-action@beta
        with:
          claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
          github_token: ${{ secrets.GITHUB_TOKEN }}
          
          # Allow all necessary tools - NO WILDCARDS
          allowed_tools: "Bash,Glob,Grep,LS,exit_plan_mode,Read,Edit,MultiEdit,Write,NotebookRead,NotebookEdit,WebFetch,TodoWrite,WebSearch,Task"
          
          # Custom instructions
          custom_instructions: |
            Follow our coding standards
            Ensure all new code has tests
            Use TypeScript for new files
            After making changes, run npm run typecheck to verify TypeScript
            Commit changes using git commands when work is complete
```

### Environment Variables

Required secrets in GitHub repository settings:
- `CLAUDE_CODE_OAUTH_TOKEN`: OAuth token for Claude Code authentication

### CLAUDE.md Configuration

Add to your repository's `CLAUDE.md` file:

```markdown
## Git Workflow
**IMPORTANT**: Always push changes to the remote repository after committing. When making any code changes:
1. Make your changes
2. Run `npm run typecheck` to verify TypeScript
3. Commit changes with a descriptive message
4. Push to remote repository with `git push origin main`

Do not leave changes uncommitted or unpushed.
```

## Testing and Validation

### 1. Test Bash Permissions

Create a test comment in a PR:
```
@claude Test the bash permissions fix. Please make a simple change to verify that commits now work properly.
```

### 2. Verify Workflow Completion

Check that:
- ✅ Workflow completes without errors
- ✅ No git exit code 128 errors
- ✅ No "permissions not granted" messages
- ✅ Claude successfully commits changes
- ✅ Changes are pushed to the correct branch

### 3. Monitor Workflow Logs

```bash
# Watch workflow run
gh run watch <run-id>

# Check for errors
gh run view <run-id> --log | grep -i error

# Verify commits
git log --oneline -3
```

## Additional Resources

### Known Issues and Workarounds

1. **Issue #2560**: Claude keeps asking for permission despite having it
2. **Issue #2733**: Infinite bash permission loop
3. **Issue #581**: Non-interactive mode doesn't respect configured permissions
4. **Issue #1614**: Permission prompts override CLAUDE.md instructions

### Security Considerations

- Claude Code Action operates in a sandboxed environment
- Limited to repository scope with short-lived tokens
- Cannot submit formal PR reviews or approve PRs
- No cross-repository access

### Beta Status

The Claude Code Action is currently in beta:
- Features may change
- Some functionality may be limited
- Regular updates and improvements expected

### Support Resources

- [Claude Code Documentation](https://docs.anthropic.com/en/docs/claude-code/github-actions)
- [GitHub Repository](https://github.com/anthropics/claude-code-action)
- [Troubleshooting Guide](https://docs.anthropic.com/en/docs/claude-code/troubleshooting)

## Changelog

- **2025-07-15**: Added bash permissions fix (Issue #74 solution)
- **2025-07-15**: Added submodule cleanup solution
- **2025-07-15**: Added complete working configuration
- **2025-07-15**: Documented contents write permission requirement

---

*This guide is based on real-world troubleshooting of the Claude Code Action in production environments. Keep this document updated as new issues and solutions are discovered.*