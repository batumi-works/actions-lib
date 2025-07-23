#!/usr/bin/env bash
# Migrate GitHub Actions workflows to use BuildJet runners for personal repos
# Includes automatic fallback configuration

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# BuildJet runner mapping
declare -A RUNNER_MAP=(
    ["ubuntu-latest"]="buildjet-2vcpu-ubuntu-2204"
    ["ubuntu-22.04"]="buildjet-2vcpu-ubuntu-2204"
    ["ubuntu-20.04"]="buildjet-2vcpu-ubuntu-2204"
    ["ubuntu-18.04"]="buildjet-2vcpu-ubuntu-2204"
)

# Function to print colored output
print_color() {
    local color=$1
    shift
    echo -e "${color}$*${NC}"
}

# Function to update workflow file
update_workflow() {
    local file=$1
    local backup_file="${file}.backup"
    local updates_made=0
    
    print_color "$BLUE" "Processing: $file"
    
    # Create backup
    cp "$file" "$backup_file"
    
    # Create temporary file for processing
    local temp_file=$(mktemp)
    
    # Process the file line by line
    while IFS= read -r line; do
        # Check if line contains runs-on
        if [[ "$line" =~ ^[[:space:]]*runs-on:[[:space:]]* ]]; then
            # Extract the current runner
            local current_runner=$(echo "$line" | sed -E 's/^[[:space:]]*runs-on:[[:space:]]*//;s/[[:space:]]*$//')
            
            # Remove quotes if present
            current_runner=$(echo "$current_runner" | sed 's/^["'"'"']//;s/["'"'"']$//')
            
            # Check if we have a mapping for this runner
            if [[ -n "${RUNNER_MAP[$current_runner]:-}" ]]; then
                local new_runner="${RUNNER_MAP[$current_runner]}"
                local indent=$(echo "$line" | sed -E 's/^([[:space:]]*)runs-on:.*/\1/')
                
                # Write the updated line with fallback comment
                echo "${indent}runs-on: $new_runner # BuildJet runner (fallback: $current_runner)" >> "$temp_file"
                print_color "$GREEN" "  ✓ Updated: $current_runner → $new_runner"
                ((updates_made++))
            else
                # Keep the line as is
                echo "$line" >> "$temp_file"
            fi
        else
            # Keep the line as is
            echo "$line" >> "$temp_file"
        fi
    done < "$file"
    
    # Replace the original file with the updated one
    mv "$temp_file" "$file"
    
    if [[ $updates_made -eq 0 ]]; then
        print_color "$YELLOW" "  No updates needed"
        rm "$backup_file"
    else
        print_color "$GREEN" "  Updated $updates_made runner reference(s)"
    fi
    
    echo ""
}

# Function to add fallback workflow template
add_fallback_template() {
    local template_dir=".github/workflow-templates"
    local template_file="$template_dir/buildjet-fallback.yml"
    
    if [[ ! -d "$template_dir" ]]; then
        mkdir -p "$template_dir"
    fi
    
    if [[ ! -f "$template_file" ]]; then
        print_color "$BLUE" "Creating fallback workflow template..."
        
        cat > "$template_file" << 'EOF'
name: 'BuildJet Runner with Fallback'

on:
  workflow_dispatch:

jobs:
  # Primary job on BuildJet runner
  build-primary:
    runs-on: buildjet-2vcpu-ubuntu-2204
    continue-on-error: true
    outputs:
      completed: ${{ steps.check.outputs.completed }}
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        
      - name: Build
        id: build
        run: |
          echo "Building on BuildJet runner..."
          # Your build steps here
          
      - name: Mark Success
        id: check
        if: success()
        run: echo "completed=true" >> $GITHUB_OUTPUT

  # Fallback job on GitHub-hosted runner
  build-fallback:
    needs: build-primary
    if: needs.build-primary.outputs.completed != 'true'
    runs-on: ubuntu-latest
    steps:
      - name: Fallback Warning
        run: |
          echo "::warning::BuildJet runner unavailable, using GitHub-hosted runner"
          
      - name: Checkout
        uses: actions/checkout@v4
        
      - name: Build
        run: |
          echo "Building on fallback runner..."
          # Same build steps here
EOF
        
        print_color "$GREEN" "✓ Created fallback template: $template_file"
    fi
}

# Function to find workflow files
find_workflow_files() {
    find . -path "./.github/workflows/*.yml" -o -path "./.github/workflows/*.yaml" | grep -v ".backup$"
}

# Main execution
main() {
    print_color "$BLUE" "=== BuildJet Runner Migration Tool ==="
    print_color "$YELLOW" "This tool will migrate your workflows to use BuildJet runners"
    echo ""
    
    # Check if we're in a git repository
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        print_color "$RED" "Error: Not in a git repository"
        exit 1
    fi
    
    # Check repository owner
    local repo_url=$(git config --get remote.origin.url)
    if [[ ! "$repo_url" =~ batumilove ]]; then
        print_color "$YELLOW" "Warning: This doesn't appear to be a batumilove personal repository"
        read -p "Continue anyway? (y/N) " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 0
        fi
    fi
    
    # Find workflow files
    print_color "$BLUE" "Searching for workflow files..."
    local workflow_files=$(find_workflow_files)
    local workflow_count=$(echo "$workflow_files" | grep -c "." || echo "0")
    
    if [[ $workflow_count -eq 0 ]]; then
        print_color "$YELLOW" "No workflow files found"
        exit 0
    fi
    
    print_color "$GREEN" "Found $workflow_count workflow file(s)"
    echo ""
    
    # Process each workflow file
    echo "$workflow_files" | while read -r file; do
        update_workflow "$file"
    done
    
    # Add fallback template
    add_fallback_template
    
    # Summary
    print_color "$BLUE" "=== Migration Summary ==="
    print_color "$GREEN" "✓ Workflows migrated to BuildJet runners"
    print_color "$YELLOW" "📝 Backup files created with .backup extension"
    echo ""
    
    # Show recommended next steps
    print_color "$BLUE" "Recommended next steps:"
    echo "1. Review the changes: git diff"
    echo "2. Test workflows in a feature branch"
    echo "3. Configure repository variables:"
    echo "   - BUILDJET_ENABLED: true"
    echo "   - FALLBACK_RUNNER_ENABLED: true"
    echo "4. Sign up for BuildJet: https://buildjet.com"
    echo "5. Commit and push changes"
    echo ""
    
    # Offer to remove backups
    read -p "Remove backup files? (y/N) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        find . -name "*.yml.backup" -o -name "*.yaml.backup" | xargs rm -f
        print_color "$GREEN" "✓ Backup files removed"
    fi
}

# Run main function
main "$@"