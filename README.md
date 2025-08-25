# AUR Auto-updater Collection

This repository contains automated updaters for multiple AUR (Arch User Repository) packages, designed for personal use with GitHub Actions automation.

## Directory Structure

```
├── packages/           # Individual package updaters
│   ├── browseros-bin/  # browseros-bin package
│   │   └── update.sh   # Update script
│   ├── ccline-bin/     # ccline-bin package
│   │   └── update.sh   # Update script
│   └── hitpag/         # hitpag package
│       └── update.sh   # Update script
├── scripts/           # Utility scripts
│   └── add-package.sh # Script to add new packages
├── shared/            # Shared utilities
│   └── common.sh      # Common functions for all updaters
├── templates/         # Package templates
│   └── package-template.sh # Template for new packages
└── .github/workflows/ # GitHub Actions workflows
    ├── browseros-bin.yml # Automated update workflow
    ├── ccline-bin.yml    # Automated update workflow
    └── hitpag.yml       # Automated update workflow
```

## Adding a New Package

Use the `add-package.sh` script to create a new AUR package updater:

```bash
./scripts/add-package.sh <package-name> <github-repo> [email]
```

Example:

```bash
./scripts/add-package.sh my-app user/repo user@example.com
```

## Manual Testing

Test any package updater with dry-run mode:

```bash
cd packages/<package-name>
./update.sh --dry-run --verbose
```

## Makefile Usage

The repository includes a comprehensive Makefile for easy management:

```bash
# Show available commands
make help

# Add a new package
make add-package PACKAGE=my-app REPO=user/repo EMAIL=user@example.com

# Test a specific package
make test-dry-run PACKAGE=browseros-bin
make test-dry-run PACKAGE=ccline-bin
make test-dry-run PACKAGE=hitpag

# Test all packages
make test-all

# Lint shell scripts
make lint

# Clean temporary files
make clean

# List all packages
make list-packages

# Validate package configurations
make validate
```

## Architecture

Each package updater follows this pattern:

1. **Shared Utilities**: Common functions in `shared/common.sh`
2. **Package Configuration**: Per-package settings in `packages/<name>/update.sh`
3. **GitHub Actions**: Automated workflows in `.github/workflows/<name>.yml`

### GitHub Actions Automation

The system uses GitHub Actions to:

- **Daily Checks**: Automatically check for new releases (cron: "0 0 \* \* \*")
- **Manual Triggers**: Allow manual execution via workflow_dispatch
- **SSH-based AUR Access**: Securely push updates using stored SSH keys
- **Version Comparison**: Compare current AUR version with latest upstream releases
- **Automated Updates**: Update PKGBUILD and .SRCINFO files when new versions are found

## Required Secrets

All workflows require the `AUR_SSH_PRIVATE_KEY` GitHub repository secret for AUR access.

## Current Packages

- **browseros-bin**: Auto-updater for BrowserOS AppImage
  - Upstream: https://github.com/browseros-ai/BrowserOS
  - AUR: https://aur.archlinux.org/packages/browseros-bin

- **ccline-bin**: Auto-updater for CCometixLine binary package
  - Upstream: https://github.com/Haleclipse/CCometixLine
  - AUR: https://aur.archlinux.org/packages/ccline-bin

- **hitpag**: Auto-updater for Hitmux hitpag source package
  - Upstream: https://github.com/Hitmux/hitpag
  - AUR: https://aur.archlinux.org/packages/hitpag
