#!/bin/bash
# T054: Create install.sh with Homebrew bundle install
# Room of Requirement CLI Tools Feature
set -euo pipefail

INSTALL_BREWFILE="${INSTALLBREWFILE:-true}"

echo "Installing Room of Requirement CLI Tools..."

# Verify Homebrew is installed and in PATH
export PATH="/home/linuxbrew/.linuxbrew/bin:${PATH}"
if ! command -v brew &> /dev/null; then
    echo "✗ Homebrew is not installed. Please install Homebrew first."
    exit 1
fi

echo "✓ Homebrew found at $(which brew)"

# Determine Brewfile location
# Priority: Feature-provided Brewfile > workspaces Brewfile > project Brewfile
BREWFILE_LOCATION=""
FEATURE_DIR="${DEVCONTAINER_FEATURE_DIR:-$(dirname "$0")}"
FEATURE_BREWFILE="${FEATURE_DIR}/Brewfile"

echo "Looking for Brewfile in: ${FEATURE_DIR}"

if [ -f "${FEATURE_BREWFILE}" ]; then
    BREWFILE_LOCATION="${FEATURE_BREWFILE}"
    echo "✓ Using Brewfile from feature: ${BREWFILE_LOCATION}"
elif [ -f "/workspaces/.devcontainer/Brewfile" ]; then
    BREWFILE_LOCATION="/workspaces/.devcontainer/Brewfile"
    echo "✓ Using Brewfile from /workspaces/.devcontainer/"
elif [ -f "/workspace/Brewfile" ]; then
    BREWFILE_LOCATION="/workspace/Brewfile"
    echo "✓ Using Brewfile from /workspace/"
else
    echo "⚠ No external Brewfile found, using embedded core tools"
    # Create minimal Brewfile with essential tools
    BREWFILE_LOCATION="/tmp/ror-cli-tools-Brewfile"
    cat > "${BREWFILE_LOCATION}" << 'BREWFILE'
# Core CLI tools for Room of Requirement
brew "jq"
brew "yq"
brew "gh"
brew "kubectl"
brew "helm"
brew "k9s"
brew "awscli"
brew "zsh-autosuggestions"
brew "zsh-syntax-highlighting"
BREWFILE
    echo "✓ Created embedded Brewfile at ${BREWFILE_LOCATION}"
fi

# Install Homebrew packages
if [ "${INSTALL_BREWFILE}" = "true" ] && [ -n "${BREWFILE_LOCATION}" ] && [ -f "${BREWFILE_LOCATION}" ]; then
    echo "Installing Homebrew packages from ${BREWFILE_LOCATION}..."
    echo "--- Brewfile contents ---"
    cat "${BREWFILE_LOCATION}"
    echo "--- End Brewfile ---"
    if brew bundle install --file="${BREWFILE_LOCATION}" --no-lock; then
        echo "✓ CLI tools installed successfully"
    else
        echo "⚠ Some packages may have failed to install"
    fi
elif [ "${INSTALL_BREWFILE}" = "false" ]; then
    echo "Skipping Brewfile installation (INSTALL_BREWFILE=false)"
else
    echo "⚠ No Brewfile found and embedding disabled, skipping installation"
fi

# Verify key tools
TOOLS=("kubectl" "helm" "jq" "yq" "gh" "k9s")
MISSING_TOOLS=()

for tool in "${TOOLS[@]}"; do
    if ! command -v "$tool" &> /dev/null; then
        MISSING_TOOLS+=("$tool")
    fi
done

if [ ${#MISSING_TOOLS[@]} -eq 0 ]; then
    echo "✓ All CLI tools installed successfully"
else
    echo "⚠ Some tools missing: ${MISSING_TOOLS[*]}"
    echo "  Install with: brew install ${MISSING_TOOLS[*]}"
fi

echo "✓ Room of Requirement CLI Tools Feature installation complete"
