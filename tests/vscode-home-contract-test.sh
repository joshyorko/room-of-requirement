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
expected_post_create="/bin/bash /usr/local/bin/devcontainer-post-create.sh"

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

    jq -e --arg expected "${expected_post_create}" \
        '.postCreateCommand == $expected' "${config}" >/dev/null || \
        fail "${config} must use only the shared absolute project hydrator"

    jq -e '((has("onCreateCommand") | not) and (has("updateContentCommand") | not))' \
        "${config}" >/dev/null || \
        fail "${config} must not define competing lifecycle hydration hooks"
done

jq -e '
    .image == "ghcr.io/joshyorko/room-of-requirement:latest" and
    ((.features // {}) | length == 0) and
    .privileged == true and
    .overrideCommand == false and
    ((.containerEnv // {}) | has("DEV_CONTAINERS_SKIP_GCOMPAT_INSTALL") | not) and
    ((.remoteEnv // {}) | has("DEV_CONTAINERS_SKIP_GCOMPAT_INSTALL") | not)
' "${ROOT_DIR}/templates/ror-starter/.devcontainer/devcontainer.json" >/dev/null || \
    fail "starter must reuse the supported image's DinD with privilege and no feature reinstall"

jq -e \
    '(.mounts // []) | index("source=ror-wolfi-podman-storage-${devcontainerId},target=/home/vscode/.local/share/containers/storage,type=volume") != null' \
    "${ROOT_DIR}/src/wolfi/.devcontainer/devcontainer.json" >/dev/null || \
    fail "Wolfi must isolate Podman storage by devcontainer ID"

temp_root="$(mktemp -d)"
trap 'rm -rf "${temp_root}"' EXIT

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

no_vscode_bin="${temp_root}/no-vscode-bin"
portable_home="${temp_root}/portable-home"
mkdir -p "${no_vscode_bin}" "${portable_home}"
cat > "${no_vscode_bin}/getent" <<'GETENT'
#!/usr/bin/env bash
exit 2
GETENT
cat > "${no_vscode_bin}/sudo" <<'SUDO'
#!/usr/bin/env bash
exit 99
SUDO
chmod +x "${no_vscode_bin}/getent" "${no_vscode_bin}/sudo"
PATH="${no_vscode_bin}:/usr/bin:/bin" bash "${SEEDER}" "${portable_home}" "${config_root}"
cmp "${config_root}/.zshrc" "${portable_home}/.zshrc" || \
    fail "portable seeding without a vscode identity changed baseline content"

echo "vscode home persistence contract tests passed"
