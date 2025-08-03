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

# Optional: Custom download URL pattern
# Override this function in your package script if needed
get_download_url() {
    local version="$1"
    echo "https://github.com/$GITHUB_REPO/releases/download/v${version}/FILE_${version}_ARCH.EXT"
}

# Optional: Custom source line for .SRCINFO
# Override this function in your package script if needed
get_source_line() {
    local version="$1"
    echo "	source = filename::$(get_download_url "$version")"
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

# Get latest GitHub release
LATEST_VERSION=$(get_latest_release "$GITHUB_REPO")
log "INFO" "Latest version: $LATEST_VERSION"

# Get file SHA256
DOWNLOAD_URL=$(get_download_url "$LATEST_VERSION")
SHASUM=$(get_sha256_checksum "$DOWNLOAD_URL")
log "INFO" "SHA256: $SHASUM"

# Compare versions
if needs_update "$CURRENT_VERSION" "$LATEST_VERSION"; then
    log "INFO" "New version available: $LATEST_VERSION"
    
    # Update files
    update_pkgbuild "$LATEST_VERSION" "$SHASUM"
    
    # Custom .SRCINFO update (override if needed)
    update_srcinfo "$LATEST_VERSION" "$SHASUM" "$GITHUB_REPO"
    
    # Commit and push changes
    commit_and_push "$LATEST_VERSION"
    
    log "INFO" "Successfully updated $AUR_PACKAGE_NAME to version $LATEST_VERSION"
else
    log "INFO" "No update needed"
fi

log "INFO" "AUR auto-update completed"