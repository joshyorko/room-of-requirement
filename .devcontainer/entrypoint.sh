#!/bin/bash
# DevContainer entrypoint wrapper for Docker-in-Docker
# Starts dockerd as root (via sudo), then runs CMD as vscode user
# Handles both standard DevContainers and GitHub Codespaces

set -e

log() {
    echo "[Entrypoint] $*" >&2
}

# Runtime selection:
# - auto (default): prefer DinD on Codespaces for k3d/kind reliability
# - dind: always use internal Docker daemon
# - host: always use host-provided Docker socket
DOCKER_BACKEND="${ROR_DOCKER_BACKEND:-auto}"

# Remove gcompat from apk world file if present
# VS Code/DevPod may try to add gcompat for musl compatibility, but Wolfi uses native glibc
# This must run early before any apk update/upgrade operations
sudo sed -i '/gcompat/d' /etc/apk/world 2>/dev/null || true

# Ensure vscode user is in docker group
sudo usermod -aG docker vscode 2>/dev/null || true

# Ensure user-owned writable directories for volume mounts/caches
# Named volumes may be created as root-owned (especially in Codespaces),
# which can break shell history, mise, npm, etc.
fix_user_dir_permissions() {
    local dir_path="$1"
    local dir_label="$2"

    if [ ! -d "$dir_path" ]; then
        log "Creating ${dir_label} directory..."
        sudo mkdir -p "$dir_path" 2>/dev/null || {
            log "Warning: Failed to create ${dir_label} directory at $dir_path"
            return
        }
    fi

    log "Ensuring ${dir_label} permissions..."
    sudo chown -R vscode:vscode "$dir_path" 2>/dev/null || log "Warning: Failed to chown $dir_path"
    sudo chmod -R u+rwX "$dir_path" 2>/dev/null || log "Warning: Failed to chmod $dir_path"
}

# Fix common writable paths early before shells/tools initialize
fix_user_dir_permissions "${HOME}/.local/share/mise" "mise cache"
fix_user_dir_permissions "${HOME}/.zsh_history_dir" "zsh history"
fix_user_dir_permissions "${HOME}/.npm" "npm cache"

# Function to start Wolfi's native dockerd
start_dockerd() {
    local docker_socket="${1:-/var/run/docker.sock}"
    local docker_host="unix://${docker_socket}"

    log "Starting Docker daemon (Wolfi native) on ${docker_socket}..."

    # Ensure /var/run is accessible (755) - dockerd creates it with 700 by default
    # which blocks non-root users from accessing the socket even with correct group membership
    if [ -d /var/run ]; then
        sudo chmod 755 /var/run
    else
        sudo mkdir -p /var/run
        sudo chmod 755 /var/run
    fi

    sudo mkdir -p "$(dirname "${docker_socket}")"

    if [ -x /usr/bin/dockerd-entrypoint.sh ]; then
        # Start dockerd-entrypoint.sh in background as root
        sudo /usr/bin/dockerd-entrypoint.sh dockerd --host="${docker_host}" &
        DOCKERD_PID=$!

        # Wait for Docker socket (max 30 seconds)
        for i in $(seq 1 30); do
            if [ -S "${docker_socket}" ]; then
                log "Docker daemon is ready"
                break
            fi
            [ "$i" -eq 30 ] && log "Warning: Docker daemon didn't start in 30s"
            sleep 1
        done

        # Fix socket permissions for vscode user
        if [ -S "${docker_socket}" ]; then
            sudo chown root:docker "${docker_socket}" 2>/dev/null || true
            sudo chmod 660 "${docker_socket}" 2>/dev/null || true
        fi

        # Ensure all child processes (including shells/tasks) use the selected socket.
        export DOCKER_HOST="${docker_host}"
        log "DOCKER_HOST set to ${DOCKER_HOST}"
    else
        log "Warning: dockerd-entrypoint.sh not found"
    fi
}

# GitHub Codespaces may or may not provide Docker - check first, then fallback.
# In Codespaces we prefer DinD by default because host socket behavior can differ
# and break nested container workloads like k3d.
if [ -n "${CODESPACES:-}" ]; then
    log "Detected GitHub Codespaces environment"

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

    if [ "${DOCKER_BACKEND}" = "dind" ] || [ "${DOCKER_BACKEND}" = "auto" ]; then
        log "Using internal DinD backend in Codespaces"
        # Avoid clashing with host-mounted /var/run/docker.sock.
        start_dockerd "/tmp/ror-docker.sock"
    elif [ "$SOCKET_FOUND" = true ]; then
        # Ensure /var/run is traversable (Codespaces may have restrictive permissions)
        sudo chmod 755 /var/run 2>/dev/null || true
        # Fix socket permissions for vscode user
        SOCKET_GROUP=$(stat -c '%G' /var/run/docker.sock 2>/dev/null || echo "unknown")
        log "Current socket group: $SOCKET_GROUP"
        sudo chown root:docker /var/run/docker.sock 2>/dev/null || true
        sudo chmod 660 /var/run/docker.sock 2>/dev/null || true
        export DOCKER_HOST="unix:///var/run/docker.sock"
        log "Docker socket permissions updated"
    else
        # No socket from Codespaces host - start our own dockerd
        log "No Docker socket from Codespaces host, starting Wolfi dockerd..."
        start_dockerd "/var/run/docker.sock"
    fi
else
    if [ "${DOCKER_BACKEND}" = "host" ] && [ -S /var/run/docker.sock ]; then
        export DOCKER_HOST="unix:///var/run/docker.sock"
        log "Using host Docker socket"
    else
        # Standard Docker-in-Docker (DevPod, local, etc): start dockerd ourselves
        start_dockerd "/var/run/docker.sock"
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
