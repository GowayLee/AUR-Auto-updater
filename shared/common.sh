#!/bin/bash

# Common utilities for AUR auto-updaters
# This file should be sourced by package-specific update scripts

# Global variables
DRY_RUN=false
VERBOSE=false

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --help)
                echo "Usage: $0 [--dry-run] [--verbose]"
                echo "  --dry-run  Show what would be done without making changes"
                echo "  --verbose  Enable verbose output"
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                exit 1
                ;;
        esac
    done
}

# Logging function
log() {
    if [[ "$VERBOSE" == "true" ]] || [[ "$1" == "ERROR" ]]; then
        echo "[$1] $2" >&2
    fi
}

# Function to execute commands with dry-run support
run_cmd() {
    if [[ "$DRY_RUN" == "true" ]]; then
        log "DRY-RUN" "Would execute: $*"
        return 0
    fi

    if [[ "$VERBOSE" == "true" ]]; then
        log "EXEC" "Running: $*"
    fi

    "$@"
}

# Check required environment variables
check_env_vars() {
    if [[ -z "${AUR_SSH_PRIVATE_KEY:-}" ]]; then
        log "ERROR" "AUR_SSH_PRIVATE_KEY environment variable is required"
        exit 1
    fi
}

# Setup SSH for AUR access
setup_ssh() {
    log "INFO" "Setting up SSH access to AUR"
    run_cmd mkdir -p ~/.ssh

    # Use a unique key name to avoid conflicts
    local unique_key_name="aur_auto_updater_${USER}_$(date +%s)"
    local key_file="$HOME/.ssh/${unique_key_name}"

    echo "$AUR_SSH_PRIVATE_KEY" > "$key_file"
    run_cmd chmod 600 "$key_file"

    # Create a backup of existing config if it exists
    if [[ -f ~/.ssh/config ]]; then
        cp ~/.ssh/config ~/.ssh/config.bak_"$(date +%s)"
    fi

    # Add our configuration with unique markers for safe removal
    cat <<EOT >> ~/.ssh/config
# AUR Auto-updater configuration - ${unique_key_name}
Host aur.archlinux.org
  IdentityFile ${key_file}
  User aur
  StrictHostKeyChecking no
# End AUR Auto-updater configuration
EOT

    # Store the key file path and config markers for cleanup
    export AUR_AUTO_UPDATER_KEY_FILE="$key_file"
    export AUR_AUTO_UPDATER_CONFIG_MARKER="AUR Auto-updater configuration - ${unique_key_name}"
}

# Clone AUR repository
clone_aur_repo() {
    log "INFO" "Cloning AUR repository"
    local clone_dir="${AUR_PACKAGE_NAME}_aur_clone"
    run_cmd git clone "ssh://aur@aur.archlinux.org/$AUR_PACKAGE_NAME.git" "$clone_dir"
    cd "$clone_dir"
}

# Get current version from PKGBUILD
get_current_version() {
    log "INFO" "Reading current version from PKGBUILD"
    grep -m1 '^pkgver=' PKGBUILD | cut -d= -f2
}

# Get GitHub release API response
get_github_release_api_response() {
    local repo="$1"
    log "INFO" "Fetching GitHub release API response from $repo"
    curl -s "https://api.github.com/repos/$repo/releases/latest"
}

# Get latest GitHub release
get_latest_release_tag_name() {
    local repo="$1"
    log "INFO" "Fetching latest GitHub release from $repo"
    curl -s "https://api.github.com/repos/$repo/releases/latest" |
        grep '"tag_name":' |
        sed -E 's/.*"v?([^"]+)".*/\1/'
}

# Get SHA256 checksum for a URL
get_sha256_checksum() {
    local url="$1"
    log "INFO" "Calculating SHA256 checksum"
    curl -sL "$url" | sha256sum | awk '{print $1}'
}

# Check if update is needed
needs_update() {
    local current="$1"
    local latest="$2"

    log "INFO" "Comparing versions"
    if [ "$current" != "$latest" ]; then
        return 0  # Update needed
    else
        return 1  # No update needed
    fi
}

# Update PKGBUILD with new version, checksum, and download URL
update_pkgbuild() {
    local version="$1"
    local checksum="$2"
    local source_url="$3"

    log "INFO" "Updating PKGBUILD"
    run_cmd sed -i "s/^pkgver=.*/pkgver=$version/" PKGBUILD
    run_cmd sed -i "s/^sha256sums=.*/sha256sums=('$checksum')/" PKGBUILD
    if [[ -n "$source_url" ]]; then
        run_cmd sed -i "s|^source=.*|source=(\"$source_url\")|" PKGBUILD
    fi
}

# Update .SRCINFO with new version and checksum
update_srcinfo() {
    local version="$1"
    local checksum="$2"

    log "INFO" "Updating .SRCINFO"
    run_cmd sed -i "s/^\tpkgver = .*/\tpkgver = $version/" .SRCINFO
    run_cmd sed -i "s/^\tsha256sums = .*/\tsha256sums = ('$checksum')/" .SRCINFO
}

# Commit and push changes
commit_and_push() {
    local version="$1"

    log "INFO" "Committing and pushing changes"
    run_cmd git config user.name "$COMMITTER_NAME"
    run_cmd git config user.email "$COMMITTER_EMAIL"
    run_cmd git add PKGBUILD .SRCINFO
    run_cmd git commit -m "chore: update to v$version"
    run_cmd git push
}

# Cleanup SSH configuration
cleanup_ssh() {
    log "INFO" "Cleaning up SSH configuration"

    # Remove the temporary SSH key file
    if [[ -n "${AUR_AUTO_UPDATER_KEY_FILE:-}" ]] && [[ -f "$AUR_AUTO_UPDATER_KEY_FILE" ]]; then
        run_cmd rm -f "$AUR_AUTO_UPDATER_KEY_FILE"
    fi

    # Remove our configuration from SSH config
    if [[ -n "${AUR_AUTO_UPDATER_CONFIG_MARKER:-}" ]] && [[ -f ~/.ssh/config ]]; then
        # Create a temporary file without our configuration
        local temp_config=$(mktemp)
        local in_config_block=false

        while IFS= read -r line; do
            if [[ "$line" == "# AUR Auto-updater configuration -"* ]]; then
                in_config_block=true
                continue
            elif [[ "$line" == "# End AUR Auto-updater configuration" ]]; then
                in_config_block=false
                continue
            fi

            if [[ "$in_config_block" == "false" ]]; then
                echo "$line" >> "$temp_config"
            fi
        done < ~/.ssh/config

        # Replace the original config
        run_cmd mv "$temp_config" ~/.ssh/config
        run_cmd chmod 600 ~/.ssh/config
    fi

    # Remove backup files created by our setup
    run_cmd rm -f ~/.ssh/config.bak_* 2>/dev/null || true

    # Unset environment variables
    unset AUR_AUTO_UPDATER_KEY_FILE
    unset AUR_AUTO_UPDATER_CONFIG_MARKER
}
