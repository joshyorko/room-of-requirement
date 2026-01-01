#!/bin/bash
# T054: Create install.sh with Homebrew bundle install
# Room of Requirement CLI Tools Feature
set -euo pipefail

INSTALL_BREWFILE="${INSTALL_BREWFILE:-true}"

echo "Installing Room of Requirement CLI Tools..."

# Verify Homebrew is installed
if ! command -v brew &> /dev/null; then
    echo "✗ Homebrew is not installed. Please install Homebrew first."
    exit 1
fi

# Determine Brewfile location
# Priority: Feature-provided Brewfile > user's project Brewfile
BREWFILE_LOCATION=""
FEATURE_BREWFILE="${DEVCONTAINER_FEATURE_DIR:-/tmp}/Brewfile"

if [ -f "${FEATURE_BREWFILE}" ]; then
    BREWFILE_LOCATION="${FEATURE_BREWFILE}"
    echo "✓ Using Brewfile from feature"
elif [ -f "/workspace/Brewfile" ]; then
    BREWFILE_LOCATION="/workspace/Brewfile"
    echo "✓ Using Brewfile from workspace"
elif [ -f "./Brewfile" ]; then
    BREWFILE_LOCATION="./Brewfile"
    echo "✓ Using Brewfile from current directory"
fi

# Install Homebrew packages
if [ "${INSTALL_BREWFILE}" = "true" ] && [ -n "${BREWFILE_LOCATION}" ] && [ -f "${BREWFILE_LOCATION}" ]; then
    echo "Installing Homebrew packages from ${BREWFILE_LOCATION}..."
    if brew bundle install --file="${BREWFILE_LOCATION}"; then
        echo "✓ CLI tools installed successfully"
    else
        echo "⚠ Some packages may have failed to install"
    fi
elif [ "${INSTALL_BREWFILE}" = "false" ]; then
    echo "Skipping Brewfile installation (INSTALL_BREWFILE=false)"
else
    echo "⚠ No Brewfile found, skipping installation"
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
