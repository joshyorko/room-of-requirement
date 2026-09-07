#!/usr/bin/env bash
# Exercise the maintained starter on a disposable built Wolfi image, offline.
set -euo pipefail

if [ "${1:-}" != "--in-container" ]; then
    image="${1:-${ROR_DOCKER_TEST_IMAGE:-}}"
    if [ -z "${image}" ]; then
        echo 'SKIP: Docker image smoke requires a built Wolfi image argument (or ROR_DOCKER_TEST_IMAGE)'
        [ "${ROR_REQUIRE_DOCKER_IMAGE_SMOKE:-0}" != "1" ]
        exit "$?"
    fi
    root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    exec docker run --rm --pull never --network none --privileged --entrypoint bash \
        --env "ROR_DOCKER_STORAGE_DRIVER=${ROR_DOCKER_STORAGE_DRIVER:-auto}" \
        --mount "type=bind,source=${root}/tests/runtime-docker-image-smoke.sh,target=/ror-docker-image-smoke.sh,readonly" \
        --mount "type=bind,source=${root}/src/common/scripts/ror-docker-start.sh,target=/usr/local/bin/ror-docker-start.sh,readonly" \
        "${image}" /ror-docker-image-smoke.sh --in-container
fi

fixture="$(mktemp -d /tmp/ror-docker-image-smoke.XXXXXX)"
export ROR_DOCKER_DATA_ROOT="${fixture}/data"
export ROR_DOCKER_EFFECTIVE_CONFIG="${fixture}/effective.json"
export ROR_DOCKER_TEST_PROFILE_DIR="${fixture}/profile.d"
export ROR_DOCKER_TEST_DEFAULT_SOCKET="${fixture}/default/docker.sock"
mkdir -p "${ROR_DOCKER_DATA_ROOT}" "${fixture}/rootfs/bin"
printf 'data-root filesystem=%s\n' "$(stat -f -c %T "${ROR_DOCKER_DATA_ROOT}")"
awk '$2 == "/" {print "root mount filesystem=" $3}' /proc/mounts

if ! /usr/local/bin/ror-docker-start.sh --socket "${fixture}/docker.sock" --link-default false \
    > "${fixture}/daemon.log" 2>&1; then
    tail -80 "${fixture}/daemon.log" >&2
    exit 1
fi

client() {
    docker --host "unix://${fixture}/docker.sock" "$@"
}

driver="$(client info --format '{{.Driver}}')"
printf 'ready driver=%s root=%s\n' "${driver}" "$(client info --format '{{.DockerRootDir}}')"
selected="$(jq -r '."storage-driver" // empty' "${ROR_DOCKER_EFFECTIVE_CONFIG}")"
if [ -n "${selected}" ]; then
    [ "${driver}" = "${selected}" ] || {
        echo "FAIL: Docker used ${driver} instead of selected graph driver ${selected}" >&2
        exit 1
    }
fi

# A tiny image made from this image's BusyBox and its real loader/libraries.
# Import and execution must both work; API readiness alone missed EINVAL.
cp /bin/busybox "${fixture}/rootfs/bin/busybox"
while IFS= read -r library; do
    cp -L --parents "${library}" "${fixture}/rootfs"
done < <(ldd /bin/busybox | awk '$3 ~ /^\// {print $3} $1 ~ /^\// {print $1}')
tar -C "${fixture}/rootfs" -cf "${fixture}/rootfs.tar" .
imported="$(client import "${fixture}/rootfs.tar")"
result="$(client run --rm --network none "${imported}" /bin/busybox echo ror-dind-container-ok)"
[ "${result}" = "ror-dind-container-ok" ] || {
    echo "FAIL: unexpected nested container result: ${result}" >&2
    exit 1
}
echo 'Docker image import and nested container execution passed'
# Docker --rm removes this task-owned outer container and all its writable
# graph data on exit; no host volume is attached or pruned.
