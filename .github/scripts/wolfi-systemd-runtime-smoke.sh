#!/usr/bin/env bash
# Runs only in the image CI job; all containers and named volumes are owned here.
set -euo pipefail

image="${1:?image required}"
scripts="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source_root="$(cd "${scripts}/../.." && pwd)"
suffix="$(date +%s)-$$-${RANDOM}"
container="ror-wolfi-systemd-${suffix}"
container_id=""
container_created=0
home_volume="${container}-home"
volumes=()
start_count=0

cleanup() {
    local status=$?
    if [[ "${container_created}" == 1 ]]; then
        docker rm -f -v "${container_id}" >/dev/null || status=1
    fi
    for volume in "${volumes[@]}"; do
        local owner
        owner="$(docker volume inspect --format '{{ index .Labels "io.ror.smoke.run" }}' "${volume}")" || {
            echo "FAIL: could not verify ownership of smoke volume ${volume}" >&2
            status=1
            continue
        }
        if [[ "${owner}" == "${container}" ]]; then
            docker volume rm "${volume}" >/dev/null || status=1
        else
            echo "FAIL: refusing to remove unowned volume ${volume}" >&2
            status=1
        fi
    done
    exit "${status}"
}
trap cleanup EXIT

create_volume() {
    local volume="$1"
    if docker volume inspect "${volume}" >/dev/null 2>&1; then
        echo "FAIL: smoke volume name already exists: ${volume}" >&2
        return 1
    fi
    docker volume create --label "io.ror.smoke.run=${container}" "${volume}" >/dev/null
    volumes+=("${volume}")
    if [[ "$(docker volume inspect --format '{{ index .Labels "io.ror.smoke.run" }}' "${volume}")" != "${container}" ]]; then
        echo "FAIL: created volume ownership could not be verified: ${volume}" >&2
        return 1
    fi
}

create_volume "${home_volume}"

start_container() {
    start_count=$((start_count + 1))
    local docker_volume="${container}-docker-${start_count}"
    local containerd_volume="${container}-containerd-${start_count}"
    local podman_volume="${container}-podman-${start_count}"
    for volume in "${docker_volume}" "${containerd_volume}" "${podman_volume}"; do
        create_volume "${volume}"
    done
    container_id="$(docker run -d --name "${container}" --privileged --cgroupns=private \
        --mount "type=volume,source=${home_volume},target=/home/vscode" \
        --mount "type=volume,source=${docker_volume},target=/var/lib/docker" \
        --mount "type=volume,source=${containerd_volume},target=/var/lib/containerd" \
        --mount "type=volume,source=${podman_volume},target=/home/vscode/.local/share/containers/storage" \
        --mount "type=bind,source=${source_root},target=/ror-source,readonly" \
        "${image}")"
    container_created=1
}

wait_for_systemd() {
    local attempt
    local container_state

    dump_startup_diagnostics() {
        local details
        details="$(docker inspect --format '{{.State.Status}} exit={{.State.ExitCode}} error={{.State.Error}}' \
            "${container_id}" 2>/dev/null || echo 'inspect unavailable')"
        echo "FAIL: systemd startup diagnostics: ${details}" >&2
        docker logs --timestamps "${container_id}" >&2 || true
        if [[ "${details}" == running* ]]; then
            docker exec --user root "${container_id}" bash -c '
                printf "PID 1: "; cat /proc/1/comm 2>&1 || true
                printf "system state: "; systemctl is-system-running 2>&1 || true
                for unit in dbus.service systemd-logind.service ror-container-init.service \
                    ror-docker.service ror-vscode-user-manager.service user@1000.service; do
                    printf "Unit: %s\n" "$unit"
                    systemctl show "$unit" --property=LoadState,ActiveState,SubState,Result --no-pager 2>&1 || true
                done
                systemctl --failed --no-pager 2>&1 || true
                journalctl -b -n 100 --no-pager 2>&1 || true
            ' >&2 || true
        fi
    }

    for ((attempt = 1; attempt <= 60; attempt++)); do
        if docker exec --user root "${container_id}" systemctl is-active --quiet ror-vscode-user-manager.service 2>/dev/null; then
            docker exec --user root "${container_id}" bash /ror-source/tests/wolfi-systemd-runtime-smoke.sh
            return
        fi
        container_state="$(docker inspect --format '{{.State.Status}}' "${container_id}" 2>/dev/null || true)"
        case "${container_state}" in
            exited|dead|removing)
                dump_startup_diagnostics
                echo "FAIL: container stopped before the vscode user manager became active" >&2
                return 1
                ;;
        esac
        sleep 1
    done
    dump_startup_diagnostics
    echo "FAIL: systemd user manager did not become active in ${container_id}" >&2
    return 1
}

user_manager() {
    docker exec --user vscode \
        --env XDG_RUNTIME_DIR=/run/user/1000 \
        --env DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus \
        "${container_id}" bash "/ror-source/tests/wolfi-systemd-user-manager-smoke.sh" "$@"
}

homebrew_service() {
    docker exec --user vscode \
        --env XDG_RUNTIME_DIR=/run/user/1000 \
        --env DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus \
        --env T3CODE_HOME="/tmp/ror-wolfi-systemd-smoke-${suffix}" \
        "${container_id}" bash /ror-source/tests/wolfi-systemd-homebrew-smoke.sh "$@"
}

start_container
wait_for_systemd
homebrew_service setup
user_manager setup
user_manager verify

# Stopping and starting the same disposable container keeps only the test HOME.
docker stop --time 30 "${container_id}" >/dev/null
docker start "${container_id}" >/dev/null
wait_for_systemd
user_manager verify
homebrew_service verify
homebrew_service cleanup

# Recreate with the test-only persisted HOME; other anonymous runtime state is new.
docker rm -f "${container_id}" >/dev/null
container_created=0
container_id=""
start_container
wait_for_systemd
user_manager verify
homebrew_service setup
user_manager verify
homebrew_service cleanup
user_manager cleanup

# Exercise RoR's existing Docker, rootless Podman, home, and native runtime checks.
docker exec -i --user root "${container_id}" bash --noprofile --norc -s < "${scripts}/docker-smoke.sh"
docker exec -i --user vscode "${container_id}" bash --noprofile --norc -s < "${scripts}/podman-smoke.sh"
docker exec --user root "${container_id}" bash /ror-source/.github/scripts/home-smoke.sh
docker exec -t --user root -e TERM=xterm-ghostty "${container_id}" \
    bash /ror-source/.github/scripts/ghostty-smoke.sh root
docker exec -t --user vscode -e TERM=xterm-ghostty "${container_id}" \
    bash /ror-source/.github/scripts/ghostty-smoke.sh vscode
docker exec --user root "${container_id}" bash /ror-source/tests/runtime-native-smoke.sh --in-container
bash "${source_root}/tests/runtime-docker-image-smoke.sh" "${image}"

if docker exec --user root "${container_id}" test -c /dev/kvm; then
    python3 "${source_root}/tests/wolfi-kvm-test.py"
    docker exec --user root "${container_id}" bash -lc 'id vscode | grep -q kvm'
else
    echo "NOT RUN: KVM device is unavailable in the disposable CI container"
fi

echo "PASS: Wolfi systemd PID 1, delegated system/user managers, Homebrew service, lifecycle, Docker, Podman, and RoR startup contracts"
