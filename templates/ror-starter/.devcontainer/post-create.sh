#!/bin/bash
# T062: Create post-create.sh for ror-starter Template
# Starter template post-create script - adapted from root post-create.sh

set -euo pipefail

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >&2
}

log "Starting project hydration..."

# T026: Brewfile installation
if [ -f ".devcontainer/Brewfile" ]; then
    log "Installing Homebrew dependencies..."
    if command -v brew &> /dev/null; then
        brew bundle install --file=.devcontainer/Brewfile || log "⚠ Some Homebrew packages failed"
    fi
fi

# T027: .mise.toml installation
if [ -f ".mise.toml" ]; then
    log "Installing tool versions from .mise.toml..."
    if command -v mise &> /dev/null; then
        mise install || log "⚠ Some mise tools failed"
    fi
fi

# T028: package.json installation
if [ -f "package.json" ]; then
    log "Installing Node.js dependencies..."
    if command -v pnpm &> /dev/null; then
        pnpm install || log "⚠ pnpm install had issues"
    elif command -v npm &> /dev/null; then
        npm install || log "⚠ npm install had issues"
    fi
fi

log "✓ Project hydration complete!"
