#!/bin/bash

# Function to get value from environment or base file
get_value() {
    local var=$1
    local env_file=$2
    # First try environment variable (GitLab CI)
    if [ -n "${!var}" ]; then
        echo "${!var}"
    # Then try environment-specific file
    elif [ -f "$env_file" ]; then
        grep "^${var}=" "$env_file" | cut -d'=' -f2-
    fi
}

# Function to validate required variables
validate_variables() {
    local env_file=$1
    
    # Get all variables from the environment file
    local required_vars=()
    while IFS= read -r line || [ -n "$line" ]; do
        # Skip comments and empty lines
        [[ "$line" =~ ^#.*$ ]] && continue
        [[ -z "$line" ]] && continue
        
        # Extract variable name
        if [[ "$line" =~ ^([A-Z_]+)= ]]; then
            required_vars+=("${BASH_REMATCH[1]}")
        fi
    done < "$env_file"
    
    local missing_vars=()
    
    for var in "${required_vars[@]}"; do
        if ! grep -q "^${var}=" "$env_file" && [ -z "${!var}" ]; then
            missing_vars+=("$var")
        fi
    done
    
    if [ ${#missing_vars[@]} -ne 0 ]; then
        echo "Error: Missing required variables in $env_file or environment:"
        printf '%s\n' "${missing_vars[@]}"
        exit 1
    fi
}

# Determine environment file based on branch
if [ -z "$CI_COMMIT_REF_NAME" ]; then
    echo "Warning: CI_COMMIT_REF_NAME is not set, defaulting to 'dev'"
    CI_COMMIT_REF_NAME="dev"
fi

ENV_FILE="env.${CI_COMMIT_REF_NAME}"

# Check if environment file exists
if [ ! -f "$ENV_FILE" ]; then
    echo "Error: Environment file $ENV_FILE not found in current directory"
    echo "Current directory: $(pwd)"
    echo "Available environment files:"
    ls -1 env.* 2>/dev/null || echo "No environment files found"
    exit 1
fi

echo "Using environment file: $ENV_FILE"

# Validate required variables
validate_variables "$ENV_FILE"

# Create .env file
{
    echo "# Generated .env file for ${CI_COMMIT_REF_NAME} environment"
    echo "# Generated at: $(date)"
    echo "# Base file: $ENV_FILE"
    echo
    
    # Process each section from the environment file
    while IFS= read -r line || [ -n "$line" ]; do
        # Skip empty lines
        [[ -z "$line" ]] && continue
        
        # If it's a comment, keep it
        if [[ "$line" =~ ^#.*$ ]]; then
            echo "$line"
            continue
        fi
        
        # Process variable
        if [[ "$line" =~ ^([A-Za-z0-9_]+)=(.*)$ ]]; then
            var="${BASH_REMATCH[1]}"
            value=$(get_value "$var" "$ENV_FILE")
            if [ -n "$value" ]; then
                echo "${var}=${value}"
            fi
        fi
    done < "$ENV_FILE"
} > .env

echo "Generated .env file from $ENV_FILE"
echo "GitLab CI variables will override values from $ENV_FILE when present" 