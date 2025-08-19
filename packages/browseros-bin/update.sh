#!/bin/bash

# AUR Auto-updater Script for browseros-bin
# Usage: ./update.sh [--dry-run] [--verbose]

set -euo pipefail

# Load shared utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../shared/common.sh"

# Package configuration
AUR_PACKAGE_NAME="browseros-bin"
GITHUB_REPO="browseros-ai/BrowserOS"
COMMITTER_NAME="Auto-updater"
COMMITTER_EMAIL="lihaoyuan0506@gmail.com"

# BrowserOS-specific GitHub release parsing function
get_browseros_release_info() {
    local repo="$1"
    log "INFO" "Fetching BrowserOS release information from $repo"

    local api_response
    api_response=$(get_github_release_api_response "$repo")

    # Extract tag_name (version)
    local tag_name
    tag_name=$(echo "$api_response" | grep '"tag_name":' | sed -E 's/.*"v?([^"]+)".*/\1/')

    # Find AppImage asset and extract download URL and digest
    local appimage_info
    appimage_info=$(echo "$api_response" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for asset in data['assets']:
    if asset['name'].endswith('_x64.AppImage'):
        print(asset['browser_download_url'], asset['digest'].split(':')[1])
        break
")

    if [[ -z "$appimage_info" ]]; then
        log "ERROR" "Could not find AppImage asset in release"
        exit 1
    fi

    local download_url=$(echo "$appimage_info" | awk '{print $1}')
    local digest=$(echo "$appimage_info" | awk '{print $2}')

    echo "$tag_name $download_url $digest"
}

# BrowserOS-specific .SRCINFO update function
update_brosweros_srcinfo() {
    local version="$1"
    local checksum="$2"
    local source_url="$3"

    log "INFO" "Updating .SRCINFO"
    run_cmd sed -i "s/^\tpkgver = .*/\tpkgver = $version/" .SRCINFO

    local new_source="	source = $source_url"
    run_cmd sed -i "/^\tsource = /c\\$new_source" .SRCINFO
    run_cmd sed -i "s/^\tsha256sums = .*/\tsha256sums = ('$checksum')/" .SRCINFO
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

# Get BrowserOS release information
RELEASE_INFO=$(get_browseros_release_info "$GITHUB_REPO")
LATEST_VERSION=$(echo "$RELEASE_INFO" | awk '{print $1}')
DOWNLOAD_URL=$(echo "$RELEASE_INFO" | awk '{print $2}')
SHASUM=$(echo "$RELEASE_INFO" | awk '{print $3}')

log "INFO" "Latest version: $LATEST_VERSION"
log "INFO" "Download URL: $DOWNLOAD_URL"
log "INFO" "SHA256: $SHASUM"

# Compare versions
if needs_update "$CURRENT_VERSION" "$LATEST_VERSION"; then
    log "INFO" "New version available: $LATEST_VERSION"

    # Update files
    update_pkgbuild "$LATEST_VERSION" "$SHASUM" "browseros.AppImage::$DOWNLOAD_URL"
    update_brosweros_srcinfo "$LATEST_VERSION" "$SHASUM" "browseros.AppImage::$DOWNLOAD_URL"
    # Commit and push changes
    commit_and_push "$LATEST_VERSION"

    log "INFO" "Successfully updated $AUR_PACKAGE_NAME to version $LATEST_VERSION"
else
    log "INFO" "No update needed"
fi

log "INFO" "AUR auto-update completed"
