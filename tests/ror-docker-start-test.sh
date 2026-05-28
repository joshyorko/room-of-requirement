#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STARTER="${ROOT_DIR}/src/common/scripts/ror-docker-start.sh"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

run_plan() {
    local fstype="$1"
    local has_fuse_overlayfs="$2"
    local has_dev_fuse="$3"
    local driver="${4:-auto}"

    ROR_DOCKER_START_DRY_RUN=1 \
        ROR_DOCKER_TEST_DATA_ROOT_FSTYPE="${fstype}" \
        ROR_DOCKER_TEST_HAS_FUSE_OVERLAYFS="${has_fuse_overlayfs}" \
        ROR_DOCKER_TEST_HAS_DEV_FUSE="${has_dev_fuse}" \
        ROR_DOCKER_STORAGE_DRIVER="${driver}" \
        "${STARTER}" --socket /tmp/ror-test-docker.sock 2>/dev/null
}

run_plan_with_dockerd_only() {
    ROR_DOCKER_START_DRY_RUN=1 \
        ROR_DOCKER_TEST_DATA_ROOT_FSTYPE="ext4" \
        ROR_DOCKER_TEST_HAS_FUSE_OVERLAYFS="1" \
        ROR_DOCKER_TEST_HAS_DEV_FUSE="1" \
        ROR_DOCKER_TEST_HAS_DOCKERD_ENTRYPOINT="0" \
        ROR_DOCKER_TEST_DOCKERD_BIN="/usr/bin/dockerd" \
        "${STARTER}" --socket /tmp/ror-test-docker.sock 2>/dev/null
}

run_plan_without_findmnt() {
    local mounts_file="$1"

    ROR_DOCKER_START_DRY_RUN=1 \
        ROR_DOCKER_TEST_HAS_FINDMNT="0" \
        ROR_DOCKER_TEST_PROC_MOUNTS="${mounts_file}" \
        ROR_DOCKER_TEST_HAS_FUSE_OVERLAYFS="1" \
        ROR_DOCKER_TEST_HAS_DEV_FUSE="1" \
        "${STARTER}" --socket /tmp/ror-test-docker.sock 2>/dev/null
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local label="$3"

    [[ "${haystack}" == *"${needle}"* ]] || fail "${label}: expected ${needle} in: ${haystack}"
}

assert_not_contains() {
    local haystack="$1"
    local needle="$2"
    local label="$3"

    [[ "${haystack}" != *"${needle}"* ]] || fail "${label}: did not expect ${needle} in: ${haystack}"
}

plan="$(run_plan overlay 1 1)"
assert_contains "${plan}" "--storage-driver=fuse-overlayfs" "overlay data root with usable fuse"

plan="$(run_plan overlay 0 1)"
assert_contains "${plan}" "--storage-driver=vfs" "overlay data root without fuse-overlayfs"

plan="$(run_plan overlay 1 0)"
assert_contains "${plan}" "--storage-driver=vfs" "overlay data root without /dev/fuse"

plan="$(run_plan ext4 1 1)"
assert_not_contains "${plan}" "--storage-driver=" "normal data root auto mode"

plan="$(run_plan ext4 1 1 vfs)"
assert_contains "${plan}" "--storage-driver=vfs" "forced vfs"

plan="$(run_plan_with_dockerd_only)"
assert_contains "${plan}" "/usr/bin/dockerd" "dockerd fallback"
assert_not_contains "${plan}" "dockerd-entrypoint.sh" "dockerd fallback"

mounts_file="$(mktemp)"
trap 'rm -f "${mounts_file}"' EXIT
cat > "${mounts_file}" <<'MOUNTS'
overlay / overlay rw,relatime 0 0
tmpfs /run tmpfs rw,nosuid,nodev 0 0
MOUNTS
plan="$(run_plan_without_findmnt "${mounts_file}")"
assert_contains "${plan}" "--storage-driver=fuse-overlayfs" "nested overlay data root without findmnt"

echo "ror-docker-start storage-driver tests passed"
