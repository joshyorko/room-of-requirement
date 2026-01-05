#!/bin/bash
# Fix Docker socket permissions for non-root access
# This script handles both Docker-in-Docker and Codespaces scenarios

set -e

log() {
    echo "[Docker Fix] $*" >&2
}

# Ensure user is in docker group
log "Adding vscode user to docker group..."
sudo usermod -aG docker vscode 2>/dev/null || true

# Check if we're in Codespaces
if [ -n "${CODESPACES:-}" ]; then
    log "Detected GitHub Codespaces environment"
    
    if [ -e /var/run/docker.sock ]; then
        log "Fixing Docker socket permissions for Codespaces..."
        
        # Get current socket info
        SOCKET_GROUP=$(stat -c '%G' /var/run/docker.sock 2>/dev/null || echo "unknown")
        SOCKET_PERMS=$(stat -c '%a' /var/run/docker.sock 2>/dev/null || echo "unknown")
        log "Current socket group: $SOCKET_GROUP, permissions: $SOCKET_PERMS"
        
        # Fix ownership and permissions
        sudo chown root:docker /var/run/docker.sock 2>/dev/null || {
            log "Warning: Could not change socket ownership, trying chmod only..."
        }
        sudo chmod 660 /var/run/docker.sock 2>/dev/null || {
            log "Warning: Could not change socket permissions"
        }
        
        log "Docker socket permissions updated"
    else
        log "Warning: Docker socket not found at /var/run/docker.sock"
    fi
else
    log "Not in Codespaces, checking if Docker daemon is running..."
    
    # Check if docker is accessible
    if docker info > /dev/null 2>&1; then
        log "Docker is already accessible"
    else
        log "Docker not accessible, attempting to start dockerd..."
        
        # Start dockerd in background if not running
        if ! pgrep -x dockerd > /dev/null; then
            log "Starting dockerd..."
            sudo sh -c 'nohup /usr/bin/dockerd-entrypoint.sh > /tmp/docker-init.log 2>&1 &'
            
            # Wait for socket to be created
            for i in {1..10}; do
                if [ -e /var/run/docker.sock ]; then
                    log "Docker socket created"
                    break
                fi
                log "Waiting for docker socket... ($i/10)"
                sleep 1
            done
            
            # Fix socket permissions
            if [ -e /var/run/docker.sock ]; then
                sudo chmod 660 /var/run/docker.sock 2>/dev/null || true
                log "Docker socket permissions fixed"
            fi
        fi
    fi
fi

# Verify Docker access
if docker info > /dev/null 2>&1; then
    log "✓ Docker is accessible without sudo"
    docker version --format '{{.Server.Version}}' 2>/dev/null | xargs -I {} log "Docker daemon version: {}"
else
    log "✗ Docker still not accessible. You may need to restart your shell or container."
    log "  Try: newgrp docker  (or restart your terminal)"
fi

exit 0