#!/bin/bash
# DevContainer entrypoint wrapper for Docker-in-Docker
# Starts dockerd as root (via sudo), then runs CMD as vscode user
# Handles both standard DevContainers and GitHub Codespaces

set -e

log() {
    echo "[Entrypoint] $*" >&2
}

# Ensure vscode user is in docker group
sudo usermod -aG docker vscode 2>/dev/null || true

# GitHub Codespaces provides its own Docker daemon - don't start another
if [ -n "${CODESPACES:-}" ]; then
    log "Detected GitHub Codespaces environment"

    # Wait for Codespaces Docker socket (provided by host)
    for i in $(seq 1 30); do
        if [ -S /var/run/docker.sock ]; then
            log "Docker socket found"
            break
        fi
        [ "$i" -eq 30 ] && log "Warning: Docker socket not found after 30s"
        sleep 1
    done

    # Fix socket permissions for vscode user
    if [ -S /var/run/docker.sock ]; then
        SOCKET_GROUP=$(stat -c '%G' /var/run/docker.sock 2>/dev/null || echo "unknown")
        log "Current socket group: $SOCKET_GROUP"
        sudo chown root:docker /var/run/docker.sock 2>/dev/null || true
        sudo chmod 660 /var/run/docker.sock 2>/dev/null || true
        log "Docker socket permissions updated"
    fi
else
    # Standard Docker-in-Docker: start dockerd ourselves
    log "Starting Docker daemon..."

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
