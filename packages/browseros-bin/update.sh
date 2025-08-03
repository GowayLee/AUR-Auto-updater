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

# Get AppImage SHA256
DOWNLOAD_URL="https://github.com/$GITHUB_REPO/releases/download/v${LATEST_VERSION}/BrowserOS_v${LATEST_VERSION}_x64.AppImage"
SHASUM=$(get_sha256_checksum "$DOWNLOAD_URL")
log "INFO" "SHA256: $SHASUM"

# Compare versions
if needs_update "$CURRENT_VERSION" "$LATEST_VERSION"; then
    log "INFO" "New version available: $LATEST_VERSION"

    # Update files
    update_pkgbuild "$LATEST_VERSION" "$SHASUM"
    update_srcinfo "$LATEST_VERSION" "$SHASUM" "$GITHUB_REPO"

    # Commit and push changes
    commit_and_push "$LATEST_VERSION"

    log "INFO" "Successfully updated $AUR_PACKAGE_NAME to version $LATEST_VERSION"
else
    log "INFO" "No update needed"
fi

log "INFO" "AUR auto-update completed"
