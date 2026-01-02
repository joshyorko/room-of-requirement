#!/bin/bash
# T057: Create install.sh with direct binary downloads (Sema4.AI, joshyorko RCC)
# T058: Add SHA256 checksum verification to specialty tools install script
# Room of Requirement Specialty Tools Feature
#
# NOTE: Most CLI tools (dagger, claude-code, devspace, hauler, uv, container-use)
# are installed via Homebrew. This script only handles tools NOT in Homebrew.
set -euo pipefail

# ============================================================================
# CONFIGURATION - Feature Options
# ============================================================================
# These can be controlled via devcontainer.json feature options
INSTALL_ACTION_SERVER="${INSTALL_ACTION_SERVER:-true}"
INSTALL_RCC="${INSTALL_RCC:-true}"

# ============================================================================
# TOOL VERSIONS & CHECKSUMS (T058)
# ============================================================================
# Sema4.AI tools - pinned versions for reproducibility
ACTION_SERVER_VERSION="2.17.1"
ACTION_SERVER_SHA256="5a3f66707a1b66e4512afb1e6827394eaaaffaec84798129159721e955b8ba41"

# joshyorko RCC (NOT Robocorp - that's the upstream, this is the fork)
RCC_VERSION="18.12.1"
RCC_SHA256="ec11807a08b23a098959a717e8011bcb776c56c2f0eaeded80b5a7dc0cb0da3a"

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================
echo_info() {
    echo "[INFO] $*"
}

echo_success() {
    echo "[✓] $*"
}

echo_warning() {
    echo "[⚠] $*"
}

echo_error() {
    echo "[✗] $*" >&2
}

# Verify SHA256 checksum of downloaded file
verify_checksum() {
    local file="$1"
    local expected_sha="$2"
    local actual_sha

    if [ ! -f "$file" ]; then
        echo_error "File not found: $file"
        return 1
    fi

    actual_sha=$(sha256sum "$file" | awk '{print $1}')

    if [ "$actual_sha" = "$expected_sha" ]; then
        echo_success "Checksum verified: $file"
        return 0
    else
        echo_error "Checksum mismatch: $file"
        echo_error "  Expected: $expected_sha"
        echo_error "  Actual:   $actual_sha"
        return 1
    fi
}

# Download tool with checksum verification
download_and_verify() {
    local url="$1"
    local dest="$2"
    local sha256="$3"
    local name="$(basename "$dest")"

    echo_info "Downloading $name from $url"

    if curl -fsSL -o "$dest" "$url"; then
        if verify_checksum "$dest" "$sha256"; then
            chmod +x "$dest"
            echo_success "$name installed to $dest"
            return 0
        else
            rm -f "$dest"
            echo_error "Checksum verification failed, file removed"
            return 1
        fi
    else
        echo_error "Failed to download $name from $url"
        return 1
    fi
}

# ============================================================================
# MAIN INSTALLATION
# ============================================================================
echo_info "Installing Room of Requirement Specialty Tools..."
echo_info "Feature options:"
echo_info "  INSTALL_ACTION_SERVER=$INSTALL_ACTION_SERVER"
echo_info "  INSTALL_RCC=$INSTALL_RCC"


INSTALL_DIR="/usr/local/bin"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

cd "$TMP_DIR"

INSTALLED_TOOLS=()
FAILED_TOOLS=()

# ============================================================================
# Sema4.AI: action-server - Default Enabled
# ============================================================================
if [ "${INSTALL_ACTION_SERVER}" = "true" ]; then
    echo_info "Installing Sema4.AI action-server v${ACTION_SERVER_VERSION}..."

    # action-server is available from Sema4.AI CDN
    ACTION_SERVER_URL="https://cdn.sema4.ai/action-server/releases/${ACTION_SERVER_VERSION}/linux64/action-server"
    ACTION_SERVER_BIN="${INSTALL_DIR}/action-server"

    if download_and_verify "$ACTION_SERVER_URL" "$ACTION_SERVER_BIN" "$ACTION_SERVER_SHA256"; then
        INSTALLED_TOOLS+=("action-server v${ACTION_SERVER_VERSION}")
    else
        echo_warning "action-server installation failed"
        FAILED_TOOLS+=("action-server")
    fi
else
    echo_info "Skipping action-server (INSTALL_ACTION_SERVER=false)"
fi

# ============================================================================
# joshyorko RCC - Default Enabled
# ============================================================================
if [ "${INSTALL_RCC}" = "true" ]; then
    echo_info "Installing joshyorko RCC v${RCC_VERSION}..."

    # rcc available from joshyorko fork (NOT Robocorp - that's a different version)
    RCC_URL="https://github.com/joshyorko/rcc/releases/download/v${RCC_VERSION}/rcc-linux64"
    RCC_BIN="${INSTALL_DIR}/rcc"

    if download_and_verify "$RCC_URL" "$RCC_BIN" "$RCC_SHA256"; then
        INSTALLED_TOOLS+=("rcc v${RCC_VERSION}")
    else
        echo_warning "rcc installation failed"
        FAILED_TOOLS+=("rcc")
    fi
else
    echo_info "Skipping rcc (INSTALL_RCC=false)"
fi

# ============================================================================
# SUMMARY & COMPLETION
# ============================================================================
echo ""
echo_success "Room of Requirement Specialty Tools installation complete"
echo ""

if [ ${#INSTALLED_TOOLS[@]} -gt 0 ]; then
    echo "Installed tools:"
    for tool in "${INSTALLED_TOOLS[@]}"; do
        echo "  ✓ $tool"
    done
else
    echo "No tools were installed"
fi

if [ ${#FAILED_TOOLS[@]} -gt 0 ]; then
    echo ""
    echo "Failed installations:"
    for tool in "${FAILED_TOOLS[@]}"; do
        echo "  ✗ $tool"
    done
    echo ""
    echo "Note: Feature options control which tools are installed."
    echo "Customize in .devcontainer/devcontainer.json"
fi

echo ""
echo "Verify installations:"
echo "  action-server version"
echo "  rcc --version"
echo ""
echo "For Homebrew-managed tools, use: brew list"
