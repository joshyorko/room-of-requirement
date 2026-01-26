#!/bin/bash
# Fix Docker socket permissions for GitHub Codespaces
# In Codespaces, the Docker socket may have different group ownership
# This script ensures the vscode user can access Docker without sudo

set -e

log() {
    echo "[Docker Fix] $*" >&2
}

# Check if running in Codespaces
if [ -n "${CODESPACES:-}" ]; then
    log "Detected GitHub Codespaces environment"
    
    # Check if Docker socket exists
    if [ -S /var/run/docker.sock ]; then
        log "Fixing Docker socket permissions..."
        
        # Check and fix /var/run permissions if needed
        CURRENT_PERMS=$(stat -c '%a' /var/run 2>/dev/null || echo "000")
        if [ "$CURRENT_PERMS" != "755" ]; then
            if ! sudo chmod 755 /var/run 2>/dev/null; then
                log "Warning: Failed to set permissions on /var/run"
            fi
        fi
        
        # Fix socket permissions
        if ! sudo chown root:docker /var/run/docker.sock 2>/dev/null; then
            log "Warning: Failed to change ownership of Docker socket"
        fi
        if ! sudo chmod 660 /var/run/docker.sock 2>/dev/null; then
            log "Warning: Failed to set permissions on Docker socket"
        fi
        
        # Ensure vscode user is in docker group
        if ! sudo usermod -aG docker vscode 2>/dev/null; then
            log "Warning: Failed to add vscode user to docker group"
        fi
        
        log "✓ Docker socket permissions fixed"
        log "Run 'newgrp docker' or restart your shell to apply group changes"
    else
        log "Warning: Docker socket not found at /var/run/docker.sock"
    fi
else
    log "Not running in Codespaces - no action needed"
fi
