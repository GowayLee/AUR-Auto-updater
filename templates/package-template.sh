#!/bin/bash

# AUR Auto-updater Script for PACKAGE_NAME
# Usage: ./update.sh [--dry-run] [--verbose]

set -euo pipefail

# Load shared utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../shared/common.sh"

# Package configuration - EDIT THESE VALUES
AUR_PACKAGE_NAME="package-name"          # AUR package name
GITHUB_REPO="owner/repo"                # GitHub repository (owner/repo)
COMMITTER_NAME="Auto-updater"           # Git committer name
COMMITTER_EMAIL="your-email@example.com" # Git committer email

# Package-specific GitHub release parsing function
# Override this function in your package script with custom logic
get_package_release_info() {
    local repo="$1"
    log "INFO" "Fetching release information from $repo"

    local api_response
    api_response=$(get_github_release_api_response "$repo")

    # Extract tag_name (version)
    local tag_name
    tag_name=$(echo "$api_response" | grep '"tag_name":' | sed -E 's/.*"v?([^"]+)".*/\1/')

    # Example: Find specific asset and extract download URL
    # Customize this section based on your package's asset naming pattern
    local download_url
    download_url=$(echo "$api_response" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for asset in data['assets']:
    if asset['name'].endswith('.tar.gz'):  # Customize this condition
        print(asset['browser_download_url'])
        break
")

    if [[ -z "$download_url" ]]; then
        log "ERROR" "Could not find required asset in release"
        exit 1
    fi

    # Calculate SHA256 checksum (or use API digest if available)
    local checksum
    checksum=$(get_sha256_checksum "$download_url")

    echo "$tag_name $download_url $checksum"
}

# Package-specific .SRCINFO update function
# Override this function in your package script if custom logic is needed
update_package_srcinfo() {
    local version="$1"
    local checksum="$2"
    local source_url="$3"

    log "INFO" "Updating .SRCINFO"
    run_cmd sed -i "s/^\\tpkgver = .*/\\tpkgver = $version/" .SRCINFO

    local new_source="\tsource = $source_url"
    run_cmd sed -i "/^\\tsource = /c\\\\$new_source" .SRCINFO
    run_cmd sed -i "s/^\\tsha256sums = .*/\\tsha256sums = ('$checksum')/" .SRCINFO
}

# Parse command line arguments
parse_args "$@"

# Check required environment variables
check_env_vars

# Main update process
log "INFO" "Starting AUR auto-update for $AUR_PACKAGE_NAME"

# Setup SSH
setup_ssh

# Clone AUR repository
clone_aur_repo

# Get current version from PKGBUILD
CURRENT_VERSION=$(get_current_version)
log "INFO" "Current version: $CURRENT_VERSION"

# Get package release information
RELEASE_INFO=$(get_package_release_info "$GITHUB_REPO")
LATEST_VERSION=$(echo "$RELEASE_INFO" | awk '{print $1}')
DOWNLOAD_URL=$(echo "$RELEASE_INFO" | awk '{print $2}')
SHASUM=$(echo "$RELEASE_INFO" | awk '{print $3}')

log "INFO" "Latest version: $LATEST_VERSION"
log "INFO" "Download URL: $DOWNLOAD_URL"
log "INFO" "SHA256: $SHASUM"

# Compare versions
if needs_update "$CURRENT_VERSION" "$LATEST_VERSION"; then
    log "INFO" "New version available: $LATEST_VERSION"

    # Update files - customize the source line format as needed
    update_pkgbuild "$LATEST_VERSION" "$SHASUM" "filename::$DOWNLOAD_URL"
    update_package_srcinfo "$LATEST_VERSION" "$SHASUM" "filename::$DOWNLOAD_URL"
    
    # Commit and push changes
    commit_and_push "$LATEST_VERSION"

    log "INFO" "Successfully updated $AUR_PACKAGE_NAME to version $LATEST_VERSION"
else
    log "INFO" "No update needed"
fi

log "INFO" "AUR auto-update completed"