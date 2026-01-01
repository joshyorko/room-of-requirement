#!/bin/bash
# T049: Create install.sh for Nushell Feature
# T101: Install Nushell but keep ZSH as default shell
set -euo pipefail

NUSHELL_VERSION="${NUSHELL_VERSION:-latest}"

echo "Installing Nushell (${NUSHELL_VERSION})..."

# Install Nushell via Homebrew or direct download
if command -v brew &> /dev/null; then
    brew install nushell
elif command -v curl &> /dev/null; then
    # Direct binary download for Nushell
    ARCH=$(uname -m)
    if [ "${ARCH}" = "x86_64" ] || [ "${ARCH}" = "amd64" ]; then
        NUSHELL_ARCH="x86_64-linux"
    elif [ "${ARCH}" = "aarch64" ] || [ "${ARCH}" = "arm64" ]; then
        NUSHELL_ARCH="aarch64-linux"
    else
        echo "✗ Unsupported architecture: ${ARCH}"
        exit 1
    fi

    DOWNLOAD_URL="https://github.com/nushell/nushell/releases/download/${NUSHELL_VERSION}/nu-${NUSHELL_VERSION}-${NUSHELL_ARCH}.tar.gz"

    curl -sS -L "${DOWNLOAD_URL}" | tar xz -C /usr/local/bin
else
    echo "✗ Neither brew nor curl found. Please install Nushell manually."
    exit 1
fi

# Verify installation
if command -v nu &> /dev/null; then
    echo "✓ Nushell installed successfully: $(nu --version)"

    # T101: Verify ZSH remains default shell (not changing default shell)
    if [ "${SHELL}" = "/bin/zsh" ]; then
        echo "✓ ZSH remains default shell"
    fi

    echo "✓ Nushell available as alternative shell - use 'nu' to switch"
    echo "✓ Nushell Feature installation complete"
else
    echo "✗ Nushell installation failed"
    exit 1
fi
