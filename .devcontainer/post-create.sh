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
# T026: Brewfile Detection & Installation
# ============================================================================
if [ -f "Brewfile" ]; then
    log "Detected Brewfile - installing Homebrew dependencies"

    if ! command -v brew &> /dev/null; then
        warn "Homebrew not found in PATH, skipping Brewfile installation"
    else
        if brew bundle check --file=Brewfile > /dev/null 2>&1; then
            log "Brewfile dependencies already satisfied"
        else
            log "Installing Brewfile dependencies"
            if brew bundle install --file=Brewfile; then
                log "✓ Brewfile dependencies installed successfully"
            else
                warn "Some Brewfile dependencies may have failed to install"
            fi
        fi
    fi
elif [ -f ".devcontainer/Brewfile" ]; then
    log "Detected .devcontainer/Brewfile - installing Homebrew dependencies"

    if command -v brew &> /dev/null; then
        if brew bundle check --file=.devcontainer/Brewfile > /dev/null 2>&1; then
            log "Brewfile dependencies already satisfied"
        else
            log "Installing Brewfile dependencies from .devcontainer/Brewfile"
            if brew bundle install --file=.devcontainer/Brewfile; then
                log "✓ Brewfile dependencies installed successfully"
            else
                warn "Some Brewfile dependencies may have failed to install"
            fi
        fi
    fi
else
    log "No Brewfile found - skipping Homebrew installation"
fi

# ============================================================================
# T027: .mise.toml Detection & Installation
# ============================================================================
if [ -f ".mise.toml" ]; then
    log "Detected .mise.toml - installing tool versions"

    if ! command -v mise &> /dev/null; then
        warn "mise not found in PATH, skipping mise install"
    else
        log "Installing mise dependencies"
        if mise install; then
            log "✓ mise dependencies installed successfully"
        else
            warn "Some mise dependencies may have failed to install"
        fi
    fi
else
    log "No .mise.toml found - using default mise configuration"
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
log "  • Run 'mise --version' to verify tool management"
log "  • Run 'which node' to check Node.js installation"
log "  • Run 'which python' to check Python installation"
log "  • Run 'starship bug' to verify Starship configuration"
log "  • Run 'z' to test zoxide navigation"

exit 0
