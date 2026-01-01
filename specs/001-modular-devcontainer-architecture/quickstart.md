# Quickstart: Modular DevContainer Architecture

**Feature**: 001-modular-devcontainer-architecture
**Date**: 2026-01-01

This guide provides step-by-step instructions for working with the new modular Room of Requirement architecture.

---

## For Users: Using the Pre-built Image

### Option 1: Instant Start (Recommended)

The fastest way to use Room of Requirement - no build required:

```json
// .devcontainer/devcontainer.json
{
  "name": "My Project",
  "image": "ghcr.io/joshyorko/ror:latest",
  "features": {
    "ghcr.io/devcontainers/features/docker-in-docker:2": {}
  },
  "remoteUser": "vscode"
}
```

**Startup time**: ~15 seconds (cached image)

### Option 2: Using the Template

Generate a complete DevContainer configuration:

```bash
# Using devcontainer CLI
devcontainer templates apply --template ghcr.io/joshyorko/ror/templates/ror-starter

# Or manually copy from:
# https://github.com/joshyorko/room-of-requirement/tree/main/templates/ror-starter
```

### Option 3: Custom Feature Composition

Build your own combination of features:

```json
// .devcontainer/devcontainer.json
{
  "name": "Custom Environment",
  "image": "cgr.dev/chainguard/wolfi-base:latest",
  "features": {
    "ghcr.io/joshyorko/ror/mise:1": {
      "defaultTools": "python@3.12,node@20"
    },
    "ghcr.io/joshyorko/ror/starship:1": {},
    "ghcr.io/devcontainers/features/docker-in-docker:2": {}
  },
  "remoteUser": "vscode"
}
```

---

## Tool Version Management with Mise

### Default Global Versions (T041)

The Room of Requirement provides default versions in `.devcontainer/config/mise.toml`:

```toml
[tools]
node = "lts"        # Latest LTS Node.js (currently 20.x)
python = "latest"   # Latest stable Python (currently 3.13+)
go = "latest"       # Latest stable Go (currently 1.23+)
rust = "latest"     # Latest stable Rust
ruby = "latest"     # Latest stable Ruby
```

These defaults are pre-installed in the image for immediate use. Check what's available:

```bash
# List all available versions for a tool
mise list-all node
mise list-all python
mise list-all go

# See currently active versions
mise current
mise list

# Check tool installation status
mise doctor
```

### Version Override Patterns (T042)

#### Pattern 1: Project-Specific .mise.toml

Create `.mise.toml` in your project root to override defaults:

```toml
# .mise.toml - Project root
# This file overrides global versions for this project

[tools]
node = "20.10.0"           # Specific Node.js version
python = "3.12.1"          # Specific Python version
go = "1.22"                # Specific Go version
ruby = "3.3.0"             # Optional: add Ruby for this project

[env]
PROJECT_NAME = "my-app"
NODE_ENV = "development"
PYTHON_ENV = "dev"
```

**How it works:**
- When you `cd` into a directory with `.mise.toml`, mise automatically activates those versions
- The versions are available in that directory and all subdirectories
- Leave your parent directory to return to global defaults

**Commands:**

```bash
# Install versions specified in .mise.toml
mise install

# Verify installation
mise current          # Shows active versions in this directory
mise list             # Shows all tools with versions

# Trust the project configuration (skip on future cd)
mise trust
# Run once per project - mise will remember to auto-load

# Verify no warnings
mise doctor
```

#### Pattern 2: .tool-versions File (Legacy Format)

Some tools use the `.tool-versions` format (compatible with `asdf`):

```bash
# .tool-versions - Project root
node 20.10.0
python 3.12.1
go 1.22
ruby 3.3.0
```

**Advantages:**
- Compatible with `asdf` tooling
- Simpler syntax for specific versions only
- Smaller file size

**How to generate:**

```bash
# Create from currently active versions
cat > .tool-versions << 'EOF'
$(mise current --format=simple)
EOF
```

#### Pattern 3: Command-Line Overrides

Temporarily switch versions without creating config files:

```bash
# Single-shot: use specific version for next command
mise use node@18 && npm --version
# Node 18 is used only for this command

# Shell-specific: use version for current shell session
mise use -g python@3.11     # -g: global to this shell session
python --version            # Shows 3.11.x

# Reset to project defaults
exec zsh -l                 # Reload shell (drops -g overrides)
```

#### Pattern 4: Environment Variables

Control version selection via environment variables:

```bash
# Temporary override
MISE_PYTHON_VERSION=3.10 python --version

# Shell-persistent
export MISE_PYTHON_VERSION=3.10
python --version            # Uses 3.10
export MISE_PYTHON_VERSION= # Clear override
python --version            # Back to default
```

#### Pattern 5: Install Additional Versions

Install extra versions alongside project defaults:

```bash
# Install additional Python version
mise install python@3.10

# Switch to it for current directory only
mise local python@3.10      # Creates local .mise.toml with python = "3.10"
python --version            # Now 3.10

# List all installed versions
mise list python            # Shows 3.10, 3.12, 3.13, etc.

# Remove unused versions
mise uninstall python@3.10
```

#### Pattern 6: Version Ranges and Constraints

Use flexible version specifications:

```toml
[tools]
# Specific versions
node = "20.10.0"
python = "3.12.1"

# Latest minor (e.g., 3.12.x)
ruby = "3.2"

# Latest patch of major (e.g., 3.x)
go = "1"

# Special versions
python = "latest"           # Latest available
python = "lts"              # Latest LTS (if available)

# Version ranges
node = "18.0.0 || 20.0.0"   # Either 18 or 20 (some tools)
```

### Version Selection Hierarchy (T042)

When a tool is invoked, mise checks versions in this order:

```
1. Command-line override (-g flag or mise use)
2. Environment variable (MISE_<TOOL>_VERSION)
3. Local .mise.toml in current/parent directories
4. Global .mise.toml (~/.config/mise/config.toml)
5. .devcontainer/config/mise.toml (Room of Requirement global)
6. System-installed version
```

**Practical example:**

```bash
# Global default (from .devcontainer/config/mise.toml)
python --version            # Python 3.13.1 (latest)

# Enter project directory with .mise.toml
cd ~/projects/legacy-app    # Contains: python = "3.9"
python --version            # Python 3.9.x

# Override with environment variable
MISE_PYTHON_VERSION=3.11 python --version    # Python 3.11.x

# Override with command-line
mise use python@3.10
python --version            # Python 3.10.x

# Reset to local .mise.toml
exec zsh -l
python --version            # Back to 3.9.x (from .mise.toml)

# Leave project directory
cd ~
python --version            # Back to 3.13.1 (global default)
```

### Common Override Scenarios

#### Scenario 1: Python Data Science Project

```bash
# Create project with specific Python and data tools
mkdir my-ml-project && cd my-ml-project

cat > .mise.toml << 'EOF'
[tools]
python = "3.11.8"           # Pinned for reproducibility
node = "20"                 # For Jupyter Lab/notebooks UI

[tasks.dev-setup]
run = "pip install -r requirements.txt"

[tasks.train-model]
run = "python src/train.py"

[env]
PYTHONPATH = "{{ config_root }}/src"
CUDA_VISIBLE_DEVICES = "0"  # GPU selection
EOF

# Install and verify
mise install
mise doctor
python --version            # 3.11.8
```

#### Scenario 2: Node.js Backend + Python Backend

```bash
mkdir full-stack && cd full-stack

cat > .mise.toml << 'EOF'
[tools]
node = "20.10.0"            # API backend
python = "3.12"             # Data service
go = "1.22"                 # Worker service

[tasks.dev-all]
run = """
npm install &&
pip install -r requirements.txt &&
go mod download
"""

[tasks.start-api]
run = "npm run dev"

[tasks.start-data]
run = "python -m uvicorn main:app"

[tasks.start-worker]
run = "go run cmd/worker/main.go"
EOF

mise install
mise run dev-all
```

#### Scenario 3: Legacy App with Constrained Versions

```bash
cd legacy-rails-app

cat > .mise.toml << 'EOF'
[tools]
ruby = "2.7.8"              # Old Rails version requirement
node = "14.21.3"            # Old Node for npm/yarn
postgres = "11"             # Old database version

[settings]
# Strict mode: fail if any tool version can't be installed
auto_install = true
EOF

mise install
ruby --version              # 2.7.8
node --version              # 14.21.3
```

#### Scenario 4: Testing Multiple Versions

```bash
# Install multiple versions for CI matrix testing
mise install node@18 node@20 node@22

# Test with specific version
mise use node@18
npm test

# Test with next version
mise use node@20
npm test

# List what you have
mise list node              # Shows 18, 20, 22, lts, latest
```

### Verify Installation (T042)

After setting up version overrides:

```bash
# Check status
mise doctor

# List installed tools with versions
mise list

# Verify specific tool
node --version
python --version
go --version

# Show where each tool is installed
which node                  # Shows mise shim path
which -a node               # Shows all available node installations

# Validate .mise.toml syntax
mise task list              # If tasks defined, lists them
```

### Common Commands

```bash
# Switch Node version for current shell
mise use node@18

# Install a specific tool globally
mise install -g python@3.11

# Trust a project's configuration
mise trust

# Update all tools to latest
mise upgrade

# Clean up old versions
mise prune
```

---

## Homebrew in the Wolfi + Homebrew Foundation

Room of Requirement uses a Universal Blue-inspired foundation combining Chainguard's Wolfi Linux with Homebrew for comprehensive package management. This approach provides:

- **Wolfi**: Secure, minimal base OS with glibc compatibility
- **Homebrew**: Cross-platform package manager for development tools
- **Clear separation**: System packages vs. development tools

### Foundation Architecture

```bash
# Base system (Wolfi)
apk list --installed | grep -E "(glibc|curl|git|bash)"

# Development tools (Homebrew)
brew list | head -10

# Check integration
which python3  # Should show Homebrew path
which kubectl  # Should show Homebrew path
```

### Homebrew Setup Verification

```bash
# Verify Homebrew installation
brew --version
brew doctor

# Check PATH configuration
echo $PATH | tr ':' '\n' | grep -E "(brew|linuxbrew)"

# Verify linuxbrew user setup
id linuxbrew
ls -la /home/linuxbrew/.linuxbrew
```

---

## Comprehensive Brewfile Examples

Brewfiles provide declarative package management for different development scenarios.

### Web Development Brewfile

```ruby
# Brewfile.web
# Install with: brew bundle install --file=Brewfile.web

# Essential web development tools
brew "jq"                    # JSON processor
brew "yq"                    # YAML processor
brew "httpie"                # HTTP client
brew "curl"                  # Enhanced curl
brew "wget"                  # File downloader

# Frontend tooling
brew "sass/sass/sass"        # Sass CSS preprocessor
brew "yarn"                  # Package manager
brew "pnpm"                  # Fast package manager

# Backend utilities
brew "redis"                 # In-memory database
brew "postgresql@15"         # Database
brew "nginx"                 # Web server

# Containers & orchestration
brew "docker-compose"        # Container orchestration
brew "kubectl"               # Kubernetes CLI
brew "helm"                  # Kubernetes package manager

# Development utilities
brew "gh"                    # GitHub CLI
brew "git-delta"             # Enhanced git diff
brew "lazygit"               # Git TUI
brew "fd"                    # Find alternative
brew "ripgrep"               # Grep alternative
brew "bat"                   # Cat alternative
brew "exa"                   # ls alternative
```

### Machine Learning Brewfile

```ruby
# Brewfile.ml
# Install with: brew bundle install --file=Brewfile.ml

# Data processing
brew "duckdb"                # Analytical database
brew "sqlite"                # Lightweight database
brew "pandoc"                # Document converter

# MLOps tools
brew "mlflow"                # ML lifecycle management
brew "dvc"                   # Data version control
brew "git-lfs"               # Large file storage

# Jupyter ecosystem
brew "jupyterlab"            # Interactive notebooks

# Cloud ML platforms
brew "aws-cli"               # AWS CLI
brew "azure-cli"             # Azure CLI
brew "google-cloud-sdk"      # Google Cloud CLI

# Monitoring & observability
brew "prometheus"            # Metrics collection
brew "grafana"               # Metrics visualization

# Development utilities
brew "jq"                    # JSON manipulation
brew "yq"                    # YAML manipulation
brew "httpie"                # HTTP testing
brew "gh"                    # GitHub CLI
brew "git-delta"             # Enhanced diffs
```

### DevOps/Platform Engineering Brewfile

```ruby
# Brewfile.devops
# Install with: brew bundle install --file=Brewfile.devops

# Container & Kubernetes
brew "kubectl"               # Kubernetes CLI
brew "helm"                  # Kubernetes packages
brew "k9s"                   # Kubernetes TUI
brew "kubectx"               # Context switching
brew "kustomize"             # Kubernetes manifests
brew "skaffold"              # Development workflow
brew "istioctl"              # Service mesh

# Infrastructure as Code
brew "terraform"             # Infrastructure provisioning
brew "terragrunt"            # Terraform wrapper
brew "pulumi"                # Modern IaC
brew "ansible"               # Configuration management

# Cloud platforms
brew "aws-cli"               # AWS CLI
brew "azure-cli"             # Azure CLI
brew "google-cloud-sdk"      # GCP CLI
brew "doctl"                 # DigitalOcean CLI

# Monitoring & Security
brew "prometheus"            # Metrics
brew "grafana-cli"           # Dashboards
brew "vault"                 # Secrets management
brew "cosign"                # Container signing
brew "trivy"                 # Vulnerability scanner

# Network & debugging
brew "tcpdump"               # Network analysis
brew "wireshark-cli"         # Network debugging
brew "nmap"                  # Network discovery
brew "openssl"               # Cryptography

# Development workflow
brew "gh"                    # GitHub CLI
brew "act"                   # Run GitHub Actions locally
brew "pre-commit"            # Git hooks
brew "commitizen"            # Conventional commits
```

### Project-Specific Brewfile Workflow

```bash
# 1. Create project-specific Brewfile
cat > Brewfile << 'EOF'
# My Project Dependencies
brew "jq"
brew "kubectl"
brew "helm"
brew "terraform"
EOF

# 2. Install dependencies
brew bundle install

# 3. Verify installation
brew bundle check

# 4. Update Brewfile from current installations
brew bundle dump --force

# 5. Clean up unused packages
brew bundle cleanup
```

---

## Homebrew + Mise Integration Examples

Clear separation of concerns between Homebrew and mise for optimal development experience.

### Separation Strategy

**Mise handles**: Language runtimes and version management
**Homebrew handles**: CLI tools, system utilities, and development tools

### Integration Example 1: Python Data Science

```toml
# .mise.toml - Language runtime management
[tools]
python = "3.11.7"     # Mise manages Python versions
node = "20.10.0"      # Mise manages Node.js versions
go = "1.21.5"         # Mise manages Go versions

[tasks.setup]
run = "pip install -r requirements.txt && brew bundle install"

[env]
PATH = "{{ config_root }}/venv/bin:$PATH"
```

```ruby
# Brewfile - Development tools
brew "duckdb"        # Database for analytics
brew "sqlite"        # Lightweight database
brew "jq"            # JSON processing
brew "pandoc"        # Document conversion
brew "gh"            # GitHub CLI
brew "git-lfs"       # Large file support
```

```bash
# Setup workflow
mise install          # Install language runtimes
mise run setup        # Install Python packages + Homebrew tools

# Verify separation
which python          # Shows mise-managed Python
which duckdb          # Shows Homebrew-managed tool
mise current          # Shows active language versions
brew list             # Shows installed development tools
```

### Integration Example 2: Full-Stack Development

```toml
# .mise.toml
[tools]
node = "20"           # Mise: Node.js runtime
python = "3.12"       # Mise: Python runtime
go = "latest"         # Mise: Go runtime
rust = "1.75"         # Mise: Rust toolchain

[tasks.dev-setup]
run = """
brew bundle install
npm install -g pnpm
pip install poetry
cargo install cargo-watch
"""

[tasks.dev]
run = "docker-compose up -d && pnpm dev"

[env]
DOCKER_BUILDKIT = "1"
```

```ruby
# Brewfile
# Container orchestration
brew "docker-compose"
brew "kubectl"
brew "k9s"

# Database tools
brew "postgresql@15"
brew "redis"

# Development utilities
brew "httpie"
brew "jq"
brew "yq"
brew "fd"
brew "ripgrep"
brew "git-delta"

# Cloud tools
brew "aws-cli"
brew "gh"
```

### PATH Management

```bash
# Check PATH order (mise should come before Homebrew for languages)
echo $PATH | tr ':' '\n' | nl

# Expected order:
# 1. ~/.local/share/mise/shims     (mise-managed tools)
# 2. /home/linuxbrew/.linuxbrew/bin (Homebrew tools)
# 3. /usr/local/bin                (system binaries)
# 4. /usr/bin                      (system binaries)

# Verify language runtime source
which python          # Should show mise shim
which -a python       # Show all Python installations

# Verify tool source
which kubectl         # Should show Homebrew installation
which -a kubectl      # Show all kubectl installations
```

### Common Integration Patterns

```bash
# Pattern 1: Project initialization
mise install                    # Install language runtimes
brew bundle install            # Install development tools
npm install                    # Install project dependencies

# Pattern 2: Environment switching
mise use python@3.9            # Switch Python version (mise)
# Keep same kubectl, jq, etc. (Homebrew)

# Pattern 3: Tool updating
mise upgrade                   # Update language runtimes
brew update && brew upgrade    # Update development tools
```

---

## Container Startup with Brewfile Integration

Automatic detection and installation of Brewfiles during container startup.

### Enhanced postCreateCommand

```json
// .devcontainer/devcontainer.json
{
  "name": "My Project",
  "image": "ghcr.io/joshyorko/ror:latest",
  "features": {
    "ghcr.io/devcontainers/features/docker-in-docker:2": {}
  },
  "postCreateCommand": "bash -c 'chmod +x .devcontainer/post-create.sh && .devcontainer/post-create.sh'",
  "remoteUser": "vscode",
  "mounts": [
    {
      "source": "homebrew-cache",
      "target": "/home/linuxbrew/.cache",
      "type": "volume"
    }
  ]
}
```

```bash
#!/bin/bash
# .devcontainer/post-create.sh - Enhanced startup script

set -euo pipefail

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >&2
}

# Function to detect and install Brewfiles
install_brewfiles() {
    local brewfiles=()

    # Detect available Brewfiles
    if [[ -f "Brewfile" ]]; then
        brewfiles+=("Brewfile")
    fi

    for env in web ml devops; do
        if [[ -f "Brewfile.$env" ]]; then
            brewfiles+=("Brewfile.$env")
        fi
    done

    if [[ ${#brewfiles[@]} -gt 0 ]]; then
        log "Found Brewfiles: ${brewfiles[*]}"

        for brewfile in "${brewfiles[@]}"; do
            log "Installing packages from $brewfile..."
            if brew bundle check --file="$brewfile" --verbose; then
                log "All packages from $brewfile already installed"
            else
                log "Installing missing packages from $brewfile..."
                brew bundle install --file="$brewfile" --no-lock
            fi
        done

        # Cleanup
        log "Running Homebrew cleanup..."
        brew cleanup

    else
        log "No Brewfiles found, skipping Homebrew package installation"
    fi
}

# Function to setup mise tools
setup_mise() {
    if [[ -f ".mise.toml" ]] || [[ -f ".tool-versions" ]]; then
        log "Setting up mise tools..."
        mise install
        mise trust

        # Verify installation
        log "Installed tools:"
        mise list --current
    else
        log "No mise configuration found"
    fi
}

# Function to run project-specific setup
run_project_setup() {
    # Check for package.json
    if [[ -f "package.json" ]]; then
        log "Found package.json, installing dependencies..."
        if command -v pnpm &> /dev/null; then
            pnpm install
        elif command -v yarn &> /dev/null; then
            yarn install
        else
            npm install
        fi
    fi

    # Check for requirements.txt
    if [[ -f "requirements.txt" ]]; then
        log "Found requirements.txt, installing Python dependencies..."
        pip install -r requirements.txt
    fi

    # Check for Cargo.toml
    if [[ -f "Cargo.toml" ]]; then
        log "Found Cargo.toml, fetching Rust dependencies..."
        cargo fetch
    fi

    # Run mise tasks if available
    if mise task list 2>/dev/null | grep -q "setup"; then
        log "Running mise setup task..."
        mise run setup
    fi
}

# Main execution
main() {
    log "Starting container post-create setup..."

    # Update Homebrew
    log "Updating Homebrew..."
    brew update

    # Install Brewfile dependencies
    install_brewfiles

    # Setup mise tools
    setup_mise

    # Run project-specific setup
    run_project_setup

    # Final verification
    log "Setup complete! Environment status:"
    log "Homebrew packages: $(brew list | wc -l)"
    if command -v mise &> /dev/null; then
        log "Mise tools: $(mise list --current 2>/dev/null || echo 'none')"
    fi

    log "Container ready for development!"
}

main "$@"
```

### Brewfile Detection Examples

```bash
# Example 1: Automatic web development setup
ls -la
# .devcontainer/
# Brewfile.web
# package.json
# .mise.toml

# Container startup will:
# 1. Install Brewfile.web packages (kubectl, helm, jq, etc.)
# 2. Install mise tools (Node.js, Python)
# 3. Run npm install
# 4. Execute any mise setup tasks

# Example 2: Multi-environment setup
ls -la
# Brewfile          # Base dependencies
# Brewfile.ml       # ML-specific tools
# Brewfile.devops   # Infrastructure tools
# requirements.txt  # Python packages
# .mise.toml       # Language versions

# Container startup will install all detected Brewfiles
```

### Caching Strategy

```json
// Enhanced caching in devcontainer.json
{
  "mounts": [
    {
      "source": "homebrew-cache",
      "target": "/home/linuxbrew/.cache",
      "type": "volume"
    },
    {
      "source": "mise-cache",
      "target": "/home/vscode/.local/share/mise",
      "type": "volume"
    },
    {
      "source": "npm-cache",
      "target": "/home/vscode/.npm",
      "type": "volume"
    }
  ]
}
```

---

## Verifying Image Security

### Signature Verification

```bash
# Install cosign if needed
# https://docs.sigstore.dev/cosign/installation/

# Verify image signature
cosign verify ghcr.io/joshyorko/ror:latest \
  --certificate-identity-regexp="https://github.com/joshyorko/room-of-requirement/*" \
  --certificate-oidc-issuer="https://token.actions.githubusercontent.com"
```

### SBOM Inspection

```bash
# Download SBOM
cosign verify-attestation ghcr.io/joshyorko/ror:latest \
  --type spdxjson \
  --certificate-identity-regexp="https://github.com/joshyorko/room-of-requirement/*" \
  --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
  | jq -r '.payload' | base64 -d > sbom.spdx.json

# View package list
cat sbom.spdx.json | jq '.packages[].name'
```

---

## For Contributors: Development Workflow

### Prerequisites

- Docker with BuildKit enabled
- Node.js 18+ (for devcontainer CLI)
- RCC (Robocorp CLI) for maintenance tasks

### Local Development

```bash
# Clone repository
git clone https://github.com/joshyorko/room-of-requirement.git
cd room-of-requirement

# Build image locally
docker build -t ror:dev .devcontainer/

# Test in VS Code
code --folder-uri vscode-remote://dev-container+$(printf '%s' "$PWD" | xxd -p)/workspace
```

### Building Features

```bash
# Install devcontainer CLI
npm install -g @devcontainers/cli

# Build all features
devcontainer features package ./features --output-folder ./output

# Build specific feature
devcontainer features package ./features/mise --output-folder ./output
```

### Running Maintenance

```bash
# Full maintenance run
rcc run -r automation/maintenance-robot/robot.yaml -t maintenance

# Dry run (preview changes)
rcc run -r automation/maintenance-robot/robot.yaml -t maintenance -- --dry-run

# Update specific allowlist
rcc run -r automation/maintenance-robot/robot.yaml -t update-downloads
```

### Testing Changes

```bash
# Lint Dockerfile
hadolint .devcontainer/Dockerfile

# Build and test container
devcontainer build --workspace-folder .
devcontainer exec --workspace-folder . mise doctor
devcontainer exec --workspace-folder . starship --version
```

---

## Troubleshooting

### Homebrew-Specific Issues

#### PATH Conflicts

```bash
# Problem: Wrong tool version being used
which python          # Shows system Python instead of mise-managed

# Diagnosis
echo $PATH | tr ':' '\n' | nl
# Look for incorrect order - mise shims should come before Homebrew

# Solution 1: Reset shell environment
exec zsh -l           # Reload shell configuration

# Solution 2: Verify mise setup
mise activate --shims  # Ensure mise shims are in PATH

# Solution 3: Manual PATH correction in ~/.zshrc
export PATH="$HOME/.local/share/mise/shims:/home/linuxbrew/.linuxbrew/bin:$PATH"
```

#### Permission Issues

```bash
# Problem: Permission denied when running brew commands
brew install jq
# Error: Permission denied @ dir_s_mkdir - /home/linuxbrew/.linuxbrew

# Diagnosis
ls -la /home/linuxbrew/.linuxbrew
id linuxbrew
groups

# Solution 1: Fix ownership
sudo chown -R vscode:vscode /home/linuxbrew/.linuxbrew

# Solution 2: Add vscode to linuxbrew group
sudo usermod -aG linuxbrew vscode
newgrp linuxbrew

# Solution 3: Verify linuxbrew user setup
sudo -u linuxbrew brew doctor
```

#### Linuxbrew User Setup Issues

```bash
# Problem: Homebrew not properly configured for Linux
brew doctor
# Warning: Homebrew/homebrew-core was not tapped properly

# Diagnosis
id linuxbrew
ls -la /home/linuxbrew
brew --config

# Solution 1: Recreate linuxbrew user
sudo userdel linuxbrew
sudo mkdir -p /home/linuxbrew
sudo useradd -r -d /home/linuxbrew linuxbrew
sudo chown linuxbrew:linuxbrew /home/linuxbrew

# Solution 2: Reinstall Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Solution 3: Verify environment variables
echo $HOMEBREW_PREFIX      # Should be /home/linuxbrew/.linuxbrew
echo $HOMEBREW_CELLAR      # Should be /home/linuxbrew/.linuxbrew/Cellar
```

#### Package Installation Failures

```bash
# Problem: Packages fail to install
brew install kubectl
# Error: Failed to download resource "kubectl"

# Diagnosis
brew config                # Check configuration
brew doctor               # Check for issues
curl -I https://github.com # Test network connectivity

# Solution 1: Clear cache and retry
brew cleanup --prune=all
brew update
brew install kubectl

# Solution 2: Use specific tap
brew tap kubernetes/tap
brew install kubernetes/tap/kubectl

# Solution 3: Manual installation fallback
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
```

#### Brewfile Bundle Issues

```bash
# Problem: brew bundle install fails
brew bundle install
# Error: No Brewfile found

# Diagnosis
ls -la Brewfile*
cat Brewfile             # Check syntax
brew bundle check        # Verify dependencies

# Solution 1: Create missing Brewfile
brew bundle dump         # Generate from current installations

# Solution 2: Fix Brewfile syntax
# Ensure proper format:
# brew "package-name"
# cask "app-name"
# tap "user/repo"

# Solution 3: Install specific file
brew bundle install --file=Brewfile.web

# Solution 4: Skip failing packages
brew bundle install --no-lock || true
```

#### Performance and Space Issues

```bash
# Problem: Homebrew taking too much space or running slowly
du -sh /home/linuxbrew/.linuxbrew

# Diagnosis
brew list | wc -l         # Count installed packages
brew outdated             # Check for updates
brew cleanup --dry-run    # See what can be cleaned

# Solution 1: Cleanup old versions
brew cleanup --prune=all
brew autoremove

# Solution 2: Remove unnecessary packages
brew list                 # Review installed packages
brew uninstall <package>  # Remove unneeded packages

# Solution 3: Clear cache
rm -rf "$(brew --cache)"

# Solution 4: Use volume mounts for caching
# Add to .devcontainer/devcontainer.json:
# "mounts": [
#   {
#     "source": "homebrew-cache",
#     "target": "/home/linuxbrew/.cache",
#     "type": "volume"
#   }
# ]
```

#### Integration with Other Tools

```bash
# Problem: Homebrew conflicts with system package manager
apt list --installed | grep kubectl
brew list | grep kubectl
# Multiple versions installed

# Solution 1: Remove system packages
sudo apt remove kubectl
# Then use only Homebrew version

# Solution 2: Use alternatives system
sudo update-alternatives --install /usr/local/bin/kubectl kubectl $(which kubectl) 1

# Solution 3: Explicit PATH management
export PATH="/home/linuxbrew/.linuxbrew/bin:$PATH"

# Problem: mise and Homebrew conflict
which node               # Shows wrong version

# Solution: Ensure correct PATH order
export PATH="$HOME/.local/share/mise/shims:/home/linuxbrew/.linuxbrew/bin:$PATH"
```

### Image Pull Issues

```bash
# Check authentication
docker login ghcr.io

# Pull with verbose output
docker pull ghcr.io/joshyorko/ror:latest --platform linux/amd64
```

### Tool Version Conflicts

```bash
# Reset mise state
rm -rf ~/.local/share/mise
mise install

# Check PATH order
echo $PATH | tr ':' '\n' | head -10
```

### Docker-in-Docker Issues

```bash
# Verify Docker daemon is running
docker info

# Check socket permissions
ls -la /var/run/docker.sock
```

### Signature Verification Failures

```bash
# Check certificate chain
cosign verify --certificate-chain <(curl -sL https://fulcio.sigstore.dev/api/v2/trustBundle) \
  ghcr.io/joshyorko/ror:latest
```

---

## Version Pinning (T085)

For production stability, pin to specific versions of both images and features to ensure reproducible environments.

### Image Version Pinning

The pre-built Room of Requirement image follows semantic versioning with multiple tag options:

| Tag Pattern | Description | Example | Use Case |
|-------------|-------------|---------|----------|
| `latest` | Most recent build from main branch | `ror:latest` | Development, testing new features |
| `stable` | Monthly validated release | `ror:stable` | Teams wanting monthly updates with stability |
| `v{X}.{Y}.{Z}` | Specific semantic version (immutable) | `ror:v2.1.0` | Production, CI/CD pipelines |
| `v{X}.{Y}` | Latest patch of minor version | `ror:v2.1` | Auto-receive security patches |
| `v{X}` | Latest minor of major version | `ror:v2` | Breaking change protection |
| `sha-{hash}` | Specific Git commit SHA | `ror:sha-abc123` | Debugging, rollback |

#### Recommended Patterns

**For Development Teams (Recommended):**
```json
{
  "image": "ghcr.io/joshyorko/ror:v2.1.0"
}
```
Pin to specific semantic version for reproducibility.

**For Personal Projects:**
```json
{
  "image": "ghcr.io/joshyorko/ror:stable"
}
```
Get monthly updates automatically.

**For CI/CD Pipelines:**
```json
{
  "image": "ghcr.io/joshyorko/ror:v2.1.0@sha256:abc123..."
}
```
Pin to digest for maximum reproducibility.

### Feature Version Pinning (T086)

Each DevContainer Feature is independently versioned using semantic versioning. Pin features to specific versions for reproducibility:

```json
{
  "features": {
    // Pin to exact version (recommended for production)
    "ghcr.io/joshyorko/room-of-requirement/mise:1.0.0": {},

    // Pin to major version (auto-receive compatible updates)
    "ghcr.io/joshyorko/room-of-requirement/starship:1": {},

    // Latest version (for development only)
    "ghcr.io/joshyorko/room-of-requirement/zoxide:latest": {}
  }
}
```

#### Available Features & Versions

| Feature | Current Version | Description |
|---------|-----------------|-------------|
| `mise` | `1.0.0` | Polyglot version manager (Node, Python, Go) |
| `starship` | `1.0.0` | Modern shell prompt |
| `zoxide` | `1.0.0` | Smart directory navigation |
| `nushell` | `1.0.0` | Modern shell alternative |
| `ror-core` | `1.0.0` | Meta-feature (mise + starship + zoxide) |
| `ror-cli-tools` | `1.0.0` | CLI tools via Homebrew |
| `ror-specialty` | `1.0.0` | Specialty tools (Sema4.AI, Dagger) |

#### Version Override Patterns (T087)

**Pattern 1: Override Feature Options**
```json
{
  "features": {
    "ghcr.io/joshyorko/room-of-requirement/mise:1.0.0": {
      "defaultTools": "node@18,python@3.11,go@1.21"
    }
  }
}
```

**Pattern 2: Override Meta-Feature Dependencies**
```json
{
  "features": {
    // Use ror-core but override mise options
    "ghcr.io/joshyorko/room-of-requirement/ror-core:1.0.0": {},
    // Add mise again with overrides (takes precedence)
    "ghcr.io/joshyorko/room-of-requirement/mise:1.0.0": {
      "defaultTools": "node@20.10.0,python@3.12.1"
    }
  }
}
```

**Pattern 3: Mix GHCR and Custom Features**
```json
{
  "features": {
    // Published features from GHCR
    "ghcr.io/joshyorko/room-of-requirement/mise:1.0.0": {},
    // Local feature for project-specific tools
    "./features/my-company-tools": {}
  }
}
```

### Version Verification

Verify the versions you're running:

```bash
# Check image version
cat /etc/ror-version 2>/dev/null || echo "Version file not found"

# Check feature versions via labels
docker inspect --format='{{json .Config.Labels}}' $(docker ps -q) | jq .

# Verify image signature (recommended for production)
cosign verify ghcr.io/joshyorko/ror:v2.1.0 \
  --certificate-identity-regexp="https://github.com/joshyorko/room-of-requirement/*" \
  --certificate-oidc-issuer="https://token.actions.githubusercontent.com"
```

### Lock File Strategy

For maximum reproducibility, use `devcontainer-lock.json`:

```json
// .devcontainer/devcontainer-lock.json
{
  "features": {
    "ghcr.io/joshyorko/room-of-requirement/mise:1.0.0": {
      "integrity": "sha256:abc123...",
      "resolved": "ghcr.io/joshyorko/room-of-requirement/mise@sha256:abc123..."
    }
  }
}
```

This file is automatically maintained by the DevContainer tooling when you build.

### Upgrade Workflow

```bash
# 1. Check current versions
cat .devcontainer/devcontainer.json | jq '.features'

# 2. Check for available updates
# (Visit GHCR or use crane)
crane ls ghcr.io/joshyorko/room-of-requirement/mise

# 3. Update devcontainer.json with new versions

# 4. Rebuild container
devcontainer rebuild --workspace-folder .

# 5. Test changes
mise --version
starship --version
```

### Release Schedule

| Release Type | Frequency | What's Included |
|--------------|-----------|-----------------|
| Patch (x.y.Z) | As needed | Security fixes, bug fixes |
| Minor (x.Y.z) | Bi-weekly | New features, tool updates |
| Major (X.y.z) | Quarterly | Breaking changes |
| Stable Tag | Monthly | Validated minor release |

---

## Getting Help

- **Issues**: https://github.com/joshyorko/room-of-requirement/issues
- **Discussions**: https://github.com/joshyorko/room-of-requirement/discussions
- **Security**: security@joshyorko.com (for vulnerability reports)
