#!/bin/bash

# AUR Auto-updater Script for hitpag
# Usage: ./update.sh [--dry-run] [--verbose]

set -euo pipefail

# Load shared utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../shared/common.sh"

# Package configuration
AUR_PACKAGE_NAME="hitpag"
GITHUB_REPO="Hitmux/hitpag"
COMMITTER_NAME="Auto-updater"
COMMITTER_EMAIL="lihaoyuan0506@gmail.com"

# Hitpag-specific GitHub release parsing function
get_hitpag_release_info() {
    local repo="$1"
    log "INFO" "Fetching hitpag release information from $repo"

    local api_response
    api_response=$(get_github_release_api_response "$repo")

    # Extract tag_name and tarball_url using Python JSON parsing
    local release_info
    release_info=$(echo "$api_response" | python3 -c "
import sys, json
data = json.load(sys.stdin)
tag_name = data.get('tag_name', '').lstrip('v')
tarball_url = data.get('tarball_url', '')
if tag_name and tarball_url:
    print(tag_name, tarball_url)
else:
    print('ERROR: Missing required fields')
")

    if [[ "$release_info" == *"ERROR: Missing required fields"* ]] || [[ -z "$release_info" ]]; then
        log "ERROR" "Could not extract release information from API response"
        exit 1
    fi

    local tag_name=$(echo "$release_info" | awk '{print $1}')
    local tarball_url=$(echo "$release_info" | awk '{print $2}')

    log "INFO" "Found release: $tag_name"
    log "INFO" "Tarball URL: $tarball_url"

    # For hitpag, checksum is SKIP since we compile from source
    echo "$tag_name $tarball_url SKIP"
}

# Hitpag-specific .SRCINFO update function
update_hitpag_srcinfo() {
    local version="$1"
    local checksum="$2"
    local source_url="$3"

    log "INFO" "Updating .SRCINFO"
    run_cmd sed -i "s/^\tpkgver = .*/\tpkgver = $version/" .SRCINFO

    local new_source="\tsource = $source_url"
    run_cmd sed -i "/^\tsource = /c\\\\$new_source" .SRCINFO
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

# Get hitpag release information
RELEASE_INFO=$(get_hitpag_release_info "$GITHUB_REPO")
LATEST_VERSION=$(echo "$RELEASE_INFO" | awk '{print $1}')
TARBALL_URL=$(echo "$RELEASE_INFO" | awk '{print $2}')
SHASUM=$(echo "$RELEASE_INFO" | awk '{print $3}')

log "INFO" "Latest version: $LATEST_VERSION"
log "INFO" "Tarball URL: $TARBALL_URL"
log "INFO" "SHA256: $SHASUM"

# Compare versions
if needs_update "$CURRENT_VERSION" "$LATEST_VERSION"; then
    log "INFO" "New version available: $LATEST_VERSION"

    # Update files - use hitpag-<version>.tar.gz::<tarball_url> format
    update_pkgbuild "$LATEST_VERSION" "$SHASUM" "hitpag-$LATEST_VERSION.tar.gz::$TARBALL_URL"
    update_hitpag_srcinfo "$LATEST_VERSION" "$SHASUM" "hitpag-$LATEST_VERSION.tar.gz::$TARBALL_URL"

    # Commit and push changes
    commit_and_push "$LATEST_VERSION"

    log "INFO" "Successfully updated $AUR_PACKAGE_NAME to version $LATEST_VERSION"
else
    log "INFO" "No update needed"
fi

log "INFO" "AUR auto-update completed"

# Cleanup SSH configuration
cleanup_ssh
