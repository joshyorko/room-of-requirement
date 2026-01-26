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
        
        # Ensure /var/run is traversable
        sudo chmod 755 /var/run 2>/dev/null || true
        
        # Fix socket permissions
        sudo chown root:docker /var/run/docker.sock 2>/dev/null || true
        sudo chmod 660 /var/run/docker.sock 2>/dev/null || true
        
        # Ensure vscode user is in docker group
        sudo usermod -aG docker vscode 2>/dev/null || true
        
        log "✓ Docker socket permissions fixed"
        log "Run 'newgrp docker' or restart your shell to apply group changes"
    else
        log "Warning: Docker socket not found at /var/run/docker.sock"
    fi
else
    log "Not running in Codespaces - no action needed"
fi
