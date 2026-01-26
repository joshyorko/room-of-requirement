#!/bin/bash
# DevContainer entrypoint wrapper for Docker-in-Docker
# Starts dockerd as root (via sudo), then runs CMD as vscode user
# Handles both standard DevContainers and GitHub Codespaces

set -e

log() {
    echo "[Entrypoint] $*" >&2
}

# Remove gcompat from apk world file if present
# VS Code/DevPod may try to add gcompat for musl compatibility, but Wolfi uses native glibc
# This must run early before any apk update/upgrade operations
sudo sed -i '/gcompat/d' /etc/apk/world 2>/dev/null || true

# Ensure vscode user is in docker group
sudo usermod -aG docker vscode 2>/dev/null || true

# Function to start Wolfi's native dockerd
start_dockerd() {
    log "Starting Docker daemon (Wolfi native)..."

    # Ensure /var/run is accessible (755) - dockerd creates it with 700 by default
    # which blocks non-root users from accessing the socket even with correct group membership
    if [ -d /var/run ]; then
        sudo chmod 755 /var/run
    else
        sudo mkdir -p /var/run
        sudo chmod 755 /var/run
    fi

    if [ -x /usr/bin/dockerd-entrypoint.sh ]; then
        # Start dockerd-entrypoint.sh in background as root
        sudo /usr/bin/dockerd-entrypoint.sh dockerd &
        DOCKERD_PID=$!

        # Wait for Docker socket (max 30 seconds)
        for i in $(seq 1 30); do
            if [ -S /var/run/docker.sock ]; then
                log "Docker daemon is ready"
                break
            fi
            [ "$i" -eq 30 ] && log "Warning: Docker daemon didn't start in 30s"
            sleep 1
        done

        # Fix socket permissions for vscode user
        if [ -S /var/run/docker.sock ]; then
            sudo chown root:docker /var/run/docker.sock 2>/dev/null || true
            sudo chmod 660 /var/run/docker.sock 2>/dev/null || true
        fi
    else
        log "Warning: dockerd-entrypoint.sh not found"
    fi
}

# GitHub Codespaces may or may not provide Docker - check first, then fallback
if [ -n "${CODESPACES:-}" ]; then
    log "Detected GitHub Codespaces environment"

    # Fix mise cache directory permissions (Codespaces volume mounts often have root ownership)
    MISE_CACHE_DIR="${HOME}/.local/share/mise"
    # Create directory if it doesn't exist to ensure permissions are set
    if [ ! -d "$MISE_CACHE_DIR" ]; then
        log "Creating mise cache directory..."
        sudo mkdir -p "$MISE_CACHE_DIR" 2>/dev/null || log "Warning: Failed to create mise cache directory"
    fi
    
    if [ -d "$MISE_CACHE_DIR" ]; then
        log "Fixing mise cache directory permissions..."
        if ! sudo chown -R vscode:vscode "$MISE_CACHE_DIR" 2>/dev/null; then
            log "Warning: Failed to change ownership of mise cache directory"
        fi
        if ! sudo chmod -R u+rwX "$MISE_CACHE_DIR" 2>/dev/null; then
            log "Warning: Failed to set permissions on mise cache directory"
        fi
    fi

    # Brief wait for Codespaces Docker socket (if host provides one)
    SOCKET_FOUND=false
    for i in $(seq 1 5); do
        if [ -S /var/run/docker.sock ]; then
            log "Docker socket found from Codespaces host"
            SOCKET_FOUND=true
            break
        fi
        sleep 1
    done

    if [ "$SOCKET_FOUND" = true ]; then
        # Ensure /var/run is traversable (Codespaces may have restrictive permissions)
        sudo chmod 755 /var/run 2>/dev/null || true
        # Fix socket permissions for vscode user
        SOCKET_GROUP=$(stat -c '%G' /var/run/docker.sock 2>/dev/null || echo "unknown")
        log "Current socket group: $SOCKET_GROUP"
        sudo chown root:docker /var/run/docker.sock 2>/dev/null || true
        sudo chmod 660 /var/run/docker.sock 2>/dev/null || true
        log "Docker socket permissions updated"
    else
        # No socket from Codespaces host - start our own dockerd
        log "No Docker socket from Codespaces host, starting Wolfi dockerd..."
        start_dockerd
    fi
else
    # Standard Docker-in-Docker (DevPod, local, etc): start dockerd ourselves
    start_dockerd
fi

# Verify Docker access
if sg docker -c "docker info" > /dev/null 2>&1; then
    DOCKER_VERSION=$(sg docker -c "docker version --format '{{.Server.Version}}'" 2>/dev/null || echo "unknown")
    log "✓ Docker ready (version: $DOCKER_VERSION)"
elif docker info > /dev/null 2>&1; then
    log "✓ Docker ready"
else
    log "⚠ Docker not accessible yet - may need 'newgrp docker' in new terminals"
fi

# Execute CMD as current user (vscode)
exec "$@"
