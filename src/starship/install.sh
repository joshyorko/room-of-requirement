#!/usr/bin/env bash
# Starship Feature install script
# Installs Starship prompt for shell customization and performance

set -e

# Feature options
STARSHIP_VERSION="${VERSION:-latest}"
CONFIG_PATH="${CONFIGPATH:-starship.toml}"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}Installing Starship${NC}"

# Determine architecture
ARCH=$(uname -m)
case "${ARCH}" in
  x86_64)
    ARCH="x86_64"
    ;;
  aarch64)
    ARCH="aarch64"
    ;;
  *)
    echo "Unsupported architecture: ${ARCH}"
    exit 1
    ;;
esac

if [ "${STARSHIP_VERSION}" = "latest" ]; then
  # Get latest version from GitHub API
  STARSHIP_VERSION=$(curl -s https://api.github.com/repos/starship/starship/releases/latest | grep -o '"tag_name": "[^"]*"' | cut -d'"' -f4)
  STARSHIP_VERSION=${STARSHIP_VERSION#v}
fi

if [ -z "${STARSHIP_VERSION}" ]; then
  echo "Failed to determine Starship version"
  exit 1
fi

echo "Downloading Starship v${STARSHIP_VERSION} for ${ARCH}..."

# Create temp directory
TEMP_DIR=$(mktemp -d)
trap "rm -rf ${TEMP_DIR}" EXIT

cd "${TEMP_DIR}"

# Download Starship binary
if ! curl -fsSL "https://github.com/starship/starship/releases/download/v${STARSHIP_VERSION}/starship-x86_64-unknown-linux-gnu.tar.gz" \
  -o starship.tar.gz; then
  echo "Failed to download Starship v${STARSHIP_VERSION}"
  exit 1
fi

# Extract and install
tar xzf starship.tar.gz
chmod +x starship
sudo mv starship /usr/local/bin/starship

echo -e "${GREEN}✓ Starship installed to /usr/local/bin/starship${NC}"

# Verify installation
if ! command -v starship &> /dev/null; then
  echo "✗ Starship installation verification failed"
  exit 1
fi

echo "$(starship --version)"

# Create configuration directory
mkdir -p /home/vscode/.config
chown -R vscode:vscode /home/vscode/.config

echo -e "${GREEN}✓ Configuration directory created${NC}"

echo -e "${GREEN}✓ Starship installation complete${NC}"
echo ""
echo "Next steps:"
echo "1. Add to your shell config (.zshrc, .bashrc, etc.):"
echo "   eval \"\$(starship init <shell>)\""
echo ""
echo "2. Starship will automatically load from: \$STARSHIP_CONFIG"
echo "   Currently set to: /home/vscode/.config/starship.toml"
