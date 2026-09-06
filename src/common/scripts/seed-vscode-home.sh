#!/bin/bash
set -euo pipefail

# Populate only image-provided defaults in the standard vscode home. The
# optional arguments are used by the contract test; normal image startup uses
# the standard paths below.
home_dir="${1:-/home/vscode}"
config_dir="${2:-/usr/share/ror/config}"

log() {
    echo "[vscode-home] $*" >&2
}

run_as_root() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    elif command -v sudo >/dev/null 2>&1 && sudo -n true >/dev/null 2>&1; then
        sudo "$@"
    else
        "$@"
    fi
}

target_owner=""
if getent passwd vscode >/dev/null 2>&1 && getent group vscode >/dev/null 2>&1; then
    target_owner="vscode:vscode"
fi

set_exact_owner() {
    local target_path="$1"
    local original_mode

    [ -n "${target_owner}" ] || return 0
    original_mode="$(stat -c '%a' "${target_path}")"
    run_as_root chown --no-dereference "${target_owner}" "${target_path}"
    if [ ! -L "${target_path}" ]; then
        run_as_root chmod "${original_mode}" "${target_path}"
    fi
}

ensure_user_dir() {
    local target_path="$1"

    if [ ! -d "${target_path}" ]; then
        if [ -n "${target_owner}" ]; then
            run_as_root install -d -m 0755 -o vscode -g vscode "${target_path}"
        else
            run_as_root mkdir -p "${target_path}"
        fi
    elif [ "$(stat -c '%u' "${target_path}")" = "0" ]; then
        # Named-volume roots can arrive owned by root. Adjust only the mount
        # root itself; descendant ownership can encode rootless ID mappings.
        set_exact_owner "${target_path}"
    fi
}

seed_if_missing() {
    local source_path="$1"
    local target_path="$2"

    [ -f "${source_path}" ] || return 0
    if [ -e "${target_path}" ] || [ -L "${target_path}" ]; then
        return 0
    fi

    ensure_user_dir "$(dirname "${target_path}")"
    run_as_root cp -p "${source_path}" "${target_path}"
    set_exact_owner "${target_path}"
}

ensure_user_dir "${home_dir}"

seed_if_missing "${config_dir}/.zshrc" "${home_dir}/.zshrc"
seed_if_missing "${config_dir}/.bashrc" "${home_dir}/.bashrc"
seed_if_missing "${config_dir}/starship.toml" "${home_dir}/.config/starship.toml"
seed_if_missing "${config_dir}/mise.toml" "${home_dir}/.config/mise/config.toml"
seed_if_missing "${config_dir}/containers-storage.conf" "${home_dir}/.config/containers/storage.conf"

ensure_user_dir "${home_dir}/.local/share/mise"
ensure_user_dir "${home_dir}/.zsh_history_dir"
ensure_user_dir "${home_dir}/.npm"
ensure_user_dir "${home_dir}/.local/share/containers/storage"

log "standard home is ready"
