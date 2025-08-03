#!/bin/bash

# Script to create a new AUR package updater
# Usage: ./add-package.sh <package-name> <github-repo> [email]

set -euo pipefail

if [[ $# -lt 2 ]]; then
    echo "Usage: $0 <package-name> <github-repo> [email]"
    echo "Example: $0 my-package owner/repo user@example.com"
    exit 1
fi

PACKAGE_NAME="$1"
GITHUB_REPO="$2"
EMAIL="${3:-lihaoyuan0506@gmail.com}"

PACKAGE_DIR="packages/$PACKAGE_NAME"

# Check if package already exists
if [[ -d "$PACKAGE_DIR" ]]; then
    echo "Error: Package '$PACKAGE_NAME' already exists"
    exit 1
fi

# Create package directory
echo "Creating package directory: $PACKAGE_DIR"
mkdir -p "$PACKAGE_DIR"

# Copy template
echo "Copying template..."
cp templates/package-template.sh "$PACKAGE_DIR/update.sh"

# Replace placeholders
echo "Configuring package..."
sed -i "s/PACKAGE_NAME/$PACKAGE_NAME/g" "$PACKAGE_DIR/update.sh"
sed -i "s/owner\/repo/$GITHUB_REPO/g" "$PACKAGE_DIR/update.sh"
sed -i "s/your-email@example.com/$EMAIL/g" "$PACKAGE_DIR/update.sh"

# Make executable
chmod +x "$PACKAGE_DIR/update.sh"

# Create GitHub workflow
echo "Creating GitHub workflow..."
cat > ".github/workflows/$PACKAGE_NAME.yml" << EOF
name: Auto-updater 4 AUR $PACKAGE_NAME

on:
  schedule:
    - cron: "0 0 * * *"
  workflow_dispatch:

jobs:
  update-aur:
    runs-on: ubuntu-latest
    steps:
      - name: 📥 Checkout repository
        uses: actions/checkout@v4

      - name: 🚀 Run AUR updater script
        env:
          AUR_SSH_PRIVATE_KEY: \${{ secrets.AUR_SSH_PRIVATE_KEY }}
        run: |
          chmod +x ./packages/$PACKAGE_NAME/update.sh
          ./packages/$PACKAGE_NAME/update.sh --verbose
EOF

echo "✅ Package '$PACKAGE_NAME' created successfully!"
echo ""
echo "Next steps:"
echo "1. Edit '$PACKAGE_DIR/update.sh' to customize the download URL pattern if needed"
echo "2. Test the script: cd $PACKAGE_DIR && ./update.sh --dry-run --verbose"
echo "3. Commit the changes: git add packages/$PACKAGE_NAME .github/workflows/$PACKAGE_NAME.yml"
echo "4. Push to trigger the first run"