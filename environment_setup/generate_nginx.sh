#!/bin/bash

# Generate nginx configuration from template
# This script replaces placeholders in nginx.conf.template with actual values

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -p, --project PROJECT_NAME    Project name (default: CI_PROJECT_NAME)"
    echo "  -g, --group GROUP_NAME        Group name (default: CI_PROJECT_NAMESPACE)"
    echo "  -b, --backend-port PORT       Backend port (default: 8000 or from .env)"
    echo "  -e, --environment ENV         Environment (dev/staging/master)"
    echo "  -o, --output FILE             Output file (default: nginx.conf)"
    echo "  -h, --help                    Show this help message"
    echo ""
    echo "Example:"
    echo "  $0 -p my-app -g my-group -b 8000 -e dev"
}

# Default values
PROJECT_NAME="${CI_PROJECT_NAME:-}"
GROUP_NAME="${CI_PROJECT_NAMESPACE:-}"
BACKEND_PORT="${BACKEND_PORT:-}"
ENVIRONMENT="${CI_COMMIT_REF_NAME:-dev}"
OUTPUT_FILE="nginx.conf"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--project)
            PROJECT_NAME="$2"
            shift 2
            ;;
        -g|--group)
            GROUP_NAME="$2"
            shift 2
            ;;
        -b|--backend-port)
            BACKEND_PORT="$2"
            shift 2
            ;;
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Fallback logic for BACKEND_PORT
if [ -z "$BACKEND_PORT" ]; then
    if [ -f .env ]; then
        print_info "Attempting to read BACKEND_PORT from .env..."
        BACKEND_PORT=$(grep '^BACKEND_PORT=' .env | cut -d '=' -f2)
        if [ -z "$BACKEND_PORT" ]; then
            print_warning "BACKEND_PORT not found in .env, using default 8000"
            BACKEND_PORT=8000
        fi
    else
        print_warning ".env file not found, using default BACKEND_PORT=8000"
        BACKEND_PORT=8000
    fi
fi

# Validate required inputs
if [ -z "$PROJECT_NAME" ]; then
    print_error "Project name is required"
    show_usage
    exit 1
fi

if [ -z "$GROUP_NAME" ]; then
    print_error "Group name is required"
    show_usage
    exit 1
fi

# Determine domain based on environment
case $ENVIRONMENT in
    dev)
        DOMAIN="${PROJECT_NAME}.dev.sofmen.com"
        ;;
    staging)
        DOMAIN="${PROJECT_NAME}.stg.sofmen.com"
        ;;
    master|main)
        DOMAIN="${PROJECT_NAME}.sofmen.com"
        ;;
    *)
        DOMAIN="${PROJECT_NAME}.${ENVIRONMENT}.sofmen.com"
        ;;
esac

# Map branch name to short environment code
case "$CI_COMMIT_REF_NAME" in
  dev)
    ENV_SHORT="dev"
    ;;
  staging)
    ENV_SHORT="stg"
    ;;
  prod|production|main|master)
    ENV_SHORT="prod"
    ;;
  *)
    ENV_SHORT="$CI_COMMIT_REF_NAME"
    ;;
esac

export ENV_SHORT
echo "[DEBUG] ENV_SHORT is: $ENV_SHORT"

# Logging
print_info "Generating nginx configuration..."
print_info "Project: $PROJECT_NAME"
print_info "Group: $GROUP_NAME"
print_info "Environment: $ENVIRONMENT"
print_info "Domain: $DOMAIN"
print_info "Backend Port: $BACKEND_PORT"
print_info "Output: $OUTPUT_FILE"

# Check if template exists
if [ ! -f "nginx.conf.template" ]; then
    print_error "nginx.conf.template not found"
    exit 1
fi

# Replace placeholders in template
print_info "Replacing placeholders in template..."

sed \
    -e "s/\${PROJECT_NAME}/$PROJECT_NAME/g" \
    -e "s/\${GROUP_NAME}/$GROUP_NAME/g" \
    -e "s/\${BACKEND_PORT}/$BACKEND_PORT/g" \
    -e "s/\${DOMAIN}/$DOMAIN/g" \
    -e "s/\${ENVIRONMENT}/$ENVIRONMENT/g" \
    -e "s/\${ENV_SHORT}/$ENV_SHORT/g" \
    nginx.conf.template > "$OUTPUT_FILE"

# Verify result
if [ -f "$OUTPUT_FILE" ]; then
    print_success "Nginx configuration generated successfully!"
    print_info "Generated file: $OUTPUT_FILE"
    print_info "Preview of generated configuration:"
    echo "----------------------------------------"
    head -10 "$OUTPUT_FILE"
    echo "----------------------------------------"
else
    print_error "Failed to generate nginx configuration"
    exit 1
fi

echo "[DEBUG] Using BACKEND_PORT: $BACKEND_PORT"
print_success "Nginx configuration generation completed!"