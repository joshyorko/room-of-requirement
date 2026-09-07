#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SEEDER="${ROOT_DIR}/src/common/scripts/seed-vscode-home.sh"
REQUIRE_FIXTURE="${ROR_REQUIRE_PRIVILEGED_OWNERSHIP_TEST:-0}"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

skip_or_fail() {
    local reason="$1"
    if [ "${REQUIRE_FIXTURE}" = "1" ]; then
        fail "privileged ownership test prerequisite missing: ${reason}"
    fi
    echo "SKIP: privileged ownership test requires ${reason}"
    exit 0
}

getent passwd vscode >/dev/null 2>&1 || skip_or_fail "a vscode user"
getent group vscode >/dev/null 2>&1 || skip_or_fail "a vscode group"
if [ "$(id -u)" -ne 0 ]; then
    sudo -n true >/dev/null 2>&1 || skip_or_fail "root or passwordless sudo"
fi
if [ "$(id -un)" != "vscode" ]; then
    command -v sudo >/dev/null 2>&1 || skip_or_fail "sudo for the vscode write probe"
    sudo -n -u vscode true >/dev/null 2>&1 || skip_or_fail "passwordless sudo to vscode"
fi

as_root() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    else
        sudo -n "$@"
    fi
}

as_vscode() {
    if [ "$(id -un)" = "vscode" ]; then
        "$@"
    else
        sudo -n -u vscode "$@"
    fi
}

temp_root="$(mktemp -d)"
cleanup() {
    as_root chown -R "$(id -u):$(id -g)" "${temp_root}" 2>/dev/null || true
    chmod -R u+rwX "${temp_root}" 2>/dev/null || true
    rm -rf "${temp_root}"
}
trap cleanup EXIT
chmod 755 "${temp_root}"

make_config() {
    local config_root="$1"
    local marker="$2"

    mkdir -p "${config_root}"
    for source_name in .zshrc .bashrc starship.toml mise.toml containers-storage.conf; do
        printf '%s:%s\n' "${marker}" "${source_name}" > "${config_root}/${source_name}"
    done
}

fresh_home="${temp_root}/fresh/home"
fresh_config="${temp_root}/fresh/config"
mkdir -p "${fresh_home}"
make_config "${fresh_config}" fresh
as_root chown 0:0 "${fresh_home}"
bash "${SEEDER}" "${fresh_home}" "${fresh_config}"
as_vscode mkdir "${fresh_home}/.local/bin"
as_vscode mkdir "${fresh_home}/.local/share/new-tool"

private_home="${temp_root}/private/home"
private_config="${temp_root}/private/config"
private_parent="${private_home}/.config/containers"
private_storage="${private_parent}/storage.conf"
mkdir -p "${private_parent}"
make_config "${private_config}" baseline
printf 'existing-private-config\n' > "${private_storage}"
as_root chown 100001:100002 "${private_parent}"
as_root chown 100003:100004 "${private_storage}"
as_root chmod 0700 "${private_parent}"
as_root chmod 4640 "${private_storage}"
private_hash_before="$(as_root sha256sum "${private_storage}")"
private_meta_before="$(as_root stat -c '%u:%g:%a' "${private_storage}")"
bash "${SEEDER}" "${private_home}" "${private_config}"
[[ "$(as_root sha256sum "${private_storage}")" == "${private_hash_before}" ]] || \
    fail "inaccessible existing Podman config content changed"
[[ "$(as_root stat -c '%u:%g:%a' "${private_storage}")" == "${private_meta_before}" ]] || \
    fail "inaccessible existing Podman config metadata changed"

ancestor_home="${temp_root}/ancestor/home"
ancestor_config="${temp_root}/ancestor/config"
ancestor_local="${ancestor_home}/.local"
ancestor_storage="${ancestor_local}/share/containers/storage"
mkdir -p "${ancestor_storage}"
make_config "${ancestor_config}" ancestor
as_root chown 100011:100012 "${ancestor_local}"
as_root chown 100013:100014 "${ancestor_storage}"
as_root chmod 0700 "${ancestor_local}"
as_root chmod 2770 "${ancestor_storage}"
ancestor_before="$(as_root stat -c '%u:%g:%a' "${ancestor_storage}")"
bash "${SEEDER}" "${ancestor_home}" "${ancestor_config}"
[[ "$(as_root stat -c '%u:%g:%a' "${ancestor_storage}")" == "${ancestor_before}" ]] || \
    fail "inaccessible mapped storage directory metadata changed"

race_home="${temp_root}/race/home"
race_config_a="${temp_root}/race/config-a"
race_config_b="${temp_root}/race/config-b"
mkdir -p "${race_home}"
make_config "${race_config_a}" winner-a
make_config "${race_config_b}" winner-b
chmod 640 "${race_config_a}/.zshrc"
chmod 600 "${race_config_b}/.zshrc"
bash "${SEEDER}" "${race_home}" "${race_config_a}" &
first_pid=$!
bash "${SEEDER}" "${race_home}" "${race_config_b}" &
second_pid=$!
wait "${first_pid}"
wait "${second_pid}"
race_content="$(< "${race_home}/.zshrc")"
case "${race_content}" in
    winner-a:.zshrc)
        [[ "$(stat -c '%a' "${race_home}/.zshrc")" = "640" ]] || \
            fail "winner-a mode changed after the competing seed"
        ;;
    winner-b:.zshrc)
        [[ "$(stat -c '%a' "${race_home}/.zshrc")" = "600" ]] || \
            fail "winner-b mode changed after the competing seed"
        ;;
    *) fail "competing seeders produced unexpected content: ${race_content}" ;;
esac

echo "privileged runtime home ownership tests passed"
