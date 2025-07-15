#!/bin/bash

# Migration script for transitioning to batumi-works/actions-lib workflows
# Usage: ./migrate-workflows.sh [repository-path]

set -e

REPO_PATH="${1:-.}"
BACKUP_DIR="${REPO_PATH}/.github/workflows/backup-$(date +%Y%m%d-%H%M%S)"

echo "🔄 Starting workflow migration to batumi-works/actions-lib..."
echo "📁 Repository path: $REPO_PATH"
echo "💾 Backup directory: $BACKUP_DIR"

# Check if repository exists
if [ ! -d "$REPO_PATH" ]; then
    echo "❌ Error: Repository path does not exist: $REPO_PATH"
    exit 1
fi

# Check if .github/workflows exists
if [ ! -d "$REPO_PATH/.github/workflows" ]; then
    echo "❌ Error: .github/workflows directory not found in $REPO_PATH"
    exit 1
fi

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Function to migrate a workflow file
migrate_workflow() {
    local file="$1"
    local filename=$(basename "$file")
    local backup_file="$BACKUP_DIR/$filename"
    
    echo "🔄 Migrating $filename..."
    
    # Create backup
    cp "$file" "$backup_file"
    echo "💾 Backed up to $backup_file"
    
    # Determine migration strategy based on filename
    case "$filename" in
        *claude-prp-implementation* | *prp-implementation*)
            cat > "$file" << 'EOF'
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
EOF
            echo "✅ Migrated to Claude PRP Implementation wrapper"
            ;;
            
        *kimi-implementation* | *moonshot-implementation*)
            cat > "$file" << 'EOF'
name: Kimi PRP Implementation

on:
  issue_comment:
    types: [created]

jobs:
  implement-prp:
    if: contains(github.event.comment.body, 'PRPs/') && contains(github.event.comment.body, '.md')
    uses: batumi-works/actions-lib/.github/workflows/claude-prp-pipeline.yml@v1
    with:
      api_provider: "moonshot"
      anthropic_base_url: "https://api.moonshot.ai/anthropic"
    secrets:
      anthropic_auth_token: ${{ secrets.ANTHROPIC_AUTH_TOKEN }}
      github_token: ${{ secrets.GITHUB_TOKEN }}
EOF
            echo "✅ Migrated to Kimi PRP Implementation wrapper"
            ;;
            
        *claude-agents* | *agent-pipeline*)
            cat > "$file" << 'EOF'
name: Claude Agent Pipeline

on:
  schedule:
    - cron: '*/30 * * * *'
  workflow_dispatch:
  issues:
    types: [opened, labeled]
  issue_comment:
    types: [created]

jobs:
  create-prp:
    uses: batumi-works/actions-lib/.github/workflows/claude-agent-pipeline.yml@v1
    with:
      api_provider: "anthropic"
      bot_username: "Claude Multi-Agent Bot"
    secrets:
      claude_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
      github_token: ${{ secrets.GITHUB_TOKEN }}
EOF
            echo "✅ Migrated to Claude Agent Pipeline wrapper"
            ;;
            
        *kimi-create-prp* | *moonshot-create-prp*)
            cat > "$file" << 'EOF'
name: Kimi Create PRP

on:
  schedule:
    - cron: '*/30 * * * *'
  workflow_dispatch:
  issues:
    types: [opened, labeled]
  issue_comment:
    types: [created]

jobs:
  create-prp:
    uses: batumi-works/actions-lib/.github/workflows/claude-agent-pipeline.yml@v1
    with:
      api_provider: "moonshot"
      anthropic_base_url: "https://api.moonshot.ai/anthropic"
      bot_username: "Claude Multi-Agent Bot"
    secrets:
      anthropic_auth_token: ${{ secrets.ANTHROPIC_AUTH_TOKEN }}
      github_token: ${{ secrets.GITHUB_TOKEN }}
EOF
            echo "✅ Migrated to Kimi Create PRP wrapper"
            ;;
            
        *claude-code-review*)
            # This one is already simple, just clean it up
            echo "ℹ️  Claude Code Review is already optimized, no changes needed"
            ;;
            
        *claude.yml)
            # This one is already simple, just clean it up
            echo "ℹ️  Claude Code workflow is already optimized, no changes needed"
            ;;
            
        *)
            echo "⚠️  Unknown workflow pattern: $filename - skipping migration"
            ;;
    esac
}

# Find and migrate workflow files
echo "🔍 Scanning for workflow files..."
find "$REPO_PATH/.github/workflows" -name "*.yml" -o -name "*.yaml" | while read -r file; do
    if [ -f "$file" ]; then
        migrate_workflow "$file"
    fi
done

# Create Dependabot configuration
echo "🔧 Creating Dependabot configuration..."
cat > "$REPO_PATH/.github/dependabot.yml" << 'EOF'
version: 2
updates:
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
      day: "monday"
      time: "09:00"
    open-pull-requests-limit: 5
    commit-message:
      prefix: "chore"
      include: "scope"
    labels:
      - "dependencies"
      - "github-actions"
    allow:
      - dependency-name: "batumi-works/actions-lib"
      - dependency-name: "actions/*"
      - dependency-name: "anthropics/*"
    groups:
      actions-lib:
        patterns:
          - "batumi-works/actions-lib"
        update-types:
          - "minor"
          - "patch"
EOF

echo "✅ Created Dependabot configuration"

# Summary
echo ""
echo "🎉 Migration completed successfully!"
echo ""
echo "📋 Summary:"
echo "   - Workflow files migrated to use batumi-works/actions-lib@v1"
echo "   - Original files backed up to: $BACKUP_DIR"
echo "   - Dependabot configuration created"
echo ""
echo "🔍 Next steps:"
echo "   1. Review the migrated workflow files"
echo "   2. Test the workflows in a development environment"
echo "   3. Update any custom configurations if needed"
echo "   4. Commit the changes to your repository"
echo ""
echo "📚 For more information, see:"
echo "   https://github.com/batumi-works/actions-lib/blob/main/README.md"