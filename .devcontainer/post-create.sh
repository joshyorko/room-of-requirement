#!/bin/bash
# Post-create script for Room of Requirement DevContainer
# Hydrates project with dependencies from Brewfile, .mise.toml, package.json
# T026-T030: Project hydration implementation

set -euo pipefail

# ============================================================================
# LOGGING & ERROR HANDLING
# ============================================================================
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >&2
}

error() {
    log "ERROR: $*"
    exit 1
}

warn() {
    log "WARNING: $*"
}

# ============================================================================
# INITIALIZATION
# ============================================================================
log "Starting post-create hydration script"

WORKSPACE_DIR="${1:-.}"
cd "$WORKSPACE_DIR" || error "Failed to change to workspace directory"

# ============================================================================
# T026: Bluefin-Style Homebrew Setup
# ============================================================================
# Ensure Homebrew is in PATH
export PATH="/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:${PATH}"

if ! command -v brew &> /dev/null; then
    warn "Homebrew not found in PATH, skipping Homebrew setup"
else
    log "Homebrew found at $(which brew)"

    # Update Homebrew to get latest formulae (image may have stale index)
    # This ensures new packages like container-use from taps are discoverable
    log "Updating Homebrew formulae index..."
    if brew update --quiet; then
        log "✓ Homebrew updated to $(brew --version | head -1)"
    else
        warn "Homebrew update had issues, continuing with existing formulae"
    fi

    # =========================================================================
    # CORE SHELL TOOLS - Pre-installed in image
    # =========================================================================
    # mise, starship, zoxide, nushell are now baked into the image
    # Verify they're available
    for tool in mise starship zoxide nu; do
        if command -v "$tool" &> /dev/null; then
            log "✓ $tool available"
        else
            warn "$tool not found - may need image rebuild"
        fi
    done

    # =========================================================================
    # MISE: Install project-specific runtimes if .mise.toml exists
    # =========================================================================
    # Default runtimes (node@lts, python@latest, go@latest) are already
    # configured globally in the image. This only runs for project overrides.

    # =========================================================================
    # BBREW TUI - For on-demand package management
    # =========================================================================
    if ! command -v bbrew &> /dev/null; then
        log "Installing bbrew (Bold Brew TUI) for on-demand package management..."
        if brew tap valkyrie00/bbrew && brew install valkyrie00/bbrew/bbrew; then
            log "✓ bbrew installed - use 'ujust bbrew' to install packages"
        else
            warn "Failed to install bbrew - packages can still be installed via 'ujust brew-install-all'"
        fi
    else
        log "✓ bbrew already installed"
    fi

    # NOTE: zsh plugins (autosuggestions, syntax-highlighting) are now managed by
    # zinit in .zshrc - no need to install via Homebrew
fi

# ============================================================================
# T027: .mise.toml Detection & Installation (Project-specific runtimes)
# ============================================================================
if [ -f ".mise.toml" ]; then
    log "Detected .mise.toml - installing project-specific tool versions"

    if ! command -v mise &> /dev/null; then
        warn "mise not found in PATH, skipping mise install"
    else
        log "Installing mise dependencies from .mise.toml"
        if mise install; then
            log "✓ mise dependencies installed successfully"
        else
            warn "Some mise dependencies may have failed to install"
        fi
    fi
else
    log "No .mise.toml found - using default mise runtimes"
fi

# ============================================================================
# T028: package.json Detection & Installation
# ============================================================================
if [ -f "package.json" ]; then
    log "Detected package.json - installing Node.js dependencies"

    # Determine package manager
    if [ -f "pnpm-lock.yaml" ]; then
        if command -v pnpm &> /dev/null; then
            log "Installing with pnpm"
            pnpm install --frozen-lockfile || warn "pnpm install had issues"
            log "✓ pnpm dependencies installed"
        else
            warn "pnpm lockfile detected but pnpm not found"
        fi
    elif [ -f "yarn.lock" ]; then
        if command -v yarn &> /dev/null; then
            log "Installing with yarn"
            yarn install --frozen-lockfile || warn "yarn install had issues"
            log "✓ yarn dependencies installed"
        else
            warn "yarn lockfile detected but yarn not found"
        fi
    elif [ -f "package-lock.json" ]; then
        if command -v npm &> /dev/null; then
            log "Installing with npm"
            npm ci || warn "npm install had issues"
            log "✓ npm dependencies installed"
        else
            warn "npm lockfile detected but npm not found"
        fi
    else
        # No lockfile, use default package manager
        if command -v pnpm &> /dev/null; then
            log "Installing with pnpm"
            pnpm install || warn "pnpm install had issues"
        elif command -v yarn &> /dev/null; then
            log "Installing with yarn"
            yarn install || warn "yarn install had issues"
        elif command -v npm &> /dev/null; then
            log "Installing with npm"
            npm install || warn "npm install had issues"
        else
            warn "No package manager found (npm, yarn, pnpm)"
        fi
    fi
else
    log "No package.json found - skipping Node.js dependency installation"
fi

# ============================================================================
# T029: mise Setup Task Detection & Execution
# ============================================================================
if command -v mise &> /dev/null && [ -f ".mise.toml" ]; then
    # Check if there's a setup task defined
    if mise task ls 2>/dev/null | grep -q "setup"; then
        log "Found mise setup task - executing"
        if mise run setup; then
            log "✓ mise setup task completed successfully"
        else
            warn "mise setup task had issues"
        fi
    fi
fi

# ============================================================================
# COMPLETION
# ============================================================================
log "✓ Post-create hydration completed successfully"
log ""
log "Environment ready! You can now:"
log "  • Run 'ujust bbrew' to launch Bold Brew TUI and install packages"
log "  • Run 'ujust brew-install-all' to install all packages from Brewfile"
log "  • Run 'ujust' to see all available commands"
log "  • Run 'mise --version' to verify tool management"
log "  • Run 'docker info' to check Docker status"

exit 0
