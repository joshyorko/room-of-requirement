#!/usr/bin/env bash
# Diagnose cgroup v2 delegation and, when given an absolute runsc path, run a
# bounded credential-free rootless Podman probe. The probe owns only its
# isolated storage/runroot and the container/image named below.
set -Eeuo pipefail

umask 077

DEFAULT_IMAGE="docker.io/library/alpine:3.22"
CGROUP_ROOT="${ROR_CGROUP_ROOT:-/sys/fs/cgroup}"
CGROUP_PROC="${ROR_CGROUP_PROC:-/proc/self/cgroup}"
CGROUP_MOUNTINFO="${ROR_CGROUP_MOUNTINFO:-/proc/self/mountinfo}"
CGROUP_MOUNTPOINT="${ROR_CGROUP_MOUNTPOINT:-/sys/fs/cgroup}"
PODMAN_BIN="${ROR_PODMAN_BIN:-podman}"
RUNTIME_PATH=""
IMAGE="${DEFAULT_IMAGE}"
EVIDENCE_PARENT="${ROR_RUNSC_PROBE_EVIDENCE_DIR:-}"
DIAGNOSE_ONLY=0

usage() {
    cat <<'USAGE'
Usage:
  ror-podman-runsc-check.sh --diagnose-only
  ror-podman-runsc-check.sh --runtime /absolute/path/to/runsc [--image IMAGE]

The full probe requires an absolute executable runsc path, runs as a
non-root user, uses isolated VFS storage and an empty registry auth file,
requests normal pasta networking, and verifies the runtime from a running
container. It never changes cgroup ownership or permissions.

Options:
  --diagnose-only       Report cgroup v2 visibility and delegation only.
  --runtime PATH        Complete pinned runsc bundle's absolute runsc path.
  --image IMAGE         Disposable public image (default: docker.io/library/alpine:3.22).
  --evidence-dir DIR    Retain the owned probe log under DIR.
  -h, --help            Show this help.
USAGE
}

log() {
    local message="$*"
    if [ -n "${LOG_FILE:-}" ]; then
        printf '%s\n' "${message}" | tee -a "${LOG_FILE}"
    else
        printf '%s\n' "${message}"
    fi
}

log_error() {
    local message="$*"
    if [ -n "${LOG_FILE:-}" ]; then
        printf '%s\n' "${message}" | tee -a "${LOG_FILE}" >&2
    else
        printf '%s\n' "${message}" >&2
    fi
}

log_command() {
    local rendered
    printf -v rendered '%q ' "$@"
    log "+ ${rendered}"
}

run_logged() {
    local status
    log_command "$@"
    set +e
    "$@" 2>&1 | tee -a "${LOG_FILE}"
    status="${PIPESTATUS[0]}"
    set -e
    log "exit=${status}"
    return "${status}"
}

capture_logged() {
    local output_file="$1"
    shift
    local status
    log_command "$@"
    set +e
    "$@" >"${output_file}" 2>&1
    status=$?
    set -e
    tee -a "${LOG_FILE}" <"${output_file}"
    log "exit=${status}"
    return "${status}"
}

file_contents() {
    local path="$1"
    if [ -r "${path}" ]; then
        tr '\n' ' ' <"${path}" | sed 's/[[:space:]]*$//' || true
    else
        printf '<unreadable>'
    fi
}

file_metadata() {
    local path="$1"
    if [ ! -e "${path}" ]; then
        printf 'missing'
        return
    fi
    local owner mode writable
    owner="$(stat -c '%u:%g' "${path}" 2>/dev/null || printf '?')"
    mode="$(stat -c '%a' "${path}" 2>/dev/null || printf '?')"
    if [ -w "${path}" ]; then
        writable=yes
    else
        writable=no
    fi
    printf 'owner=%s mode=%s writable=%s' "${owner}" "${mode}" "${writable}"
}

current_cgroup_dir() {
    if [ -n "${ROR_CGROUP_CURRENT_DIR:-}" ]; then
        printf '%s\n' "${ROR_CGROUP_CURRENT_DIR}"
        return
    fi

    local cgroup_path
    cgroup_path="$(awk -F: '$1 == "0" { print $3; exit }' "${CGROUP_PROC}" 2>/dev/null || true)"
    [ -n "${cgroup_path}" ] || cgroup_path="/"
    case "${cgroup_path}" in
        /*) ;;
        *) cgroup_path="/${cgroup_path}" ;;
    esac
    if [ "${cgroup_path}" = "/" ]; then
        printf '%s\n' "${CGROUP_ROOT}"
    else
        printf '%s%s\n' "${CGROUP_ROOT%/}" "${cgroup_path}"
    fi
}

cgroup_mount_line() {
    [ -r "${CGROUP_MOUNTINFO}" ] || return 0
    awk -v mountpoint="${CGROUP_MOUNTPOINT}" '
        $5 == mountpoint {
            for (i = 6; i <= NF; i++) {
                if ($i == "-") {
                    if ($(i + 1) == "cgroup2") print $0
                    exit
                }
            }
        }
    ' "${CGROUP_MOUNTINFO}"
}

candidate_is_writable() {
    local directory="$1"
    [ -d "${directory}" ] || return 1
    [ -w "${directory}" ] || return 1
    [ -w "${directory}/cgroup.procs" ] || return 1
    [ -w "${directory}/cgroup.subtree_control" ] || return 1
}

print_remediation() {
    local uid
    uid="$(id -u)"
    log "Required outer host/orchestrator change (not an image fix):"
    log "  Allocate a dedicated cgroup v2 subtree for this workspace, enable the needed controllers in its ancestors,"
    log "  place the outer workspace process in that subtree, and delegate it to uid ${uid}."
    log "  The delegatee needs write access to the subtree directory, cgroup.procs, and cgroup.subtree_control."
    log "  A cgroup namespace boundary with nsdelegate may provide the equivalent namespace delegation."
    log "Re-run this check as the target unprivileged user after the outer delegation is provisioned."
    log "Do not use --ignore-cgroups, disabled cgroups, host networking, a fallback runtime, or blanket privileged mode."
}

diagnose_cgroups() {
    local uid filesystem mount_line mount_fstype mount_options mount_super
    local current_dir root_available root_subtree current_available current_subtree
    local root_candidate=0 current_candidate=0

    uid="$(id -u)"
    filesystem="${ROR_CGROUP_FILESYSTEM:-}"
    if [ -z "${filesystem}" ]; then
        filesystem="$(stat -fc '%T' "${CGROUP_ROOT}" 2>/dev/null || printf 'unknown')"
    fi
    current_dir="$(current_cgroup_dir)"
    mount_line="$(cgroup_mount_line || true)"
    mount_fstype="$(printf '%s\n' "${mount_line}" | awk -F' - ' 'NF > 1 {print $2}' | awk '{print $1}')"
    mount_options="$(printf '%s\n' "${mount_line}" | awk '{print $6}')"
    mount_super="$(printf '%s\n' "${mount_line}" | awk -F' - ' 'NF > 1 {print $2}' | awk '{print $3}')"

    log "=== Room of Requirement rootless Podman/runsc cgroup check ==="
    log "Checking uid=${uid} (root is not a valid rootless result)"
    log "cgroup root: ${CGROUP_ROOT} ($(file_metadata "${CGROUP_ROOT}"))"
    log "cgroup filesystem: ${filesystem}"
    if [ -n "${mount_line}" ]; then
        log "cgroup mount: fstype=${mount_fstype:-unknown} options=${mount_options:-unknown} super_options=${mount_super:-unknown}"
    else
        log "cgroup mount: no cgroup2 mount record found at ${CGROUP_MOUNTPOINT}"
    fi
    log "current cgroup: ${current_dir}"

    case "${filesystem}" in
        cgroup2fs | cgroup2) ;;
        *)
            log "controller visibility: unavailable for cgroup v2 (filesystem=${filesystem})"
            log "RESULT: BLOCKED (cgroup v2 is not mounted at the diagnostic root)"
            print_remediation
            return 2
            ;;
    esac

    if [ ! -f "${CGROUP_ROOT}/cgroup.controllers" ]; then
        log "controller visibility: unavailable (missing cgroup.controllers)"
        log "RESULT: BLOCKED (cgroup v2 is not visible)"
        print_remediation
        return 2
    fi

    root_available="$(file_contents "${CGROUP_ROOT}/cgroup.controllers")"
    root_subtree="$(file_contents "${CGROUP_ROOT}/cgroup.subtree_control")"
    current_available="$(file_contents "${current_dir}/cgroup.controllers")"
    current_subtree="$(file_contents "${current_dir}/cgroup.subtree_control")"
    log "controller visibility (availability only; not delegation):"
    log "  root cgroup.controllers: ${root_available}"
    log "  root cgroup.subtree_control: ${root_subtree}"
    log "  current cgroup.controllers: ${current_available}"
    log "  current cgroup.subtree_control: ${current_subtree}"
    log "delegation access:"
    log "  root directory: $(file_metadata "${CGROUP_ROOT}")"
    log "  root cgroup.procs: $(file_metadata "${CGROUP_ROOT}/cgroup.procs")"
    log "  root cgroup.subtree_control: $(file_metadata "${CGROUP_ROOT}/cgroup.subtree_control")"
    log "  current directory: $(file_metadata "${current_dir}")"
    log "  current cgroup.procs: $(file_metadata "${current_dir}/cgroup.procs")"
    log "  current cgroup.subtree_control: $(file_metadata "${current_dir}/cgroup.subtree_control")"

    if candidate_is_writable "${CGROUP_ROOT}"; then
        root_candidate=1
    fi
    if [ "${current_dir}" != "${CGROUP_ROOT}" ] && candidate_is_writable "${current_dir}"; then
        current_candidate=1
    fi

    if [ "${root_candidate}" -eq 1 ]; then
        log "RESULT: READY (a writable cgroup delegation candidate is visible to uid ${uid})"
        log "This is only a static prerequisite; run the full absolute-runsc probe for runtime viability."
        return 0
    fi

    if [ "${current_candidate}" -eq 1 ]; then
        log "RESULT: BLOCKED (the current cgroup is writable, but the visible cgroup mount root is not; runsc may need to configure that root)"
        print_remediation
        return 2
    fi

    log "RESULT: BLOCKED (controllers are visible, but no cgroup directory + cgroup.procs + cgroup.subtree_control is writable by uid ${uid})"
    print_remediation
    return 2
}

# shellcheck disable=SC2329 # Invoked indirectly by the EXIT trap.
cleanup_probe() {
    local cleanup_status=0 image_ids_file final_ps_file final_images_file image_id compact
    [ "${PROBE_INITIALIZED:-0}" -eq 1 ] || return 0

    image_ids_file="${PROBE_DIR}/image-ids.txt"
    final_ps_file="${PROBE_DIR}/final-ps.json"
    final_images_file="${PROBE_DIR}/final-images.json"

    if ! capture_logged "${image_ids_file}" "${PODMAN_BASE[@]}" images --quiet --no-trunc; then
        cleanup_status=1
    fi

    if [ -n "${CONTAINER_NAME:-}" ]; then
        if run_logged "${PODMAN_BASE[@]}" container exists "${CONTAINER_NAME}"; then
            if ! run_logged "${PODMAN_BASE[@]}" rm --force "${CONTAINER_NAME}"; then
                cleanup_status=1
            fi
        fi
    fi

    if [ -f "${image_ids_file}" ]; then
        while IFS= read -r image_id; do
            [ -n "${image_id}" ] || continue
            if ! run_logged "${PODMAN_BASE[@]}" rmi --force "${image_id}"; then
                cleanup_status=1
            fi
        done <"${image_ids_file}"
    fi

    if ! capture_logged "${final_ps_file}" "${PODMAN_BASE[@]}" ps --all --format json; then
        cleanup_status=1
    else
        compact="$(tr -d '[:space:]' <"${final_ps_file}")"
        if [ "${compact}" != "[]" ]; then
            log_error "FAIL: owned Podman container cleanup is not empty: ${compact}"
            cleanup_status=1
        fi
    fi
    if ! capture_logged "${final_images_file}" "${PODMAN_BASE[@]}" images --format json; then
        cleanup_status=1
    else
        compact="$(tr -d '[:space:]' <"${final_images_file}")"
        if [ "${compact}" != "[]" ]; then
            log_error "FAIL: owned Podman image cleanup is not empty: ${compact}"
            cleanup_status=1
        fi
    fi
    return "${cleanup_status}"
}

# shellcheck disable=SC2329 # Invoked indirectly by the EXIT trap.
finish_probe() {
    local main_status=$? cleanup_status
    trap - EXIT
    set +e
    cleanup_probe
    cleanup_status=$?
    if [ "${cleanup_status}" -ne 0 ]; then
        log_error "FAIL: owned probe cleanup did not complete; evidence retained at ${PROBE_DIR}"
        [ "${main_status}" -eq 0 ] && main_status=1
    fi
    if [ "${main_status}" -eq 0 ]; then
        log "RESULT: PASS (runsc identity, synthetic execution, normal networking, and cleanup verified)"
    elif [ "${main_status}" -eq 2 ]; then
        log "RESULT: BLOCKED (the outer runtime could not provide the required rootless cgroup delegation)"
        print_remediation
    else
        log "RESULT: FAIL (probe did not satisfy the runtime contract)"
    fi
    log "Evidence retained at ${PROBE_DIR}"
    exit "${main_status}"
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --diagnose-only)
            DIAGNOSE_ONLY=1
            shift
            ;;
        --runtime)
            [ "$#" -ge 2 ] || { usage >&2; exit 64; }
            RUNTIME_PATH="$2"
            shift 2
            ;;
        --image)
            [ "$#" -ge 2 ] || { usage >&2; exit 64; }
            IMAGE="$2"
            shift 2
            ;;
        --evidence-dir)
            [ "$#" -ge 2 ] || { usage >&2; exit 64; }
            EVIDENCE_PARENT="$2"
            shift 2
            ;;
        -h | --help)
            usage
            exit 0
            ;;
        *)
            printf 'Unknown argument: %s\n' "$1" >&2
            usage >&2
            exit 64
            ;;
    esac
done

if [ "${DIAGNOSE_ONLY}" -eq 1 ]; then
    diagnose_cgroups
    exit "$?"
fi

if [ -z "${RUNTIME_PATH}" ] || [[ "${RUNTIME_PATH}" != /* ]]; then
    printf 'ERROR: --runtime must be an absolute executable path from the complete pinned bundle\n' >&2
    exit 64
fi
if [ ! -x "${RUNTIME_PATH}" ]; then
    printf 'ERROR: runsc is not executable: %s\n' "${RUNTIME_PATH}" >&2
    exit 64
fi
case "${IMAGE}" in
    "" | -* | *[[:space:]]*)
        printf 'ERROR: --image must be a non-empty image reference without whitespace or option syntax\n' >&2
        exit 64
        ;;
esac

if [ "$(id -u)" -eq 0 ]; then
    printf 'ERROR: run the full probe as the target unprivileged user; root cannot prove rootless delegation\n' >&2
    exit 2
fi
command -v "${PODMAN_BIN}" >/dev/null 2>&1 || {
    printf 'ERROR: Podman is not available: %s\n' "${PODMAN_BIN}" >&2
    exit 1
}
PODMAN_BIN="$(command -v "${PODMAN_BIN}")"

if [ -z "${XDG_RUNTIME_DIR:-}" ]; then
    candidate_runtime_dir="/run/user/$(id -u)"
    if [ -d "${candidate_runtime_dir}" ]; then
        export XDG_RUNTIME_DIR="${candidate_runtime_dir}"
    fi
fi

if [ -n "${EVIDENCE_PARENT}" ]; then
    if [ ! -e "${EVIDENCE_PARENT}" ]; then
        mkdir -m 700 -- "${EVIDENCE_PARENT}"
    fi
    [ -d "${EVIDENCE_PARENT}" ] || {
        printf 'ERROR: evidence path is not a directory: %s\n' "${EVIDENCE_PARENT}" >&2
        exit 64
    }
    [ "$(stat -c '%u' "${EVIDENCE_PARENT}")" = "$(id -u)" ] || {
        printf 'ERROR: evidence directory must be owned by the invoking user: %s\n' "${EVIDENCE_PARENT}" >&2
        exit 64
    }
    PROBE_DIR="$(mktemp -d "${EVIDENCE_PARENT%/}/runsc-probe.XXXXXX")"
else
    PROBE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/ror-podman-runsc-check.XXXXXX")"
fi
chmod 700 "${PROBE_DIR}"
LOG_FILE="${PROBE_DIR}/probe.log"
: >"${LOG_FILE}"
PODMAN_BASE=(
    "${PODMAN_BIN}"
    --root "${PROBE_DIR}/storage"
    --runroot "${PROBE_DIR}/runroot"
    --storage-driver vfs
    --runtime "${RUNTIME_PATH}"
    --cgroup-manager cgroupfs
)
mkdir -m 700 "${PROBE_DIR}/storage" "${PROBE_DIR}/runroot" \
    "${PROBE_DIR}/config" "${PROBE_DIR}/docker-config"
AUTH_FILE="${PROBE_DIR}/auth.json"
printf '{"auths":{}}\n' >"${AUTH_FILE}"
chmod 600 "${AUTH_FILE}"
export REGISTRY_AUTH_FILE="${AUTH_FILE}"
export CONTAINERS_AUTH_FILE="${AUTH_FILE}"
export XDG_CONFIG_HOME="${PROBE_DIR}/config"
export DOCKER_CONFIG="${PROBE_DIR}/docker-config"
PROBE_INITIALIZED=1
CONTAINER_NAME="ror-runsc-probe-$(id -u)-$$"
trap finish_probe EXIT

if diagnose_cgroups >"${PROBE_DIR}/cgroup-diagnostic.txt" 2>&1; then
    diagnosis_status=0
else
    diagnosis_status=$?
fi
tee -a "${LOG_FILE}" <"${PROBE_DIR}/cgroup-diagnostic.txt"
if [ "${diagnosis_status}" -ne 0 ]; then
    log "Static cgroup diagnostic is blocked; running the real probe to preserve the exact runtime result."
fi

if ! run_logged "${RUNTIME_PATH}" --version; then
    exit 1
fi

INFO_FILE="${PROBE_DIR}/podman-info.txt"
if ! capture_logged "${INFO_FILE}" "${PODMAN_BASE[@]}" info --format '{{.Host.Security.Rootless}} {{.Host.CgroupManager}} {{.Host.NetworkBackend}}'; then
    exit 1
fi
info_rootless=""
info_cgroup_manager=""
info_network_backend=""
read -r info_rootless info_cgroup_manager info_network_backend <"${INFO_FILE}" || true
if [ "${info_rootless}" != "true" ]; then
    log_error "FAIL: Podman did not report rootless=true (reported: ${info_rootless:-empty})"
    exit 1
fi
if [ "${info_cgroup_manager}" != "cgroupfs" ]; then
    log_error "FAIL: Podman did not report cgroupfs (reported: ${info_cgroup_manager:-empty})"
    exit 1
fi
if [ -z "${info_network_backend}" ]; then
    log_error "FAIL: Podman did not report a network backend"
    exit 1
fi
log "Podman identity: rootless=${info_rootless} cgroup-manager=${info_cgroup_manager} network-backend=${info_network_backend}"

RUN_FILE="${PROBE_DIR}/podman-run.txt"
if ! capture_logged "${RUN_FILE}" "${PODMAN_BASE[@]}" run \
    --detach \
    --name "${CONTAINER_NAME}" \
    --network pasta \
    --pull always \
    --authfile "${AUTH_FILE}" \
    "${IMAGE}" sleep 120; then
    if grep -Eiq 'cannot set up cgroup|cgroup\.subtree_control.*permission denied|permission denied.*cgroup' "${RUN_FILE}"; then
        log_error "The OCI runtime reached container creation but could not configure cgroups."
        exit 2
    fi
    exit 1
fi

IDENTITY_FILE="${PROBE_DIR}/runtime-identity.txt"
if ! capture_logged "${IDENTITY_FILE}" "${PODMAN_BASE[@]}" inspect \
    --format '{{.State.Running}} {{.OCIRuntime}}' "${CONTAINER_NAME}"; then
    exit 1
fi
running_state=""
reported_runtime=""
read -r running_state reported_runtime <"${IDENTITY_FILE}" || true
case "${reported_runtime}" in
    runsc | */runsc) ;;
    *)
        log_error "FAIL: running container reported OCI runtime '${reported_runtime:-empty}', expected runsc"
        exit 1
        ;;
esac
if [ "${running_state}" != "true" ]; then
    log_error "FAIL: runtime identity was not observed on a running container (state=${running_state:-empty})"
    exit 1
fi
log "Running-container runtime identity: state=${running_state} runtime=${reported_runtime}"

EXEC_FILE="${PROBE_DIR}/container-exec.txt"
container_probe_command="test \"\$(id -u)\" -eq 0; wget -q -O /dev/null https://example.com; printf \"synthetic=ok network=ok\\n\""
if ! capture_logged "${EXEC_FILE}" "${PODMAN_BASE[@]}" exec "${CONTAINER_NAME}" \
    /bin/sh -eu -c "${container_probe_command}"; then
    exit 1
fi
grep -q 'synthetic=ok network=ok' "${EXEC_FILE}" || {
    log_error "FAIL: synthetic execution/network marker was not returned"
    exit 1
}

exit 0
