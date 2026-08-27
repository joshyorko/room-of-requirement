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

seed_if_missing() {
    local source_path="$1"
    local target_path="$2"

    [ -f "${source_path}" ] || return 0
    if [ -e "${target_path}" ] || [ -L "${target_path}" ]; then
        return 0
    fi

    run_as_root mkdir -p "$(dirname "${target_path}")"
    run_as_root cp -p "${source_path}" "${target_path}"
}

if [ ! -d "${home_dir}" ]; then
    run_as_root mkdir -p "${home_dir}"
fi

seed_if_missing "${config_dir}/.zshrc" "${home_dir}/.zshrc"
seed_if_missing "${config_dir}/.bashrc" "${home_dir}/.bashrc"
seed_if_missing "${config_dir}/starship.toml" "${home_dir}/.config/starship.toml"
seed_if_missing "${config_dir}/mise.toml" "${home_dir}/.config/mise/config.toml"

# PVCs and named volumes can be initialized by root. Reconcile ownership but
# intentionally leave every existing permission bit unchanged.
if getent passwd vscode >/dev/null 2>&1 && getent group vscode >/dev/null 2>&1; then
    run_as_root chown -R vscode:vscode "${home_dir}"
fi

# A mount can expose a restrictive root directory even after ownership is
# corrected. Grant the owner access without changing group/other permissions.
run_as_root chmod u+rwX "${home_dir}"

log "standard home is ready"
