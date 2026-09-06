#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STARTER="${ROOT_DIR}/src/common/scripts/ror-docker-start.sh"
WOLFI_DOCKERFILE="${ROOT_DIR}/src/wolfi/.devcontainer/Dockerfile"
DOCKERFILES=(
    "${ROOT_DIR}/src/ubuntu-noble/.devcontainer/Dockerfile"
    "${ROOT_DIR}/src/debian-trixie/.devcontainer/Dockerfile"
    "${WOLFI_DOCKERFILE}"
)

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

temp_root="$(mktemp -d)"
trap 'rm -rf "${temp_root}"' EXIT
empty_config="${temp_root}/empty.json"
printf '{}\n' > "${empty_config}"

run_plan() {
    local fstype="$1"
    local has_fuse_overlayfs="$2"
    local has_dev_fuse="$3"
    local driver="${4:-auto}"

    ROR_DOCKER_START_DRY_RUN=1 \
        ROR_DOCKER_DAEMON_CONFIG="${empty_config}" \
        ROR_DOCKER_EFFECTIVE_CONFIG="${temp_root}/effective.json" \
        ROR_DOCKER_TEST_DATA_ROOT_FSTYPE="${fstype}" \
        ROR_DOCKER_TEST_HAS_FUSE_OVERLAYFS="${has_fuse_overlayfs}" \
        ROR_DOCKER_TEST_HAS_DEV_FUSE="${has_dev_fuse}" \
        ROR_DOCKER_STORAGE_DRIVER="${driver}" \
        "${STARTER}" --socket /tmp/ror-test-docker.sock 2>/dev/null
}

run_plan_with_dockerd_only() {
    ROR_DOCKER_START_DRY_RUN=1 \
        ROR_DOCKER_DAEMON_CONFIG="${empty_config}" \
        ROR_DOCKER_EFFECTIVE_CONFIG="${temp_root}/effective.json" \
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
        ROR_DOCKER_DAEMON_CONFIG="${empty_config}" \
        ROR_DOCKER_EFFECTIVE_CONFIG="${temp_root}/effective.json" \
        ROR_DOCKER_TEST_HAS_FINDMNT="0" \
        ROR_DOCKER_TEST_PROC_MOUNTS="${mounts_file}" \
        ROR_DOCKER_TEST_HAS_FUSE_OVERLAYFS="1" \
        ROR_DOCKER_TEST_HAS_DEV_FUSE="1" \
        "${STARTER}" --socket /tmp/ror-test-docker.sock 2>/dev/null
}

run_plan_with_config() {
    local config_path="$1"
    local effective_path="$2"
    shift 2

    env \
        ROR_DOCKER_START_DRY_RUN=1 \
        ROR_DOCKER_DAEMON_CONFIG="${config_path}" \
        ROR_DOCKER_EFFECTIVE_CONFIG="${effective_path}" \
        ROR_DOCKER_TEST_DATA_ROOT_FSTYPE="overlay" \
        ROR_DOCKER_TEST_HAS_FUSE_OVERLAYFS="1" \
        ROR_DOCKER_TEST_HAS_DEV_FUSE="1" \
        "$@" \
        "${STARTER}" --socket "${temp_root}/docker.sock" 2>/dev/null
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

for package in iptables-wrappers iptables-nft nftables; do
    grep -Eq "^[[:space:]]*${package}[[:space:]\\]*$" "${WOLFI_DOCKERFILE}" || \
        fail "Wolfi Dockerfile must install ${package} for nftables-compatible Docker networking"
done

for dockerfile in "${DOCKERFILES[@]}"; do
    grep -Eq '^[[:space:]]*jq[[:space:]\\]*$' "${dockerfile}" || \
        fail "${dockerfile} must install jq for daemon configuration parsing"
done

plan="$(run_plan overlay 1 1)"
assert_contains "${plan}" "--config-file=${temp_root}/effective.json" \
    "overlay data root with usable fuse"
jq -e '."storage-driver" == "fuse-overlayfs"' "${temp_root}/effective.json" >/dev/null || \
    fail "overlay data root with usable fuse must select fuse-overlayfs"

plan="$(run_plan overlay 0 1)"
jq -e '."storage-driver" == "vfs"' "${temp_root}/effective.json" >/dev/null || \
    fail "overlay data root without fuse-overlayfs must select vfs"

plan="$(run_plan overlay 1 0)"
jq -e '."storage-driver" == "vfs"' "${temp_root}/effective.json" >/dev/null || \
    fail "overlay data root without /dev/fuse must select vfs"

plan="$(run_plan ext4 1 1)"
assert_not_contains "${plan}" "--storage-driver=" "normal data root auto mode"
jq -e 'has("storage-driver") | not' "${temp_root}/effective.json" >/dev/null || \
    fail "normal data root auto mode must use Docker's default driver"

plan="$(run_plan ext4 1 1 vfs)"
jq -e '."storage-driver" == "vfs"' "${temp_root}/effective.json" >/dev/null || \
    fail "forced vfs must be written to the effective config"

plan="$(run_plan_with_dockerd_only)"
assert_contains "${plan}" "/usr/bin/dockerd" "dockerd fallback"
assert_not_contains "${plan}" "dockerd-entrypoint.sh" "dockerd fallback"

mounts_file="${temp_root}/mounts"
cat > "${mounts_file}" <<'MOUNTS'
overlay / overlay rw,relatime 0 0
tmpfs /run tmpfs rw,nosuid,nodev 0 0
MOUNTS
plan="$(run_plan_without_findmnt "${mounts_file}")"
jq -e '."storage-driver" == "fuse-overlayfs"' "${temp_root}/effective.json" >/dev/null || \
    fail "nested overlay data root without findmnt must select fuse-overlayfs"

pretty_config="${temp_root}/pretty.json"
compact_config="${temp_root}/compact.json"
printf '{\n  "storage-driver": "vfs"\n}\n' > "${pretty_config}"
printf '{"storage-driver":"vfs"}\n' > "${compact_config}"

for config_path in "${pretty_config}" "${compact_config}"; do
    effective_path="${config_path%.json}-effective.json"
    plan="$(run_plan_with_config "${config_path}" "${effective_path}")"
    assert_contains "${plan}" "--config-file=${effective_path}" \
        "daemon config is forwarded"
    assert_not_contains "${plan}" "--storage-driver=" \
        "daemon config does not duplicate the storage driver"
    jq -e '."storage-driver" == "vfs" and ."data-root" == "/var/lib/docker"' \
        "${effective_path}" >/dev/null || \
        fail "effective config must preserve ${config_path} and resolve data-root"
    if command -v dockerd >/dev/null 2>&1; then
        dockerd --validate --config-file "${effective_path}" >/dev/null
    fi
done

host_config="${temp_root}/host.json"
host_effective="${temp_root}/host-effective.json"
printf '{"hosts":["unix:///tmp/other.sock"]}\n' > "${host_config}"
run_plan_with_config "${host_config}" "${host_effective}" >/dev/null
jq -e 'has("hosts") | not' "${host_effective}" >/dev/null || \
    fail "the explicit socket must not duplicate a daemon config hosts setting"

configured_root="${temp_root}/configured-data"
custom_root="${temp_root}/custom-data"
data_config="${temp_root}/data-root.json"
data_effective="${temp_root}/data-root-effective.json"
jq -n --arg root "${configured_root}" '{"data-root": $root}' > "${data_config}"
run_plan_with_config "${data_config}" "${data_effective}" >/dev/null
jq -e --arg root "${configured_root}" '."data-root" == $root' \
    "${data_effective}" >/dev/null || \
    fail "daemon config data-root must drive the effective launch config"

run_plan_with_config "${data_config}" "${data_effective}" \
    ROR_DOCKER_DATA_ROOT="${custom_root}" >/dev/null
jq -e --arg root "${custom_root}" '."data-root" == $root' \
    "${data_effective}" >/dev/null || \
    fail "explicit data-root must override the daemon config for probing and launch"

override_effective="${temp_root}/override-effective.json"
run_plan_with_config "${compact_config}" "${override_effective}" \
    ROR_DOCKER_STORAGE_DRIVER=fuse-overlayfs >/dev/null
jq -e '."storage-driver" == "fuse-overlayfs"' "${override_effective}" >/dev/null || \
    fail "explicit storage driver must override daemon config without duplicate flags"

shipped_effective="${temp_root}/shipped-effective.json"
ROR_DOCKER_START_DRY_RUN=1 \
    ROR_DOCKER_DAEMON_CONFIG="${ROOT_DIR}/src/common/config/docker-daemon.json" \
    ROR_DOCKER_EFFECTIVE_CONFIG="${shipped_effective}" \
    ROR_DOCKER_TEST_DATA_ROOT_FSTYPE=overlay \
    ROR_DOCKER_TEST_HAS_FUSE_OVERLAYFS=1 \
    ROR_DOCKER_TEST_HAS_DEV_FUSE=0 \
    "${STARTER}" --socket "${temp_root}/shipped.sock" >/dev/null
jq -e '."storage-driver" == "vfs"' "${shipped_effective}" >/dev/null || \
    fail "shipped auto configuration must fall back when FUSE is unavailable"

invalid_config="${temp_root}/invalid.json"
printf '{invalid\n' > "${invalid_config}"
if run_plan_with_config "${invalid_config}" "${temp_root}/invalid-effective.json" >/dev/null; then
    fail "invalid daemon JSON must fail before launch"
fi

runtime_bin="${temp_root}/runtime-bin"
mkdir -p "${runtime_bin}"
cat > "${runtime_bin}/sudo" <<'SUDO'
#!/usr/bin/env bash
case "$1" in
    mkdir | install)
        exec "$@"
        ;;
    find | mount | chown | chmod | ln | tee)
        exit 0
        ;;
    "${ROR_DOCKER_TEST_FIXTURE}"/fake-*)
        exec "$@"
        ;;
    *)
        exit 97
        ;;
esac
SUDO
cat > "${runtime_bin}/mountpoint" <<'MOUNTPOINT'
#!/usr/bin/env bash
exit 0
MOUNTPOINT
cat > "${runtime_bin}/sleep" <<'SLEEP'
#!/usr/bin/env bash
exec /bin/sleep 0.01
SLEEP
cat > "${runtime_bin}/docker" <<'DOCKER'
#!/usr/bin/env bash
exit 1
DOCKER
cat > "${temp_root}/fake-failed" <<'FAILED'
#!/usr/bin/env bash
exit 42
FAILED
cat > "${temp_root}/fake-idle" <<'IDLE'
#!/usr/bin/env bash
exec /bin/sleep 1
IDLE
chmod +x \
    "${runtime_bin}/sudo" \
    "${runtime_bin}/mountpoint" \
    "${runtime_bin}/sleep" \
    "${runtime_bin}/docker" \
    "${temp_root}/fake-failed" \
    "${temp_root}/fake-idle"

run_runtime_case() {
    local fake_daemon="$1"
    local socket_path="$2"

    PATH="${runtime_bin}:/home/linuxbrew/.linuxbrew/bin:/usr/bin:/bin" \
        ROR_DOCKER_DAEMON_CONFIG="${empty_config}" \
        ROR_DOCKER_EFFECTIVE_CONFIG="${temp_root}/runtime-effective.json" \
        ROR_DOCKER_DATA_ROOT="${temp_root}/runtime-data" \
        ROR_DOCKER_TEST_DATA_ROOT_FSTYPE=ext4 \
        ROR_DOCKER_TEST_HAS_DOCKERD_ENTRYPOINT=0 \
        ROR_DOCKER_TEST_DOCKERD_BIN="${fake_daemon}" \
        ROR_DOCKER_TEST_DOCKER_BIN="${runtime_bin}/docker" \
        ROR_DOCKER_TEST_FIXTURE="${temp_root}" \
        ROR_DOCKER_START_TIMEOUT_SECONDS=2 \
        "${STARTER}" --socket "${socket_path}" --link-default false >/dev/null 2>&1
}

set +e
run_runtime_case "${temp_root}/fake-failed" "${temp_root}/failed.sock"
failed_status=$?
set -e
[[ "${failed_status}" -ne 0 ]] || \
    fail "an exited Docker daemon must fail startup"

stale_socket="${temp_root}/stale.sock"
python3 - "${stale_socket}" <<'PY'
import socket
import sys

sock = socket.socket(socket.AF_UNIX)
sock.bind(sys.argv[1])
sock.close()
PY
set +e
run_runtime_case "${temp_root}/fake-idle" "${stale_socket}"
stale_status=$?
set -e
[[ "${stale_status}" -ne 0 ]] || \
    fail "a stale socket inode must not satisfy Docker API readiness"

set +e
run_runtime_case "${temp_root}/fake-idle" "${temp_root}/timeout.sock"
timeout_status=$?
set -e
[[ "${timeout_status}" -ne 0 ]] || \
    fail "Docker API readiness timeout must fail startup"

echo "ror-docker-start config and readiness tests passed"
