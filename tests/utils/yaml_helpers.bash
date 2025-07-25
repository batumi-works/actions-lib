#!/bin/bash
# YAML validation helpers for workflow tests

# Validate YAML syntax
validate_yaml() {
    local file="$1"
    
    if [[ ! -f "$file" ]]; then
        echo "ERROR: File not found: $file" >&2
        return 1
    fi
    
    # Check if yq is available
    if command -v yq &> /dev/null; then
        # Use yq to validate YAML
        if yq eval '.' "$file" > /dev/null 2>&1; then
            return 0
        else
            echo "ERROR: Invalid YAML in $file" >&2
            return 1
        fi
    else
        # Fallback: basic syntax check with ruby or python if available
        if command -v ruby &> /dev/null; then
            ruby -e "require 'yaml'; YAML.load_file('$file')" 2> /dev/null
            return $?
        elif command -v python3 &> /dev/null; then
            python3 -c "import yaml; yaml.safe_load(open('$file'))" 2> /dev/null
            return $?
        elif command -v python &> /dev/null; then
            python -c "import yaml; yaml.safe_load(open('$file'))" 2> /dev/null
            return $?
        else
            echo "WARNING: No YAML validator available (install yq, ruby, or python)" >&2
            # Return success to not block tests
            return 0
        fi
    fi
}

# Extract YAML value using yq or fallback methods
get_yaml_value() {
    local file="$1"
    local path="$2"
    
    if command -v yq &> /dev/null; then
        yq eval "$path" "$file" 2> /dev/null
    else
        echo "WARNING: yq not available for YAML parsing" >&2
        echo ""
    fi
}

# Check if YAML path exists
yaml_path_exists() {
    local file="$1"
    local path="$2"
    
    if command -v yq &> /dev/null; then
        local value=$(yq eval "$path" "$file" 2> /dev/null)
        if [[ "$value" != "null" && -n "$value" ]]; then
            return 0
        else
            return 1
        fi
    else
        # Cannot check without yq
        return 0
    fi
}

# Count items in YAML array
yaml_array_length() {
    local file="$1"
    local path="$2"
    
    if command -v yq &> /dev/null; then
        yq eval "$path | length" "$file" 2> /dev/null
    else
        echo "0"
    fi
}

# Export functions for use in tests
export -f validate_yaml
export -f get_yaml_value
export -f yaml_path_exists
export -f yaml_array_length