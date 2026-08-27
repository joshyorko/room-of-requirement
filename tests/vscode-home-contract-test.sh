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

for config in "${CONFIGS[@]}"; do
    jq -e --arg expected "${expected_mount}" \
        '(.mounts // []) | index($expected) != null' "${config}" >/dev/null || \
        fail "${config} must mount the standard vscode home"

    jq -e \
        'any(.mounts[]?; contains("automation-jat") or contains("/workspaces/automation-jat")) | not' \
        "${config}" >/dev/null || \
        fail "${config} must not add an automation-jat persistence mount"

    jq -e '.postCreateCommand | contains("seed-vscode-home.sh")' "${config}" >/dev/null || \
        fail "${config} must use the idempotent home seeder"

    jq -e '.postCreateCommand | contains("/bin/bash /usr/local/bin/seed-vscode-home.sh")' "${config}" >/dev/null || \
        fail "${config} must invoke the home seeder with an absolute bash path"

    jq -e '.postCreateCommand | contains("cp /usr/share/ror/config/.zshrc ~/.zshrc") | not' \
        "${config}" >/dev/null || \
        fail "${config} must not overwrite the persistent zsh configuration"
done

temp_root="$(mktemp -d)"
trap 'rm -rf "${temp_root}"' EXIT

config_root="${temp_root}/config"
home_root="${temp_root}/home"
mkdir -p "${config_root}" "${home_root}/.codex" "${home_root}/.local/bin" "${home_root}/.config"

printf 'seed-zsh\n' > "${config_root}/.zshrc"
printf 'seed-bash\n' > "${config_root}/.bashrc"
printf 'seed-starship\n' > "${config_root}/starship.toml"
printf 'seed-mise\n' > "${config_root}/mise.toml"
chmod 640 "${config_root}/.zshrc" "${config_root}/.bashrc"
chmod 644 "${config_root}/starship.toml" "${config_root}/mise.toml"

bash "${SEEDER}" "${home_root}" "${config_root}"

for pair in \
    ".zshrc:${home_root}/.zshrc" \
    ".bashrc:${home_root}/.bashrc" \
    "starship.toml:${home_root}/.config/starship.toml" \
    "mise.toml:${home_root}/.config/mise/config.toml"; do
    source_name="${pair%%:*}"
    target_path="${pair#*:}"
    cmp "${config_root}/${source_name}" "${target_path}" || \
        fail "seeded file differs: ${target_path}"
    [[ "$(stat -c '%a' "${config_root}/${source_name}")" == "$(stat -c '%a' "${target_path}")" ]] || \
        fail "seeded mode differs: ${target_path}"
done

printf 'user-owned-zsh\n' > "${home_root}/.zshrc"
chmod 600 "${home_root}/.zshrc"
printf 'user-owned-mise\n' > "${home_root}/.config/mise/config.toml"
chmod 600 "${home_root}/.config/mise/config.toml"
printf 'codex-session\n' > "${home_root}/.codex/session-state"
chmod 600 "${home_root}/.codex/session-state"
printf '#!/bin/sh\n' > "${home_root}/.local/bin/user-tool"
chmod 700 "${home_root}/.local/bin/user-tool"
before_zsh="$(sha256sum "${home_root}/.zshrc")"
before_mise="$(sha256sum "${home_root}/.config/mise/config.toml")"
before_codex="$(sha256sum "${home_root}/.codex/session-state")"
before_tool="$(sha256sum "${home_root}/.local/bin/user-tool")"

bash "${SEEDER}" "${home_root}" "${config_root}"

[[ "$(sha256sum "${home_root}/.zshrc")" == "${before_zsh}" ]] || \
    fail "existing zsh configuration was overwritten"
[[ "$(sha256sum "${home_root}/.config/mise/config.toml")" == "${before_mise}" ]] || \
    fail "existing mise configuration was overwritten"
[[ "$(sha256sum "${home_root}/.codex/session-state")" == "${before_codex}" ]] || \
    fail "Codex state changed during reseed"
[[ "$(sha256sum "${home_root}/.local/bin/user-tool")" == "${before_tool}" ]] || \
    fail "user-installed tool changed during reseed"
[[ "$(stat -c '%a' "${home_root}/.zshrc")" == "600" ]] || \
    fail "existing private zsh mode changed"
[[ "$(stat -c '%a' "${home_root}/.config/mise/config.toml")" == "600" ]] || \
    fail "existing private mise mode changed"
[[ "$(stat -c '%a' "${home_root}/.codex/session-state")" == "600" ]] || \
    fail "existing private Codex mode changed"
[[ "$(stat -c '%a' "${home_root}/.local/bin/user-tool")" == "700" ]] || \
    fail "existing user tool mode changed"

echo "vscode home persistence contract tests passed"
