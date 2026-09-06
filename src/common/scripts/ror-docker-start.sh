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

validate_daemon_config() {
    local config_path="$1"

    [ -f "${config_path}" ] || return 0
    command -v jq >/dev/null 2>&1 || {
        log "jq is required to parse Docker daemon configuration"
        return 1
    }
    jq -e '
        type == "object" and
        ((.["storage-driver"] == null) or (.["storage-driver"] | type == "string")) and
        ((.["data-root"] == null) or (.["data-root"] | type == "string"))
    ' "${config_path}" >/dev/null || {
        log "Invalid Docker daemon configuration: ${config_path}"
        return 1
    }
}

daemon_config_value() {
    local config_path="$1"
    local key="$2"

    [ -f "${config_path}" ] || return 0
    jq -r --arg key "${key}" '.[$key] // empty' "${config_path}"
}

auto_storage_driver() {
    local fstype
    fstype="$(data_root_fstype)"

    case "${fstype}" in
        fuse.fuse-overlayfs | fuse-overlayfs)
            # A FUSE-backed outer graph store cannot reliably host another
            # overlay mount, including fuse-overlayfs. Keep nested writes plain.
            echo "vfs"
            ;;
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
            if [ -n "${CONFIGURED_STORAGE_DRIVER}" ]; then
                echo "${CONFIGURED_STORAGE_DRIVER}"
            else
                auto_storage_driver
            fi
            ;;
        fuse-overlayfs | overlay2 | vfs)
            echo "${requested}"
            ;;
        default | none | overlayfs)
            echo ""
            ;;
        *)
            log "Warning: unsupported ROR_DOCKER_STORAGE_DRIVER=${requested}; falling back to auto"
            if [ -n "${CONFIGURED_STORAGE_DRIVER}" ]; then
                echo "${CONFIGURED_STORAGE_DRIVER}"
            else
                auto_storage_driver
            fi
            ;;
    esac
}

write_effective_config() {
    local source_path="$1"
    local target_path="$2"
    local temporary_path

    # Docker 29 otherwise defaults to containerd's overlayfs image store even
    # when this helper needs a classic FUSE/vfs graph driver for nested storage.
    # Reject an explicit conflicting store choice instead of overwriting it.
    temporary_path="$(mktemp)"
    if [ -f "${source_path}" ]; then
        jq \
            --arg storage_driver "${STORAGE_DRIVER}" \
            --arg data_root "${DOCKER_DATA_ROOT}" \
            '
                del(.hosts)
                | if $storage_driver == "" then
                    del(.["storage-driver"])
                else
                    .["storage-driver"] = $storage_driver
                end
                | .["data-root"] = $data_root
                | if $storage_driver == "fuse-overlayfs" or $storage_driver == "vfs" or $storage_driver == "overlay2" then
                    if .features["containerd-snapshotter"] == true then
                        error("Selected graph driver requires containerd-snapshotter=false; use ROR_DOCKER_STORAGE_DRIVER=default to keep the explicit containerd image store")
                    else
                        .features["containerd-snapshotter"] = false
                    end
                  else . end
            ' "${source_path}" > "${temporary_path}"
    else
        jq -n \
            --arg storage_driver "${STORAGE_DRIVER}" \
            --arg data_root "${DOCKER_DATA_ROOT}" \
            '
                {"data-root": $data_root}
                | if $storage_driver == "" then . else .["storage-driver"] = $storage_driver end
                | if $storage_driver == "fuse-overlayfs" or $storage_driver == "vfs" or $storage_driver == "overlay2" then
                    .features["containerd-snapshotter"] = false
                  else . end
            ' > "${temporary_path}"
    fi

    run_as_root mkdir -p "$(dirname "${target_path}")"
    run_as_root install -m 0644 "${temporary_path}" "${target_path}"
    rm -f "${temporary_path}"
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

docker_bin() {
    if [ -n "${ROR_DOCKER_TEST_DOCKER_BIN:-}" ]; then
        echo "${ROR_DOCKER_TEST_DOCKER_BIN}"
        return
    fi

    command -v docker 2>/dev/null || true
}

docker_api_ready() {
    local client_bin="$1"

    "${client_bin}" --host "${DOCKER_HOST_VALUE}" info >/dev/null 2>&1
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
  ROR_DOCKER_DATA_ROOT=/path/to/docker-data
  ROR_DOCKER_DAEMON_CONFIG=/path/to/daemon.json
USAGE
}

DOCKER_SOCKET="/var/run/docker.sock"
DEFAULT_SOCKET="${ROR_DOCKER_TEST_DEFAULT_SOCKET:-/var/run/docker.sock}"
PROFILE_DIR="${ROR_DOCKER_TEST_PROFILE_DIR:-/etc/profile.d}"
LINK_DEFAULT="true"
DRY_RUN="${ROR_DOCKER_START_DRY_RUN:-}"
SOURCE_CONFIG="${ROR_DOCKER_DAEMON_CONFIG:-/etc/docker/daemon.json}"
EFFECTIVE_CONFIG="${ROR_DOCKER_EFFECTIVE_CONFIG:-/run/ror/docker-daemon.json}"

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

validate_daemon_config "${SOURCE_CONFIG}"
CONFIGURED_STORAGE_DRIVER="$(daemon_config_value "${SOURCE_CONFIG}" "storage-driver")"
CONFIGURED_DATA_ROOT="$(daemon_config_value "${SOURCE_CONFIG}" "data-root")"
DOCKER_DATA_ROOT="${ROR_DOCKER_DATA_ROOT:-${CONFIGURED_DATA_ROOT:-/var/lib/docker}}"
STORAGE_DRIVER="$(selected_storage_driver)"
write_effective_config "${SOURCE_CONFIG}" "${EFFECTIVE_CONFIG}"

if [ -z "${DRY_RUN}" ]; then
    run_as_root mkdir -p "${DOCKER_DATA_ROOT}" "$(dirname "${DOCKER_SOCKET}")"
fi

DOCKERD_ARGS=(dockerd "--host=${DOCKER_HOST_VALUE}" "--config-file=${EFFECTIVE_CONFIG}")

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
elif [ -n "${CONFIGURED_STORAGE_DRIVER}" ]; then
    log "Starting Docker daemon on ${DOCKER_SOCKET} with ${DOCKERD_STARTER} and daemon config storage driver ${CONFIGURED_STORAGE_DRIVER}"
else
    log "Starting Docker daemon on ${DOCKER_SOCKET} with ${DOCKERD_STARTER} and Docker default storage driver"
fi

if [ "$(id -u)" -eq 0 ]; then
    "${DOCKERD_COMMAND[@]}" &
else
    sudo "${DOCKERD_COMMAND[@]}" &
fi
DOCKERD_PID=$!

DOCKER_BIN="$(docker_bin)"
if [ -z "${DOCKER_BIN}" ]; then
    log "Docker CLI not found; cannot verify daemon API readiness"
    kill "${DOCKERD_PID}" 2>/dev/null || true
    wait "${DOCKERD_PID}" 2>/dev/null || true
    exit 1
fi

START_TIMEOUT="${ROR_DOCKER_START_TIMEOUT_SECONDS:-30}"
if ! [[ "${START_TIMEOUT}" =~ ^[1-9][0-9]*$ ]]; then
    log "Invalid ROR_DOCKER_START_TIMEOUT_SECONDS=${START_TIMEOUT}"
    kill "${DOCKERD_PID}" 2>/dev/null || true
    wait "${DOCKERD_PID}" 2>/dev/null || true
    exit 2
fi

for ((i = 1; i <= START_TIMEOUT; i++)); do
    if docker_api_ready "${DOCKER_BIN}"; then
        log "Docker daemon API is ready"
        break
    fi

    if ! kill -0 "${DOCKERD_PID}" 2>/dev/null; then
        if wait "${DOCKERD_PID}"; then
            daemon_status=1
        else
            daemon_status=$?
        fi
        log "Docker daemon exited before API readiness (status ${daemon_status})"
        exit "${daemon_status}"
    fi

    if [ "${i}" -eq "${START_TIMEOUT}" ]; then
        log "Docker daemon API did not become ready at ${DOCKER_HOST_VALUE} within ${START_TIMEOUT}s"
        kill "${DOCKERD_PID}" 2>/dev/null || true
        wait "${DOCKERD_PID}" 2>/dev/null || true
        exit 1
    fi

    sleep 1
done

if [ -S "${DOCKER_SOCKET}" ]; then
    run_as_root chown root:docker "${DOCKER_SOCKET}" 2>/dev/null || true
    run_as_root chmod 660 "${DOCKER_SOCKET}" 2>/dev/null || true
fi

if [ "${DOCKER_SOCKET}" != "${DEFAULT_SOCKET}" ] && [ -S "${DOCKER_SOCKET}" ]; then
    run_as_root mkdir -p "$(dirname "${DEFAULT_SOCKET}")"
    if [ "${LINK_DEFAULT}" = "true" ] && [ ! -S "${DEFAULT_SOCKET}" ]; then
        run_as_root ln -sf "${DOCKER_SOCKET}" "${DEFAULT_SOCKET}"
        run_as_root chmod 755 "$(dirname "${DEFAULT_SOCKET}")" 2>/dev/null || true
        log "Linked ${DEFAULT_SOCKET} -> ${DOCKER_SOCKET}"
    else
        run_as_root mkdir -p "${PROFILE_DIR}"
        printf 'export DOCKER_HOST=%s\n' "${DOCKER_HOST_VALUE}" | run_as_root tee "${PROFILE_DIR}/ror-docker-host.sh" >/dev/null || true
        run_as_root chmod 644 "${PROFILE_DIR}/ror-docker-host.sh" 2>/dev/null || true
        log "Persisted DOCKER_HOST for new shells (${DOCKER_HOST_VALUE})"
    fi
fi
