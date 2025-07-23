#!/usr/bin/env bash
# Pin GitHub Actions to specific commit SHAs for security
# Based on best practices from the Obsidian vault

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_color() {
    local color=$1
    shift
    echo -e "${color}$*${NC}"
}

# Function to get the latest commit SHA for an action
get_action_sha() {
    local action=$1
    local ref=$2
    
    # Extract owner and repo from action
    local owner=$(echo "$action" | cut -d'/' -f1)
    local repo=$(echo "$action" | cut -d'/' -f2)
    
    # Get the commit SHA for the ref
    local sha=$(curl -s "https://api.github.com/repos/$owner/$repo/commits/$ref" | jq -r '.sha' 2>/dev/null)
    
    if [[ -z "$sha" || "$sha" == "null" ]]; then
        print_color "$RED" "Failed to get SHA for $action@$ref"
        return 1
    fi
    
    echo "$sha"
}

# Function to get tag info for a commit
get_tag_for_sha() {
    local action=$1
    local sha=$2
    
    # Extract owner and repo from action
    local owner=$(echo "$action" | cut -d'/' -f1)
    local repo=$(echo "$action" | cut -d'/' -f2)
    
    # Get tags that point to this commit
    local tag=$(curl -s "https://api.github.com/repos/$owner/$repo/git/refs/tags" | \
        jq -r --arg sha "$sha" '.[] | select(.object.sha == $sha) | .ref' | \
        sed 's|refs/tags/||' | head -n1)
    
    echo "$tag"
}

# Common actions and their versions
declare -A COMMON_ACTIONS=(
    ["actions/checkout"]="v4.1.1"
    ["actions/setup-node"]="v4.0.1"
    ["actions/cache"]="v3.3.3"
    ["actions/upload-artifact"]="v4.0.0"
    ["actions/download-artifact"]="v4.1.0"
    ["nick-invision/retry"]="v3.0.0"
    ["dorny/test-reporter"]="v1.7.0"
    ["anthropics/claude-code-base-action"]="beta"
)

# Function to update action references in a file
update_action_in_file() {
    local file=$1
    local updates_made=0
    
    print_color "$BLUE" "Processing: $file"
    
    # Create backup
    cp "$file" "${file}.bak"
    
    # Process each common action
    for action in "${!COMMON_ACTIONS[@]}"; do
        local version="${COMMON_ACTIONS[$action]}"
        
        # Check if action is used in the file
        if grep -q "uses: $action@" "$file"; then
            # Get the SHA for this version
            local sha=$(get_action_sha "$action" "$version")
            
            if [[ -n "$sha" ]]; then
                # Get tag info for comment
                local tag=$(get_tag_for_sha "$action" "$sha")
                local comment=""
                if [[ -n "$tag" ]]; then
                    comment=" # $tag"
                else
                    comment=" # $version"
                fi
                
                # Update the action reference
                sed -i "s|uses: $action@[^ ]*|uses: $action@$sha$comment|g" "$file"
                print_color "$GREEN" "  ✓ Updated $action to $sha$comment"
                ((updates_made++))
            fi
        fi
    done
    
    # Check for any remaining unpinned actions
    local unpinned=$(grep -E "uses: [^/]+/[^@]+@(main|master|v[0-9]+|beta|alpha)" "$file" || true)
    if [[ -n "$unpinned" ]]; then
        print_color "$YELLOW" "  ⚠ Found unpinned actions that need manual review:"
        echo "$unpinned" | while read -r line; do
            echo "    $line"
        done
    fi
    
    if [[ $updates_made -eq 0 ]]; then
        print_color "$YELLOW" "  No updates needed"
        rm "${file}.bak"
    else
        print_color "$GREEN" "  Updated $updates_made action(s)"
    fi
    
    echo ""
}

# Function to find all workflow files
find_workflow_files() {
    find . -path "*.github/workflows/*.yml" -o -path "*.github/workflows/*.yaml" | grep -v ".bak$"
}

# Function to find all action.yml files
find_action_files() {
    find . -name "action.yml" -o -name "action.yaml" | grep -v ".bak$"
}

# Main execution
main() {
    print_color "$BLUE" "=== GitHub Actions Version Pinning Tool ==="
    echo ""
    
    # Check if we're in a git repository
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        print_color "$RED" "Error: Not in a git repository"
        exit 1
    fi
    
    # Check for required tools
    if ! command -v jq &> /dev/null; then
        print_color "$RED" "Error: jq is required but not installed"
        exit 1
    fi
    
    # Find and process workflow files
    print_color "$BLUE" "Searching for workflow files..."
    local workflow_files=$(find_workflow_files)
    local workflow_count=$(echo "$workflow_files" | grep -c "." || echo "0")
    
    if [[ $workflow_count -gt 0 ]]; then
        print_color "$GREEN" "Found $workflow_count workflow file(s)"
        echo ""
        
        echo "$workflow_files" | while read -r file; do
            update_action_in_file "$file"
        done
    else
        print_color "$YELLOW" "No workflow files found"
    fi
    
    # Find and process action files
    print_color "$BLUE" "Searching for composite action files..."
    local action_files=$(find_action_files)
    local action_count=$(echo "$action_files" | grep -c "." || echo "0")
    
    if [[ $action_count -gt 0 ]]; then
        print_color "$GREEN" "Found $action_count action file(s)"
        echo ""
        
        echo "$action_files" | while read -r file; do
            update_action_in_file "$file"
        done
    else
        print_color "$YELLOW" "No action files found"
    fi
    
    # Summary
    print_color "$BLUE" "=== Summary ==="
    print_color "$GREEN" "✓ Processing complete"
    print_color "$YELLOW" "⚠ Review any warnings above and update manually if needed"
    print_color "$BLUE" "📝 Backup files created with .bak extension"
    echo ""
    
    # Show diff command
    print_color "$BLUE" "To review changes, run:"
    echo "  git diff"
    echo ""
    
    # Offer to remove backups
    read -p "Remove backup files? (y/N) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        find . -name "*.yml.bak" -o -name "*.yaml.bak" | xargs rm -f
        print_color "$GREEN" "✓ Backup files removed"
    fi
}

# Run main function
main "$@"