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
    elif [ -n "${target_owner:-}" ] && command -v sudo >/dev/null 2>&1 && sudo -n true >/dev/null 2>&1; then
        sudo "$@"
    else
        "$@"
    fi
}

target_owner=""
if getent passwd vscode >/dev/null 2>&1 && getent group vscode >/dev/null 2>&1; then
    target_owner="vscode:vscode"
fi

run_as_target() {
    if [ -z "${target_owner}" ] || [ "$(id -un)" = "vscode" ]; then
        "$@"
    else
        sudo -n -u vscode "$@"
    fi
}

path_exists() {
    run_as_root test -e "$1" || run_as_root test -L "$1"
}

set_exact_owner() {
    local target_path="$1"
    local original_mode

    [ -n "${target_owner}" ] || return 0
    original_mode="$(run_as_root stat -c '%a' "${target_path}")"
    run_as_root chown --no-dereference "${target_owner}" "${target_path}"
    if ! run_as_root test -L "${target_path}"; then
        run_as_root chmod "${original_mode}" "${target_path}"
    fi
}

ensure_single_dir() {
    local target_path="$1"
    local adopt_root_owner="$2"
    local target_uid

    if path_exists "${target_path}"; then
        run_as_root test -d "${target_path}" || {
            log "Cannot initialize ${target_path}: an existing non-directory blocks it"
            return 1
        }
        target_uid="$(run_as_root stat -c '%u' "${target_path}")"
        if [ "${adopt_root_owner}" = "1" ] && [ "${target_uid}" = "0" ]; then
            set_exact_owner "${target_path}"
        fi
    elif run_as_root mkdir -m 0755 -- "${target_path}" 2>/dev/null; then
        set_exact_owner "${target_path}"
    elif path_exists "${target_path}" && run_as_root test -d "${target_path}"; then
        # Another seeder created it first. Preserve the winner's metadata.
        :
    else
        log "Cannot initialize missing directory ${target_path}"
        return 1
    fi

    run_as_target test -x "${target_path}" || {
        log "Preserving inaccessible existing directory ${target_path}"
        return 2
    }
}

ensure_user_dir() {
    local target_path="$1"
    local adopt_final="${2:-0}"
    local relative_path
    local current_path
    local component
    local component_adopt

    case "${target_path}" in
        "${home_dir}" | "${home_dir}"/*) ;;
        *)
            log "Refusing to initialize path outside ${home_dir}: ${target_path}"
            return 1
            ;;
    esac

    ensure_single_dir "${home_dir}" 1 || return $?
    [ "${target_path}" != "${home_dir}" ] || return 0

    relative_path="${target_path#"${home_dir}"/}"
    current_path="${home_dir}"
    while IFS= read -r component; do
        [ -n "${component}" ] || continue
        current_path="${current_path}/${component}"
        component_adopt=0
        if [ "${current_path}" = "${target_path}" ]; then
            component_adopt="${adopt_final}"
        fi
        ensure_single_dir "${current_path}" "${component_adopt}" || return $?
    done < <(printf '%s\n' "${relative_path}" | tr '/' '\n')
}

seed_if_missing() {
    local source_path="$1"
    local target_path="$2"
    local parent_path
    local ensure_status
    local temporary_path

    [ -f "${source_path}" ] || return 0
    if path_exists "${target_path}"; then
        return 0
    fi

    parent_path="$(dirname "${target_path}")"
    if ensure_user_dir "${parent_path}"; then
        :
    else
        ensure_status=$?
        if [ "${ensure_status}" -eq 2 ]; then
            log "Skipping ${target_path}: its existing parent is inaccessible"
            return 0
        fi
        return "${ensure_status}"
    fi

    if path_exists "${target_path}"; then
        return 0
    fi

    temporary_path="$(run_as_root mktemp "${parent_path}/.ror-seed.XXXXXX")"
    if ! run_as_root cp -p -- "${source_path}" "${temporary_path}"; then
        run_as_root rm -f -- "${temporary_path}"
        return 1
    fi
    set_exact_owner "${temporary_path}"

    if run_as_root ln -- "${temporary_path}" "${target_path}" 2>/dev/null; then
        run_as_root rm -f -- "${temporary_path}"
        return 0
    fi

    run_as_root rm -f -- "${temporary_path}"
    if path_exists "${target_path}"; then
        # Another seeder won the exclusive create. Its file is authoritative.
        return 0
    fi

    log "Failed to create missing default ${target_path}"
    return 1
}

ensure_user_dir "${home_dir}"

seed_if_missing "${config_dir}/.zshrc" "${home_dir}/.zshrc"
seed_if_missing "${config_dir}/.bashrc" "${home_dir}/.bashrc"
seed_if_missing "${config_dir}/starship.toml" "${home_dir}/.config/starship.toml"
seed_if_missing "${config_dir}/mise.toml" "${home_dir}/.config/mise/config.toml"
seed_if_missing "${config_dir}/containers-storage.conf" "${home_dir}/.config/containers/storage.conf"

ensure_user_dir "${home_dir}/.local/share/mise" 1 || true
ensure_user_dir "${home_dir}/.zsh_history_dir" 1 || true
ensure_user_dir "${home_dir}/.npm" 1 || true
ensure_user_dir "${home_dir}/.local/share/containers/storage" 1 || true

log "standard home is ready"
