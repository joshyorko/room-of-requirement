#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOCKERFILE="${ROOT_DIR}/src/wolfi/.devcontainer/Dockerfile"
ENTRYPOINT="${ROOT_DIR}/src/common/entrypoint.sh"
DEVCONTAINER="${ROOT_DIR}/src/wolfi/.devcontainer/devcontainer.json"
WORKFLOW="${ROOT_DIR}/.github/workflows/build-devcontainers.yml"

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
assert_contains "${DOCKERFILE}" 'rootless_storage_path[[:space:]]*=[[:space:]]*"\$HOME/.local/share/containers/storage"' \
    "rootless storage path"
assert_contains "${DOCKERFILE}" 'mount_program[[:space:]]*=[[:space:]]*"/usr/bin/fuse-overlayfs"' \
    "fuse-overlayfs storage"
assert_contains "${ENTRYPOINT}" 'XDG_RUNTIME_DIR' "dynamic runtime directory"
assert_contains "${ENTRYPOINT}" 'mount --make-rshared /' "shared root mount"
assert_contains "${DEVCONTAINER}" 'ror-wolfi-podman-storage' "separate Podman storage volume"
assert_contains "${DEVCONTAINER}" 'target=/home/vscode/.local/share/containers/storage' \
    "Podman storage volume target"
assert_not_contains "${DOCKERFILE}" 'alias[[:space:]]+docker[[:space:]]*=' \
    "Docker command replacement"
assert_not_contains "${ENTRYPOINT}" 'podman system service' \
    "Podman API service"
assert_contains "${WORKFLOW}" 'container="\$\(docker run -d --privileged "\$\{BUILT_IMAGE\}" sleep infinity\)"' \
    "Podman smoke owns its container lifecycle"
assert_contains "${WORKFLOW}" 'docker rm -f "\$\{container\}"' \
    "Podman smoke cleans up its container"
assert_not_contains "${WORKFLOW}" 'docker ps --filter "ancestor=' \
    "Podman smoke does not reuse a prior step container"
assert_contains "${WORKFLOW}" 'docker.io/library/alpine:3\.22' \
    "Podman smoke uses fully qualified Alpine image"

echo "Wolfi Podman contract tests passed"
