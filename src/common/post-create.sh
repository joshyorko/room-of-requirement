#!/bin/bash
# Post-create script for Room of Requirement DevContainer
# Hydrates dependencies declared by project Brewfiles, mise configuration,
# package.json, and the optional mise setup task.
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
MISE_CACHE_SEEDER="${ROR_MISE_CACHE_SEEDER:-/usr/local/bin/mise-seed-cache.sh}"
if [ -x "${MISE_CACHE_SEEDER}" ]; then
    "${MISE_CACHE_SEEDER}"
fi

# ============================================================================
# T026: Bluefin-Style Homebrew Setup
# ============================================================================
# Ensure Homebrew is in PATH
export PATH="/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:${PATH}"

project_brewfiles=()
for brewfile in Brewfile .devcontainer/Brewfile; do
    if [ -f "${brewfile}" ]; then
        project_brewfiles+=("${brewfile}")
    fi
done

if [ "${#project_brewfiles[@]}" -gt 0 ]; then
    command -v brew >/dev/null 2>&1 || error "Project Brewfile found but Homebrew is unavailable"
    for brewfile in "${project_brewfiles[@]}"; do
        log "Installing Homebrew dependencies from ${brewfile}"
        brew bundle install --file="${brewfile}"
        log "✓ Homebrew dependencies installed from ${brewfile}"
    done
else
    log "No project Brewfile found - skipping Homebrew dependency installation"
fi

# ============================================================================
# T027: .mise.toml Detection & Installation (Project-specific runtimes)
# ============================================================================
mise_config=""
for candidate in mise.toml .mise.toml; do
    if [ -f "${candidate}" ]; then
        mise_config="${candidate}"
        break
    fi
done

if [ -n "${mise_config}" ]; then
    log "Detected ${mise_config} - installing project-specific tool versions"
    command -v mise >/dev/null 2>&1 || error "Project mise config found but mise is unavailable"
    export MISE_RUBY_COMPILE=0
    mise install
    # Installation does not change this noninteractive shell's PATH. Capture
    # separately so an environment-resolution failure cannot be hidden by eval.
    project_env="$(mise env --shell bash)"
    eval "${project_env}"
    log "✓ mise dependencies installed successfully"
else
    log "No project mise config found - skipping tool installation"
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
            pnpm install --frozen-lockfile
            log "✓ pnpm dependencies installed"
        else
            error "pnpm lockfile detected but pnpm is unavailable"
        fi
    elif [ -f "yarn.lock" ]; then
        if command -v yarn &> /dev/null; then
            log "Installing with yarn"
            yarn install --frozen-lockfile
            log "✓ yarn dependencies installed"
        else
            error "yarn lockfile detected but yarn is unavailable"
        fi
    elif [ -f "package-lock.json" ]; then
        if command -v npm &> /dev/null; then
            log "Installing with npm"
            npm ci
            log "✓ npm dependencies installed"
        else
            error "npm lockfile detected but npm is unavailable"
        fi
    else
        # No lockfile, use default package manager
        if command -v pnpm &> /dev/null; then
            log "Installing with pnpm"
            pnpm install
        elif command -v yarn &> /dev/null; then
            log "Installing with yarn"
            yarn install
        elif command -v npm &> /dev/null; then
            log "Installing with npm"
            npm install
        else
            error "package.json found but no Node.js package manager is available"
        fi
        log "✓ Node.js dependencies installed"
    fi
else
    log "No package.json found - skipping Node.js dependency installation"
fi

# ============================================================================
# T029: mise Setup Task Detection & Execution
# ============================================================================
if [ -n "${mise_config}" ]; then
    # Keep discovery failure fatal, and do not run an unrelated global setup.
    project_tasks="$(mise tasks ls --local --name-only)"
    if grep -Fxq "setup" <<< "${project_tasks}"; then
        log "Found mise setup task - executing"
        mise run setup
        log "✓ mise setup task completed successfully"
    fi
fi

# ============================================================================
# COMPLETION
# ============================================================================
log "✓ Post-create hydration completed successfully"
log ""
log "Environment ready! You can now:"
log "  • Run 'ujust bbrew' to install optional curated bundles"
log "  • Run 'ujust runtime-defaults' to install global language defaults"
log "  • Re-run 'ujust brew-install-all' if you want to hydrate every Brewfile"
log "  • Run 'ujust' to see all available commands"
log "  • Run 'mise --version' to verify tool management"
log "  • Run 'docker info' to check Docker status"

exit 0
