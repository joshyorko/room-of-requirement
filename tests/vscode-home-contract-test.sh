#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SEEDER="${ROOT_DIR}/src/common/scripts/seed-vscode-home.sh"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

CONFIGS=(
    "${ROOT_DIR}/.devcontainer/devcontainer.json"
    "${ROOT_DIR}/src/ubuntu-noble/.devcontainer/devcontainer.json"
    "${ROOT_DIR}/src/debian-trixie/.devcontainer/devcontainer.json"
    "${ROOT_DIR}/src/wolfi/.devcontainer/devcontainer.json"
    "${ROOT_DIR}/templates/ror-starter/.devcontainer/devcontainer.json"
)

expected_mount="source=ror-vscode-home-\${devcontainerId},target=/home/vscode,type=volume"
expected_docker_mount="source=ror-docker-data-\${devcontainerId},target=/var/lib/docker,type=volume"

for config in "${CONFIGS[@]}"; do
    jq -e --arg expected "${expected_mount}" \
        '(.mounts // []) | index($expected) != null' "${config}" >/dev/null || \
        fail "${config} must mount the standard vscode home"

    jq -e \
        'any(.mounts[]?; contains("automation-jat") or contains("/workspaces/automation-jat")) | not' \
        "${config}" >/dev/null || \
        fail "${config} must not add an automation-jat persistence mount"

    jq -e --arg expected "${expected_docker_mount}" \
        '(.mounts // []) | index($expected) != null' "${config}" >/dev/null || \
        fail "${config} must isolate Docker storage by devcontainer ID"

    jq -e \
        'any(.mounts[]?; contains("target=/home/linuxbrew/.cache/Homebrew")) | not' \
        "${config}" >/dev/null || \
        fail "${config} must not mount the cache path for the wrong Homebrew user"

    jq -e '.postCreateCommand | contains("seed-vscode-home.sh")' "${config}" >/dev/null || \
        fail "${config} must use the idempotent home seeder"

    jq -e '.postCreateCommand | contains("/bin/bash /usr/local/bin/seed-vscode-home.sh")' "${config}" >/dev/null || \
        fail "${config} must invoke the home seeder with an absolute bash path"

    jq -e '.postCreateCommand | contains("cp /usr/share/ror/config/.zshrc ~/.zshrc") | not' \
        "${config}" >/dev/null || \
        fail "${config} must not overwrite the persistent zsh configuration"
done

jq -e \
    '(.mounts // []) | index("source=ror-wolfi-podman-storage-${devcontainerId},target=/home/vscode/.local/share/containers/storage,type=volume") != null' \
    "${ROOT_DIR}/src/wolfi/.devcontainer/devcontainer.json" >/dev/null || \
    fail "Wolfi must isolate Podman storage by devcontainer ID"

temp_root="$(mktemp -d)"
cleanup() {
    sudo -n chown -R "$(id -u):$(id -g)" "${temp_root}" 2>/dev/null || true
    chmod -R u+rwX "${temp_root}" 2>/dev/null || true
    rm -rf "${temp_root}"
}
trap cleanup EXIT

config_root="${temp_root}/config"
home_root="${temp_root}/home"
mkdir -p "${config_root}" "${home_root}/.codex" "${home_root}/.local/bin" "${home_root}/.config"

printf 'seed-zsh\n' > "${config_root}/.zshrc"
printf 'seed-bash\n' > "${config_root}/.bashrc"
printf 'seed-starship\n' > "${config_root}/starship.toml"
printf 'seed-mise\n' > "${config_root}/mise.toml"
printf 'seed-podman-storage\n' > "${config_root}/containers-storage.conf"
chmod 640 "${config_root}/.zshrc" "${config_root}/.bashrc"
chmod 644 \
    "${config_root}/starship.toml" \
    "${config_root}/mise.toml" \
    "${config_root}/containers-storage.conf"

storage_root="${home_root}/.local/share/containers/storage"
mkdir -p "${storage_root}"
mapped_sentinel="${storage_root}/mapped-sentinel"
printf 'mapped-owner\n' > "${mapped_sentinel}"
sudo -n chown 100001:100001 "${mapped_sentinel}"
sudo -n chmod 4755 "${mapped_sentinel}"
mapped_before="$(stat -c '%u:%g:%a' "${mapped_sentinel}")"
sudo -n chown 0:0 "${storage_root}"
sudo -n chmod 2770 "${storage_root}"

bash "${SEEDER}" "${home_root}" "${config_root}"

for pair in \
    ".zshrc:${home_root}/.zshrc" \
    ".bashrc:${home_root}/.bashrc" \
    "starship.toml:${home_root}/.config/starship.toml" \
    "mise.toml:${home_root}/.config/mise/config.toml" \
    "containers-storage.conf:${home_root}/.config/containers/storage.conf"; do
    source_name="${pair%%:*}"
    target_path="${pair#*:}"
    cmp "${config_root}/${source_name}" "${target_path}" || \
        fail "seeded file differs: ${target_path}"
    [[ "$(stat -c '%a' "${config_root}/${source_name}")" == "$(stat -c '%a' "${target_path}")" ]] || \
        fail "seeded mode differs: ${target_path}"
done

[[ "$(stat -c '%u:%g:%a' "${mapped_sentinel}")" == "${mapped_before}" ]] || \
    fail "home seeding changed subordinate ownership or special mode bits"
[[ "$(stat -c '%U:%G:%a' "${storage_root}")" == "vscode:vscode:2770" ]] || \
    fail "home seeding did not initialize the storage mount root safely"

printf 'user-owned-zsh\n' > "${home_root}/.zshrc"
chmod 600 "${home_root}/.zshrc"
printf 'user-owned-mise\n' > "${home_root}/.config/mise/config.toml"
chmod 600 "${home_root}/.config/mise/config.toml"
printf 'user-owned-storage\n' > "${home_root}/.config/containers/storage.conf"
chmod 600 "${home_root}/.config/containers/storage.conf"
printf 'codex-session\n' > "${home_root}/.codex/session-state"
chmod 600 "${home_root}/.codex/session-state"
printf '#!/bin/sh\n' > "${home_root}/.local/bin/user-tool"
chmod 700 "${home_root}/.local/bin/user-tool"
before_zsh="$(sha256sum "${home_root}/.zshrc")"
before_mise="$(sha256sum "${home_root}/.config/mise/config.toml")"
before_storage="$(sha256sum "${home_root}/.config/containers/storage.conf")"
before_codex="$(sha256sum "${home_root}/.codex/session-state")"
before_tool="$(sha256sum "${home_root}/.local/bin/user-tool")"

bash "${SEEDER}" "${home_root}" "${config_root}"

[[ "$(sha256sum "${home_root}/.zshrc")" == "${before_zsh}" ]] || \
    fail "existing zsh configuration was overwritten"
[[ "$(sha256sum "${home_root}/.config/mise/config.toml")" == "${before_mise}" ]] || \
    fail "existing mise configuration was overwritten"
[[ "$(sha256sum "${home_root}/.config/containers/storage.conf")" == "${before_storage}" ]] || \
    fail "existing Podman storage configuration was overwritten"
[[ "$(sha256sum "${home_root}/.codex/session-state")" == "${before_codex}" ]] || \
    fail "Codex state changed during reseed"
[[ "$(sha256sum "${home_root}/.local/bin/user-tool")" == "${before_tool}" ]] || \
    fail "user-installed tool changed during reseed"
[[ "$(stat -c '%a' "${home_root}/.zshrc")" == "600" ]] || \
    fail "existing private zsh mode changed"
[[ "$(stat -c '%a' "${home_root}/.config/mise/config.toml")" == "600" ]] || \
    fail "existing private mise mode changed"
[[ "$(stat -c '%a' "${home_root}/.config/containers/storage.conf")" == "600" ]] || \
    fail "existing private Podman config mode changed"
[[ "$(stat -c '%a' "${home_root}/.codex/session-state")" == "600" ]] || \
    fail "existing private Codex mode changed"
[[ "$(stat -c '%a' "${home_root}/.local/bin/user-tool")" == "700" ]] || \
    fail "existing user tool mode changed"

echo "vscode home persistence contract tests passed"
