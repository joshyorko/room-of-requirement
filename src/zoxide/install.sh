#!/bin/bash
# T047: Create install.sh for zoxide Feature
set -euo pipefail

ZOXIDE_VERSION="${ZOXIDE_VERSION:-latest}"

echo "Installing zoxide (${ZOXIDE_VERSION})..."

# Install zoxide via Homebrew or direct download
if command -v brew &> /dev/null; then
    brew install zoxide
elif command -v curl &> /dev/null; then
    curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash
else
    echo "✗ Neither brew nor curl found. Please install zoxide manually."
    exit 1
fi

# Verify installation
if command -v zoxide &> /dev/null; then
    echo "✓ zoxide installed successfully: $(zoxide --version)"
    echo "✓ zoxide Feature installation complete"
else
    echo "✗ zoxide installation failed"
    exit 1
fi
