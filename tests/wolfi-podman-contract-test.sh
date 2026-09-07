#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOCKERFILE="${ROOT_DIR}/src/wolfi/.devcontainer/Dockerfile"
ENTRYPOINT="${ROOT_DIR}/src/common/entrypoint.sh"
DEVCONTAINER="${ROOT_DIR}/src/wolfi/.devcontainer/devcontainer.json"
STORAGE_CONFIG="${ROOT_DIR}/src/wolfi/config/containers-storage.conf"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

assert_contains() {
    local file="$1"
    local pattern="$2"
    local label="$3"
    grep -Eq "${pattern}" "${file}" || fail "${label}: ${pattern} not found in ${file}"
}

assert_not_contains() {
    local file="$1"
    local pattern="$2"
    local label="$3"
    if grep -Eq "${pattern}" "${file}"; then
        fail "${label}: unexpected ${pattern} in ${file}"
    fi
}

for package in podman-6.0 buildah skopeo shadow-subids mount; do
    assert_contains "${DOCKERFILE}" "^[[:space:]]*${package}[[:space:]\\]*$" \
        "Wolfi Podman package"
done

assert_contains "${DOCKERFILE}" 'brew install.*passt|brew install passt' \
    "Homebrew pasta provider"
assert_contains "${DOCKERFILE}" 'echo[[:space:]]+"vscode:[^" ]+:[^" ]+"[[:space:]]*>>[[:space:]]*/etc/subuid' \
    "subordinate UID range"
assert_contains "${DOCKERFILE}" 'echo[[:space:]]+"vscode:[^" ]+:[^" ]+"[[:space:]]*>>[[:space:]]*/etc/subgid' \
    "subordinate GID range"
assert_contains "${DOCKERFILE}" "grep[[:space:]]+-q[[:space:]]+'\\^vscode:'[[:space:]]+/etc/subuid" \
    "subordinate UID range is duplicate-safe"
assert_contains "${DOCKERFILE}" "grep[[:space:]]+-q[[:space:]]+'\\^vscode:'[[:space:]]+/etc/subgid" \
    "subordinate GID range is duplicate-safe"
assert_contains "${DOCKERFILE}" 'chmod[[:space:]]+u\+s[[:space:]]+/usr/bin/newuidmap[[:space:]]+/usr/bin/newgidmap' \
    "setuid mapping helpers"
python3 - "${STORAGE_CONFIG}" <<'PY'
import pathlib
import sys
import tomllib

config = tomllib.loads(pathlib.Path(sys.argv[1]).read_text())
assert config["storage"]["driver"] == "overlay"
assert config["storage"]["rootless_storage_path"] == "$HOME/.local/share/containers/storage"
assert config["storage"]["options"]["overlay"]["mount_program"] == "/usr/bin/fuse-overlayfs"
PY
assert_contains "${DOCKERFILE}" 'src/wolfi/config/containers-storage.conf[[:space:]]+/usr/share/ror/config/containers-storage.conf' \
    "persistent-home Podman baseline"
assert_contains "${ENTRYPOINT}" 'XDG_RUNTIME_DIR' "dynamic runtime directory"
assert_contains "${ENTRYPOINT}" 'mount --make-rshared /' "shared root mount"
assert_not_contains "${ENTRYPOINT}" 'chown[[:space:]]+-R.*(HOME|podman|storage|mise|npm)' \
    "recursive runtime ownership repair"
assert_not_contains "${ENTRYPOINT}" 'chmod[[:space:]]+-R.*(HOME|podman|storage|mise|npm)' \
    "recursive runtime mode repair"
assert_contains "${DEVCONTAINER}" 'ror-wolfi-podman-storage-\$\{devcontainerId\}' \
    "workspace-scoped Podman storage volume"
assert_contains "${DEVCONTAINER}" 'target=/home/vscode/.local/share/containers/storage' \
    "Podman storage volume target"
assert_not_contains "${DOCKERFILE}" 'alias[[:space:]]+docker[[:space:]]*=' \
    "Docker command replacement"
assert_not_contains "${ENTRYPOINT}" 'podman system service' \
    "Podman API service"
echo "Wolfi Podman contract tests passed"
