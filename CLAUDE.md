# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This repository contains automated updaters for AUR (Arch User Repository) packages. It's designed to automatically check for new releases of upstream projects and update the corresponding AUR packages.

## Architecture

The repository uses GitHub Actions workflows to automate the update process:

1. **Scheduled Checks**: Workflows run daily (cron: "0 0 * * *") to check for new releases
2. **Manual Triggers**: Workflows can be manually triggered via workflow_dispatch
3. **SSH-based AUR Access**: Uses SSH keys to securely push updates to AUR repositories

## Current Packages

- **browseros-bin**: Auto-updater for the BrowserOS AppImage package
  - Upstream: https://github.com/browseros-ai/BrowserOS
  - AUR Package: https://aur.archlinux.org/packages/browseros-bin
  - Workflow: `.github/workflows/browseros-bin.yml`

## Workflow Process

Each updater follows this pattern:

1. **Setup SSH**: Configure SSH access to AUR using stored secrets
2. **Clone AUR Repo**: Pull the existing AUR package repository
3. **Check Latest Release**: Query GitHub API for the latest release version
4. **Compare Versions**: Compare current AUR version with latest upstream version
5. **Update Files**: If new version exists, update PKGBUILD and .SRCINFO files
6. **Push Changes**: Commit and push updates to AUR repository

## Required Secrets

Each workflow requires these GitHub repository secrets:
- `AUR_SSH_PRIVATE_KEY`: SSH private key for AUR access

## File Structure

```
.github/workflows/          # GitHub Actions workflows
  browseros-bin.yml        # Auto-updater for browseros-bin package
README.md                  # Package documentation
```

## Development Notes

- Workflows use version comparison with `sort -V` for proper semantic version handling
- SHA256 checksums are calculated for downloaded files to ensure integrity
- Updates are committed with "Auto-updater" as the committer
- The workflow handles both the PKGBUILD and .SRCINFO file updates simultaneously

## Adding New Packages

To add a new AUR package auto-updater:

1. Create a new workflow file in `.github/workflows/`
2. Follow the existing pattern from `browseros-bin.yml`
3. Update the upstream repository URL and package names
4. Ensure the AUR_SSH_PRIVATE_KEY secret is available
5. Test the workflow manually before enabling scheduled runs