#!/bin/bash
# Post-create script for Room of Requirement DevContainer
# Hydrates project with RoR defaults plus project dependencies from .mise.toml,
# package.json, and related setup hooks.
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
# MISE CACHE SEEDING
# ============================================================================
# Seed the user mise cache if a system-level runtime seed exists.
# On slimmer images this is a no-op, but we keep the hook so derived images can
# still pre-populate runtimes if they choose to.
if [ -x /usr/local/bin/mise-seed-cache.sh ]; then
    /usr/local/bin/mise-seed-cache.sh
fi

# ============================================================================
# T026: Bluefin-Style Homebrew Setup
# ============================================================================
# Ensure Homebrew is in PATH
export PATH="/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:${PATH}"

if ! command -v brew &> /dev/null; then
    warn "Homebrew not found in PATH, skipping Homebrew setup"
else
    log "Homebrew found at $(which brew)"

    # Update Homebrew to get latest formulae/tap metadata before bundle hydration
    log "Updating Homebrew formulae index..."
    if brew update --quiet; then
        log "✓ Homebrew updated to $(brew --version | head -1)"
    else
        warn "Homebrew update had issues, continuing with existing formulae"
    fi

    # Hydrate only the RoR developer bundle during post-create. The other
    # curated Brewfiles stay opt-in via `ujust bbrew` or `ujust brew-install-all`.
    ROR_BREWFILE="${ROR_BREWFILE:-/usr/share/ror/brew/ror.Brewfile}"
    if [ ! -f "$ROR_BREWFILE" ] && [ -f ".devcontainer/brew/ror.Brewfile" ]; then
        ROR_BREWFILE=".devcontainer/brew/ror.Brewfile"
    fi

    if [ -f "$ROR_BREWFILE" ]; then
        log "Ensuring tap is available: joshyorko/tools"
        if brew tap joshyorko/tools; then
            log "✓ Tap ready: joshyorko/tools"
        else
            warn "Unable to tap joshyorko/tools before RoR bundle install"
        fi

        log "Installing Homebrew bundle: $(basename "$ROR_BREWFILE")"
        if brew bundle install --file="$ROR_BREWFILE"; then
            log "✓ Installed $(basename "$ROR_BREWFILE")"
        else
            warn "Homebrew bundle had issues: $(basename "$ROR_BREWFILE")"
        fi

        # brew bundle ensures desired packages are installed, but it does not
        # reliably upgrade existing tap-hosted casks. Refresh the RoR tap tools
        # explicitly so containers pick up newer RCC and Action Server releases.
        log "Refreshing tap-hosted RoR tools to latest available revisions"
        for tool_cask in joshyorko/tools/rcc joshyorko/tools/action-server; do
            if brew list --cask "$tool_cask" >/dev/null 2>&1; then
                if brew upgrade --cask "$tool_cask"; then
                    log "✓ Upgraded cask: $tool_cask"
                else
                    warn "Failed to upgrade cask: $tool_cask"
                fi
            else
                warn "Expected cask not installed after bundle: $tool_cask"
            fi
        done

        if brew list --formula joshyorko/tools/t3code-cli-main >/dev/null 2>&1; then
            if brew upgrade joshyorko/tools/t3code-cli-main; then
                log "✓ Upgraded formula: joshyorko/tools/t3code-cli-main"
            else
                warn "Failed to upgrade formula: joshyorko/tools/t3code-cli-main"
            fi
        else
            warn "Expected formula not installed after bundle: joshyorko/tools/t3code-cli-main"
        fi
    else
        warn "No RoR Brewfile found, skipping Homebrew bundle hydration"
    fi

    # =========================================================================
    # MISE: Install Global Runtimes (cached via volume mount)
    # =========================================================================
    # Install default runtimes - these are cached in the mise volume for fast restarts
    log "Installing global language runtimes (node, python, go, ruby)..."
    # Ensure mise is active for this session
    export MISE_RUBY_COMPILE=0
    eval "$(mise activate bash)"

    mise install node@lts python@latest go@latest ruby@latest

    # Update npm to latest to fix potential vulnerabilities
    log "Updating npm to latest..."
    mise exec -- npm install -g npm@latest 2>/dev/null || warn "npm update had issues"
    mise exec -- npm cache clean --force 2>/dev/null || true

    log "✓ Core runtimes installed and cached via mise"
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
        export MISE_RUBY_COMPILE=0
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
log "  • Run 'ujust bbrew' to install optional curated bundles"
log "  • Re-run 'ujust brew-install-all' if you want to hydrate every Brewfile"
log "  • Run 'ujust' to see all available commands"
log "  • Run 'mise --version' to verify tool management"
log "  • Run 'docker info' to check Docker status"
log ""
log "Note: If Docker requires sudo, try 'bash /usr/local/bin/fix-docker-permissions.sh'"
log "      or restart your shell with 'newgrp docker'"

exit 0
