#!/usr/bin/env bash
# mise Feature install script
# Installs mise-en-place version manager for polyglot language runtime management

set -e

# Feature options
DEFAULT_TOOLS="${DEFAULTTOOLS:-node@lts,python@latest,go@latest}"
SHIM_PATH="${SHIMPATH:-/usr/local/share/mise/shims}"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}Installing mise-en-place...${NC}"

# Determine architecture
ARCH=$(uname -m)
case "${ARCH}" in
  x86_64)
    ARCH="x64"
    ;;
  aarch64)
    ARCH="arm64"
    ;;
  *)
    echo "Unsupported architecture: ${ARCH}"
    exit 1
    ;;
esac

# Get latest mise release
MISE_VERSION=$(curl -s https://api.github.com/repos/jdx/mise/releases/latest | grep -o '"tag_name": "[^"]*"' | cut -d'"' -f4)
MISE_VERSION=${MISE_VERSION#v}

if [ -z "${MISE_VERSION}" ]; then
  echo "Failed to determine latest mise version"
  exit 1
fi

echo "Downloading mise v${MISE_VERSION}..."

# Download and install mise
TEMP_DIR=$(mktemp -d)
trap "rm -rf ${TEMP_DIR}" EXIT

cd "${TEMP_DIR}"

# Download mise binary
curl -fsSL "https://github.com/jdx/mise/releases/download/v${MISE_VERSION}/mise-v${MISE_VERSION}-linux-${ARCH}" \
  -o mise

chmod +x mise

# Install to /usr/local/bin
mv mise /usr/local/bin/mise
echo -e "${GREEN}✓ mise installed to /usr/local/bin/mise${NC}"

# Initialize mise
echo "Configuring mise..."
/usr/local/bin/mise --version

# Create shim directory and configure PATH
mkdir -p "${SHIM_PATH}"
echo -e "${GREEN}✓ Created shim path at ${SHIM_PATH}${NC}"

# Create configuration directory
mkdir -p /home/vscode/.config/mise
mkdir -p /home/vscode/.cache/mise

# Set proper permissions for vscode user
chown -R vscode:vscode /home/vscode/.config/mise
chown -R vscode:vscode /home/vscode/.cache/mise
mkdir -p "${SHIM_PATH}"
chown -R vscode:vscode "$(dirname "${SHIM_PATH}")"

echo -e "${GREEN}✓ Configuration directories created${NC}"

# Pre-install default tools if specified and not empty
if [ -n "${DEFAULT_TOOLS}" ] && [ "${DEFAULT_TOOLS}" != "none" ]; then
  echo "Pre-installing default tools: ${DEFAULT_TOOLS}"

  # Convert comma-separated list to space-separated
  TOOLS=$(echo "${DEFAULT_TOOLS}" | sed 's/,/ /g')

  # Pre-install each tool as root (for system-wide availability)
  for tool in ${TOOLS}; do
    echo "Installing ${tool}..."
    if /usr/local/bin/mise install "${tool}" 2>&1 || true; then
      echo -e "${GREEN}✓ ${tool} installed${NC}"
    else
      echo "Warning: Failed to install ${tool}"
    fi
  done
fi

echo -e "${GREEN}✓ mise-en-place installation complete${NC}"
echo ""
echo "Next steps:"
echo "1. Add to your shell config (.zshrc, .bashrc, etc.):"
echo "   eval \"\$(mise activate)\""
echo ""
echo "2. Create a .mise.toml in your project to manage tool versions:"
echo "   [tools]"
echo "   node = \"20\""
echo "   python = \"3.11\""
echo ""
echo "3. Run 'mise install' to install configured tools"
