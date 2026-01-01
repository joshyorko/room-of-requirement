#!/bin/bash
# Nushell Feature install script
# Installs Nushell shell as an alternative to bash/zsh
set -euo pipefail

VERSION="${VERSION:-latest}"

echo "Installing Nushell (${VERSION})..."

# Determine architecture
ARCH=$(uname -m)
case "${ARCH}" in
    x86_64|amd64)
        NU_ARCH="x86_64-unknown-linux-gnu"
        ;;
    aarch64|arm64)
        NU_ARCH="aarch64-unknown-linux-gnu"
        ;;
    *)
        echo "Unsupported architecture: ${ARCH}"
        exit 1
        ;;
esac

# Get version to download
if [ "${VERSION}" = "latest" ]; then
    VERSION=$(curl -sS https://api.github.com/repos/nushell/nushell/releases/latest | grep -o '"tag_name": "[^"]*"' | cut -d'"' -f4)
fi

if [ -z "${VERSION}" ]; then
    echo "Failed to determine Nushell version"
    exit 1
fi

echo "Downloading Nushell ${VERSION} for ${NU_ARCH}..."

# Create temp directory
TEMP_DIR=$(mktemp -d)
trap "rm -rf ${TEMP_DIR}" EXIT

cd "${TEMP_DIR}"

# Download and extract
DOWNLOAD_URL="https://github.com/nushell/nushell/releases/download/${VERSION}/nu-${VERSION}-${NU_ARCH}.tar.gz"
if ! curl -fsSL "${DOWNLOAD_URL}" -o nushell.tar.gz; then
    echo "Failed to download Nushell from ${DOWNLOAD_URL}"
    exit 1
fi

tar xzf nushell.tar.gz

# Find and install the nu binary
NU_BIN=$(find . -name "nu" -type f -executable | head -1)
if [ -z "${NU_BIN}" ]; then
    # Try without executable check
    NU_BIN=$(find . -name "nu" -type f | head -1)
fi

if [ -n "${NU_BIN}" ]; then
    chmod +x "${NU_BIN}"
    mv "${NU_BIN}" /usr/local/bin/nu
    echo "✓ Nushell installed to /usr/local/bin/nu"
else
    echo "Failed to find nu binary in archive"
    exit 1
fi

# Verify installation
if command -v nu &> /dev/null; then
    echo "✓ Nushell $(nu --version) installed successfully"
    echo "✓ Use 'nu' to start Nushell (ZSH remains default)"
else
    echo "Nushell installation verification failed"
    exit 1
fi
