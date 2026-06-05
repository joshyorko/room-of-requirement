#!/bin/bash
# Lightweight DevContainer entrypoint.
# Docker is owned by the Dev Container Docker-in-Docker feature when present.

set -e

log() {
    echo "[Entrypoint] $*" >&2
}

run_as_root() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    else
        sudo "$@"
    fi
}

if command -v apk >/dev/null 2>&1; then
    run_as_root sed -i '/gcompat/d' /etc/apk/world 2>/dev/null || true
fi

if id vscode >/dev/null 2>&1 && getent group docker >/dev/null 2>&1; then
    run_as_root usermod -aG docker vscode 2>/dev/null || true
fi

# Ensure user-owned writable directories for volume mounts/caches
# Named volumes may be created as root-owned (especially in Codespaces),
# which can break shell history, mise, npm, etc.
fix_user_dir_permissions() {
    local dir_path="$1"
    local dir_label="$2"

    if [ ! -d "$dir_path" ]; then
        log "Creating ${dir_label} directory..."
        run_as_root mkdir -p "$dir_path" 2>/dev/null || {
            log "Warning: Failed to create ${dir_label} directory at $dir_path"
            return
        }
    fi

    log "Ensuring ${dir_label} permissions..."
    run_as_root chown -R vscode:vscode "$dir_path" 2>/dev/null || log "Warning: Failed to chown $dir_path"
    run_as_root chmod -R u+rwX "$dir_path" 2>/dev/null || log "Warning: Failed to chmod $dir_path"
}

# Fix common writable paths early before shells/tools initialize
fix_user_dir_permissions "${HOME}/.local/share/mise" "mise cache"
fix_user_dir_permissions "${HOME}/.zsh_history_dir" "zsh history"
fix_user_dir_permissions "${HOME}/.npm" "npm cache"

if [ -x /usr/local/share/docker-init.sh ] && [ "${ROR_USE_DEVCONTAINER_DOCKER_INIT:-1}" != "0" ]; then
    log "Delegating Docker startup to Dev Container Docker-in-Docker feature"
    exec /usr/local/share/docker-init.sh "$@"
fi

if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    log "Docker ready"
elif [ -x /usr/local/bin/ror-docker-start.sh ] && command -v dockerd >/dev/null 2>&1; then
    log "Starting Docker with Room of Requirement fallback starter"
    /usr/local/bin/ror-docker-start.sh --socket /var/run/docker.sock
else
    log "Docker feature init not found; continuing without starting Docker"
fi

# Execute CMD as current user (vscode)
exec "$@"
