#!/bin/bash
# zoxide Feature install script
# Installs zoxide - a smarter cd command
set -euo pipefail

VERSION="${VERSION:-latest}"

echo "Installing zoxide (${VERSION})..."

# Determine architecture
ARCH=$(uname -m)
case "${ARCH}" in
    x86_64|amd64)
        ZOXIDE_ARCH="x86_64-unknown-linux-musl"
        ;;
    aarch64|arm64)
        ZOXIDE_ARCH="aarch64-unknown-linux-musl"
        ;;
    *)
        echo "Unsupported architecture: ${ARCH}"
        exit 1
        ;;
esac

# Get version to download
if [ "${VERSION}" = "latest" ]; then
    VERSION=$(curl -sS https://api.github.com/repos/ajeetdsouza/zoxide/releases/latest | grep -o '"tag_name": "[^"]*"' | cut -d'"' -f4)
fi

if [ -z "${VERSION}" ]; then
    echo "Failed to determine zoxide version"
    exit 1
fi

echo "Downloading zoxide ${VERSION} for ${ZOXIDE_ARCH}..."

# Create temp directory
TEMP_DIR=$(mktemp -d)
trap "rm -rf ${TEMP_DIR}" EXIT

cd "${TEMP_DIR}"

# Download and extract
DOWNLOAD_URL="https://github.com/ajeetdsouza/zoxide/releases/download/${VERSION}/zoxide-${VERSION#v}-${ZOXIDE_ARCH}.tar.gz"
if ! curl -fsSL "${DOWNLOAD_URL}" -o zoxide.tar.gz; then
    echo "Failed to download zoxide from ${DOWNLOAD_URL}"
    exit 1
fi

tar xzf zoxide.tar.gz

# Install zoxide binary
if [ -f "zoxide" ]; then
    chmod +x zoxide
    mv zoxide /usr/local/bin/zoxide
    echo "✓ zoxide installed to /usr/local/bin/zoxide"
else
    echo "Failed to find zoxide binary in archive"
    exit 1
fi

# Verify installation
if command -v zoxide &> /dev/null; then
    echo "✓ zoxide $(zoxide --version) installed successfully"
    echo ""
    echo "Add to your shell config:"
    echo "  eval \"\$(zoxide init bash)\"  # for bash"
    echo "  eval \"\$(zoxide init zsh)\"   # for zsh"
else
    echo "zoxide installation verification failed"
    exit 1
fi
