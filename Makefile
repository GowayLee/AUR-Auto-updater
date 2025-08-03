# Makefile for AUR Auto-updater Collection 🚀

# Variables
SHELL := /bin/bash
.PHONY: help add-package test-dry-run test-all lint clean setup update

# Default target
help:
	@echo "📋 Available targets:"
	@echo "  help          - Show this help message"
	@echo "  add-package   - Add a new AUR package (usage: make add-package PACKAGE=<name> REPO=<owner/repo> [EMAIL=<email>])"
	@echo "  test-dry-run  - Test package update in dry-run mode (usage: make test-dry-run PACKAGE=<name>)"
	@echo "  test-all      - Test all packages in dry-run mode"
	@echo "  lint          - Lint shell scripts"
	@echo "  clean         - Clean temporary files"
	@echo "  setup         - Setup development environment"
	@echo "  list-packages - List all available packages"
	@echo "  validate      - Validate all package configurations"
	@echo "  update        - Update AUR package (usage: make update PACKAGE=<name> SSH_KEY=<path/to/key>)"

# Add new package
add-package:
ifndef PACKAGE
	$(error PACKAGE is required. Usage: make add-package PACKAGE=<name> REPO=<owner/repo> [EMAIL=<email>])
endif
ifndef REPO
	$(error REPO is required. Usage: make add-package PACKAGE=<name> REPO=<owner/repo> [EMAIL=<email>])
endif
	@echo "📦 Adding new package: $(PACKAGE)"
	@echo "🔗 GitHub repository: $(REPO)"
	@echo "📧 Email: $(EMAIL)"
	@./scripts/add-package.sh $(PACKAGE) $(REPO) $(EMAIL)

# Test specific package in dry-run mode
test-dry-run:
ifndef PACKAGE
	$(error PACKAGE is required. Usage: make test-dry-run PACKAGE=<name>)
endif
	@echo "🧪 Testing package: $(PACKAGE) in dry-run mode"
	@cd packages/$(PACKAGE) && ./update.sh --dry-run --verbose

# Test all packages in dry-run mode
test-all:
	@echo "🧪 Testing all packages in dry-run mode..."
	@for pkg in packages/*; do \
		if [ -f "$$pkg/update.sh" ]; then \
			echo "Testing $$(basename $$pkg)..."; \
			cd "$$pkg" && ./update.sh --dry-run --verbose; \
			cd ../..; \
		fi; \
	done

# Lint shell scripts
lint:
	@echo "🔍 Linting shell scripts..."
	@command -v shellcheck >/dev/null 2>&1 || { echo "Installing shellcheck..."; sudo pacman -S shellcheck; }
	@find . -name "*.sh" -exec shellcheck {} \;
	@echo "✅ Linting complete."

# Clean temporary files and cloned repositories
clean:
	@echo "🧹 Cleaning temporary files and cloned repositories..."
	@find . -name "*.tmp" -delete
	@find . -name "*.log" -delete
	@find . -name "*~" -delete
	@find . -name ".DS_Store" -delete
	@find . -name "Thumbs.db" -delete
	@echo "🗑️  Cleaning up cloned AUR repositories..."
	@# Remove cloned AUR repositories with consistent naming pattern
	@find . -maxdepth 3 -type d -name "*_aur_clone" -exec rm -rf {} \; 2>/dev/null || true
	@echo "🗑️  Cleaning up SSH configuration..."
	@# Remove only our auto-generated SSH keys
	@find ~/.ssh -name "aur_auto_updater_*" -type f -delete 2>/dev/null || true
	@# Remove only our configuration blocks with proper markers
	@if [ -f ~/.ssh/config ]; then \
		tmp_config=$$(mktemp); \
		in_config_block=false; \
		while IFS= read -r line; do \
			if echo "$$line" | grep -q "^# AUR Auto-updater configuration -"; then \
				in_config_block=true; \
				continue; \
			elif echo "$$line" | grep -q "^# End AUR Auto-updater configuration"; then \
				in_config_block=false; \
				continue; \
			fi; \
			if [ "$$in_config_block" = "false" ]; then \
				echo "$$line" >> "$$tmp_config"; \
			fi; \
		done < ~/.ssh/config; \
		mv "$$tmp_config" ~/.ssh/config; \
		chmod 600 ~/.ssh/config; \
	fi
	@# Remove backup files created by our setup
	@rm -f ~/.ssh/config.bak_* 2>/dev/null || true
	@echo "✅ Clean complete."

# Setup development environment
setup:
	@echo "⚙️ Setting up development environment..."
	@chmod +x scripts/add-package.sh
	@chmod +x shared/common.sh
	@find packages -name "update.sh" -exec chmod +x {} \;
	@command -v shellcheck >/dev/null 2>&1 || { echo "Installing shellcheck..."; sudo pacman -S shellcheck; }
	@echo "✅ Setup complete."

# List all available packages
list-packages:
	@echo "📦 Available packages:"
	@for pkg in packages/*; do \
		if [ -d "$$pkg" ]; then \
			echo "  - $$(basename $$pkg)"; \
		fi; \
	done

# Validate all package configurations
validate:
	@echo "✅ Validating package configurations..."
	@for pkg in packages/*; do \
		if [ -f "$$pkg/update.sh" ]; then \
			echo "Validating $$(basename $$pkg)..."; \
			cd "$$pkg" && bash -n update.sh && echo "  ✓ Syntax OK" || echo "  ✗ Syntax Error"; \
			cd ../..; \
		fi; \
	done
	@echo "✅ Validation complete."

# Quick test for a specific package (no dry-run)
test-quick:
ifndef PACKAGE
	$(error PACKAGE is required. Usage: make test-quick PACKAGE=<name>)
endif
	@echo "⚡ Quick test for package: $(PACKAGE)"
	@cd packages/$(PACKAGE) && ./update.sh --help

# Show package status
status:
ifndef PACKAGE
	$(error PACKAGE is required. Usage: make status PACKAGE=<name>)
endif
	@echo "📊 Status for package: $(PACKAGE)"
	@echo "📁 Package directory: packages/$(PACKAGE)"
	@if [ -f "packages/$(PACKAGE)/update.sh" ]; then \
		echo "✓ Update script exists"; \
		if [ -x "packages/$(PACKAGE)/update.sh" ]; then \
			echo "✓ Update script is executable"; \
		else \
			echo "✗ Update script is not executable"; \
		fi; \
	else \
		echo "✗ Update script does not exist"; \
	fi
	@if [ -f ".github/workflows/$(PACKAGE).yml" ]; then \
		echo "✓ GitHub workflow exists"; \
	else \
		echo "✗ GitHub workflow does not exist"; \
	fi

# Update AUR package with specified SSH key
update:
ifndef PACKAGE
	$(error PACKAGE is required. Usage: make update PACKAGE=<name> SSH_KEY=<path/to/key>)
endif
ifndef SSH_KEY
	$(error SSH_KEY is required. Usage: make update PACKAGE=<name> SSH_KEY=<path/to/key>)
endif
	@echo "🔄 Updating AUR package: $(PACKAGE)"
	@echo "🔑 Using SSH key: $(SSH_KEY)"
	@SSH_KEY_EXPANDED=$$(bash -c "echo $(SSH_KEY)"); \
	if [ ! -f "$$SSH_KEY_EXPANDED" ]; then \
		echo "❌ Error: SSH key file not found: $$SSH_KEY_EXPANDED"; \
		exit 1; \
	fi
	@if [ ! -f "packages/$(PACKAGE)/update.sh" ]; then \
		echo "❌ Error: Package update script not found: packages/$(PACKAGE)/update.sh"; \
		exit 1; \
	fi
	@SSH_KEY_EXPANDED=$$(bash -c "echo $(SSH_KEY)"); \
	export AUR_SSH_PRIVATE_KEY=$$(cat "$$SSH_KEY_EXPANDED"); \
	cd packages/$(PACKAGE) && ./update.sh --verbose
