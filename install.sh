#!/bin/bash

VERSION=$1

# Color Definitions
readonly RED='\033[31m'
readonly YELLOW='\033[33m'
readonly GREEN='\033[32m'
readonly PURPLE='\033[36m'
readonly RESET='\033[0m'

# Consts
readonly FORBIDDEN_VERSIONS=("1.0.0")

# Function to print INFO messages
log_info() {
    echo -e "${YELLOW}[INFO] $1${RESET}"
}

# Function to print SUCCESS messages
log_success() {
    echo -e "${GREEN}[SUCCESS] $1${RESET}"
}

# Function to print ERROR messages
log_error() {
    echo -e "${RED}[ERROR] $1${RESET}"
}

# Function to print WARNING messages
log_warning() {
    echo -e "${PURPLE}[WARNING] $1${RESET}"
}

# Function to validate input version number format
validate_version() {
    if [[ $1 =~ ^[v]?[0-9]+(\.[0-9]+)*$ ]]; then
        return 0 # Valid version format
    else
        return 1 # Invalid version format
    fi
}

is_forbidden_version() {
    local version=${1#v}
    for forbidden_version in "${FORBIDDEN_VERSIONS[@]}"; do
        if [[ "$version" == "$forbidden_version" ]]; then
            return 0
        fi
    done
    return 1
}

check_github_version() {
    local repo_owner="$1"
    local repo_name="$2"
    local version="$3"
    
    local tags=$(curl -sL "https://api.github.com/repos/${repo_owner}/${repo_name}/tags" | grep -o '"name": "[^"]*"' | cut -d'"' -f4)
    for tag in $tags; do
        if [[ "$tag" == "$version" ]]; then
            return 0 # Version exists on GitHub
        fi
    done
    return 1 # Version does not exist on GitHub
}

check_dependencies() {
    for cmd in curl sed; do
        if ! command -v $cmd &>/dev/null; then
            log_error "$cmd is not installed. Please install it and try again."
            return 1
        fi
    done
    return 0
}

main() {
    if ! check_dependencies; then
        exit 1
    fi
    
    # Check if a version is provided, if not set a default version (latest)
    if [ -z "$VERSION" ]; then
        log_info "No version provided. Installing the latest release."
        VERSION=$(curl -Ls "https://api.github.com/repos/StafLoker/ddns-porkbun-script/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    else
        if validate_version "$VERSION"; then
            if is_forbidden_version "$VERSION"; then
                log_error "Version $version is forbidden."
                exit 2
            fi
            if check_github_version "StafLoker" "ddns-porkbun-script" "${VERSION}"; then
                log_success "Version $VERSION exists on GitHub. Proceeding with installation."
            else
                log_error "Version $VERSION does not exist on GitHub. Exiting."
                exit 3
            fi
        else
            log_error "Invalid version format. Please provide a valid version number. Exiting."
            exit 4
        fi
    fi

    # Truncate version to major.minor (e.g., from v1.0.1 to v1.0)
    VERSION_TRUNCATED="${VERSION%.*}"

   bash <(curl -Ls "https://raw.githubusercontent.com/StafLoker/ddns-porkbun-script/main/install_version/$VERSION_TRUNCATED/install.sh") "$VERSION"
}

main
