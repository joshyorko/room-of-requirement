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

# Prepare rootless Podman without changing Docker's startup contract. The
# runtime directory follows the effective vscode UID because Dev Containers
# may remap it at launch, and persistent storage may arrive root-owned.
prepare_podman_runtime() {
    command -v podman >/dev/null 2>&1 || return 0
    id vscode >/dev/null 2>&1 || return 0

    local vscode_uid
    local runtime_dir
    local podman_storage
    vscode_uid="$(id -u vscode)"
    runtime_dir="/run/user/${vscode_uid}"
    podman_storage="${HOME}/.local/share/containers/storage"

    run_as_root mkdir -p "${runtime_dir}" "${podman_storage}" 2>/dev/null || {
        log "Warning: Failed to create Podman runtime or storage directories"
        return 0
    }
    run_as_root chown vscode:vscode "${runtime_dir}" 2>/dev/null || \
        log "Warning: Failed to chown Podman runtime or storage directories"
    run_as_root chown -R vscode:vscode "${podman_storage}" 2>/dev/null || \
        log "Warning: Failed to chown Podman storage contents"
    run_as_root chmod 700 "${runtime_dir}" 2>/dev/null || \
        log "Warning: Failed to restrict Podman runtime directory"
    export XDG_RUNTIME_DIR="${runtime_dir}"

    if command -v mount >/dev/null 2>&1; then
        run_as_root mount --make-rshared / 2>/dev/null || \
            log "Warning: Could not make root mount recursively shared"
    fi
}

prepare_podman_runtime

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
