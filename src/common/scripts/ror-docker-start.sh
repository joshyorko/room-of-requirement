#!/usr/bin/env bash
set -euo pipefail

log() {
    echo "[Docker] $*" >&2
}

run_as_root() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    else
        sudo "$@"
    fi
}

data_root_fstype() {
    if [ -n "${ROR_DOCKER_TEST_DATA_ROOT_FSTYPE:-}" ]; then
        echo "${ROR_DOCKER_TEST_DATA_ROOT_FSTYPE}"
        return
    fi

    if [ "${ROR_DOCKER_TEST_HAS_FINDMNT:-1}" != "0" ] && command -v findmnt >/dev/null 2>&1; then
        findmnt -T "${DOCKER_DATA_ROOT}" -no FSTYPE 2>/dev/null | head -n 1 || true
        return
    fi

    awk -v target="${DOCKER_DATA_ROOT}" '
        function unescape_mount(path) {
            gsub(/\\040/, " ", path)
            gsub(/\\011/, "\t", path)
            gsub(/\\012/, "\n", path)
            gsub(/\\134/, "\\", path)
            return path
        }

        {
            mount_point = unescape_mount($2)
            if (target == mount_point || index(target, mount_point "/") == 1 || mount_point == "/") {
                mount_len = length(mount_point)
                if (mount_len > best_len) {
                    best_len = mount_len
                    fstype = $3
                }
            }
        }

        END { print fstype }
    ' "${ROR_DOCKER_TEST_PROC_MOUNTS:-/proc/mounts}" 2>/dev/null || true
}

has_fuse_overlayfs() {
    if [ -n "${ROR_DOCKER_TEST_HAS_FUSE_OVERLAYFS:-}" ]; then
        [ "${ROR_DOCKER_TEST_HAS_FUSE_OVERLAYFS}" = "1" ]
        return
    fi

    command -v fuse-overlayfs >/dev/null 2>&1
}

has_dev_fuse() {
    if [ -n "${ROR_DOCKER_TEST_HAS_DEV_FUSE:-}" ]; then
        [ "${ROR_DOCKER_TEST_HAS_DEV_FUSE}" = "1" ]
        return
    fi

    [ -c /dev/fuse ]
}

auto_storage_driver() {
    local fstype
    fstype="$(data_root_fstype)"

    case "${fstype}" in
        overlay | overlayfs)
            if has_fuse_overlayfs && has_dev_fuse; then
                echo "fuse-overlayfs"
            else
                echo "vfs"
            fi
            ;;
        *)
            echo ""
            ;;
    esac
}

selected_storage_driver() {
    local requested="${ROR_DOCKER_STORAGE_DRIVER:-auto}"

    case "${requested}" in
        "" | auto)
            auto_storage_driver
            ;;
        fuse-overlayfs | overlay2 | vfs)
            echo "${requested}"
            ;;
        default | none | overlayfs)
            echo ""
            ;;
        *)
            log "Warning: unsupported ROR_DOCKER_STORAGE_DRIVER=${requested}; falling back to auto"
            auto_storage_driver
            ;;
    esac
}

dockerd_entrypoint() {
    if [ "${ROR_DOCKER_TEST_HAS_DOCKERD_ENTRYPOINT:-}" = "0" ]; then
        return 1
    fi

    [ -x /usr/bin/dockerd-entrypoint.sh ]
}

dockerd_bin() {
    if [ -n "${ROR_DOCKER_TEST_DOCKERD_BIN:-}" ]; then
        echo "${ROR_DOCKER_TEST_DOCKERD_BIN}"
        return
    fi

    command -v dockerd 2>/dev/null || true
}

prepare_dind_runtime() {
    run_as_root find /run /var/run -iname 'docker*.pid' -delete 2>/dev/null || true
    run_as_root find /run /var/run -iname 'container*.pid' -delete 2>/dev/null || true

    if [ -d /sys/kernel/security ] && ! mountpoint -q /sys/kernel/security; then
        run_as_root mount -t securityfs none /sys/kernel/security 2>/dev/null || \
            log "Warning: could not mount /sys/kernel/security"
    fi
}

usage() {
    cat <<'USAGE'
Usage: ror-docker-start.sh [--socket PATH] [--link-default true|false] [--dry-run]

Environment:
  ROR_DOCKER_STORAGE_DRIVER=auto|fuse-overlayfs|vfs|overlay2|default
USAGE
}

DOCKER_SOCKET="/var/run/docker.sock"
LINK_DEFAULT="true"
DRY_RUN="${ROR_DOCKER_START_DRY_RUN:-}"
DOCKER_DATA_ROOT="${ROR_DOCKER_DATA_ROOT:-/var/lib/docker}"

while [ "$#" -gt 0 ]; do
    case "$1" in
        --socket)
            DOCKER_SOCKET="$2"
            shift 2
            ;;
        --link-default)
            LINK_DEFAULT="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN="1"
            shift
            ;;
        -h | --help)
            usage
            exit 0
            ;;
        *)
            log "Unknown argument: $1"
            usage >&2
            exit 2
            ;;
    esac
done

DOCKER_HOST_VALUE="unix://${DOCKER_SOCKET}"

if [ -z "${DRY_RUN}" ]; then
    run_as_root mkdir -p "${DOCKER_DATA_ROOT}" "$(dirname "${DOCKER_SOCKET}")"
fi

STORAGE_DRIVER="$(selected_storage_driver)"
DOCKERD_ARGS=(dockerd "--host=${DOCKER_HOST_VALUE}")

if [ -n "${STORAGE_DRIVER}" ]; then
    DOCKERD_ARGS+=("--storage-driver=${STORAGE_DRIVER}")
fi

DOCKERD_COMMAND=()
if dockerd_entrypoint; then
    DOCKERD_COMMAND=(/usr/bin/dockerd-entrypoint.sh "${DOCKERD_ARGS[@]}")
    DOCKERD_STARTER="dockerd-entrypoint.sh"
else
    DOCKERD_BIN="$(dockerd_bin)"
    if [ -n "${DOCKERD_BIN}" ]; then
        DOCKERD_COMMAND=("${DOCKERD_BIN}" "${DOCKERD_ARGS[@]:1}")
        DOCKERD_STARTER="${DOCKERD_BIN}"
    fi
fi

if [ -n "${DRY_RUN}" ]; then
    printf '%q ' "${DOCKERD_COMMAND[@]}"
    printf '\n'
    exit 0
fi

if [ "${#DOCKERD_COMMAND[@]}" -eq 0 ]; then
    log "Warning: neither dockerd-entrypoint.sh nor dockerd was found"
    exit 0
fi

prepare_dind_runtime

if [ -n "${STORAGE_DRIVER}" ]; then
    log "Starting Docker daemon on ${DOCKER_SOCKET} with ${DOCKERD_STARTER} and storage driver ${STORAGE_DRIVER}"
else
    log "Starting Docker daemon on ${DOCKER_SOCKET} with ${DOCKERD_STARTER} and Docker default storage driver"
fi

if [ "$(id -u)" -eq 0 ]; then
    "${DOCKERD_COMMAND[@]}" &
else
    sudo "${DOCKERD_COMMAND[@]}" &
fi

for i in $(seq 1 30); do
    if [ -S "${DOCKER_SOCKET}" ]; then
        log "Docker daemon socket is ready"
        break
    fi

    if [ "$i" -eq 30 ]; then
        log "Warning: Docker daemon did not create ${DOCKER_SOCKET} within 30s"
    fi

    sleep 1
done

if [ -S "${DOCKER_SOCKET}" ]; then
    run_as_root chown root:docker "${DOCKER_SOCKET}" 2>/dev/null || true
    run_as_root chmod 660 "${DOCKER_SOCKET}" 2>/dev/null || true
fi

if [ "${DOCKER_SOCKET}" != "/var/run/docker.sock" ] && [ -S "${DOCKER_SOCKET}" ]; then
    run_as_root mkdir -p /var/run
    if [ "${LINK_DEFAULT}" = "true" ] && [ ! -S /var/run/docker.sock ]; then
        run_as_root ln -sf "${DOCKER_SOCKET}" /var/run/docker.sock
        run_as_root chmod 755 /var/run 2>/dev/null || true
        log "Linked /var/run/docker.sock -> ${DOCKER_SOCKET}"
    else
        run_as_root mkdir -p /etc/profile.d
        printf 'export DOCKER_HOST=%s\n' "${DOCKER_HOST_VALUE}" | run_as_root tee /etc/profile.d/ror-docker-host.sh >/dev/null || true
        run_as_root chmod 644 /etc/profile.d/ror-docker-host.sh 2>/dev/null || true
        log "Persisted DOCKER_HOST for new shells (${DOCKER_HOST_VALUE})"
    fi
fi
