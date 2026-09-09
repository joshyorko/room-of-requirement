#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECK_SCRIPT="${ROOT_DIR}/src/common/scripts/ror-podman-runsc-check.sh"
JUSTFILE="${ROOT_DIR}/src/common/justfile"
DOCKERFILE="${ROOT_DIR}/src/wolfi/.devcontainer/Dockerfile"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

assert_contains() {
    local file="$1"
    local pattern="$2"
    local label="$3"
    grep -Eq -- "${pattern}" "${file}" || fail "${label}: ${pattern} not found in ${file}"
}

[ -f "${CHECK_SCRIPT}" ] || fail "missing bounded rootless Podman/runsc checker"
assert_contains "${JUSTFILE}" 'cgroup-check:' "cgroup diagnostic recipe"
assert_contains "${JUSTFILE}" 'podman-runsc-check' "runsc probe recipe"
assert_contains "${DOCKERFILE}" 'ror-podman-runsc-check\.sh' "Wolfi installs the checker"
assert_contains "${CHECK_SCRIPT}" 'cgroup\.subtree_control' "cgroup delegation probe"
assert_contains "${CHECK_SCRIPT}" '--network pasta' "normal network probe"
assert_contains "${CHECK_SCRIPT}" 'OCIRuntime' "running-container runtime identity"
if grep -Eq -- '(^|[[:space:]])--privileged([[:space:]]|$)|(^|[[:space:]])--ignore-cgroups([[:space:]]|$)|cgroups-disabled|--network[[:space:]]+host' \
    "${CHECK_SCRIPT}"; then
    fail "checker contains a forbidden workaround"
fi

temp_root="$(mktemp -d)"
cleanup_test() {
    chmod -R u+w "${temp_root}" 2>/dev/null || true
    rm -rf "${temp_root}"
}
trap cleanup_test EXIT

make_cgroup_tree() {
    local mode="$1"
    local root="${temp_root}/cgroup-${mode}"
    mkdir -p "${root}/current"
    printf 'cpu memory pids\n' > "${root}/cgroup.controllers"
    printf '%s\n' "$([ "${mode}" = delegated ] && echo 'cpu memory pids' || true)" \
        > "${root}/cgroup.subtree_control"
    printf 'cpu memory pids\n' > "${root}/current/cgroup.controllers"
    printf '%s\n' "$([ "${mode}" = delegated ] && echo 'cpu memory pids' || true)" \
        > "${root}/current/cgroup.subtree_control"
    printf '123\n' > "${root}/cgroup.procs"
    printf '123\n' > "${root}/current/cgroup.procs"
    if [ "${mode}" = delegated ]; then
        chmod 700 "${root}" "${root}/current"
        chmod 600 "${root}"/cgroup.{controllers,subtree_control,procs} \
            "${root}/current"/cgroup.{controllers,subtree_control,procs}
    else
        chmod 555 "${root}" "${root}/current"
        chmod 444 "${root}"/cgroup.{controllers,subtree_control,procs} \
            "${root}/current"/cgroup.{controllers,subtree_control,procs}
    fi
    printf '%s\n' "${root}"
}

blocked_root="$(make_cgroup_tree blocked)"
set +e
blocked_output="$(ROR_CGROUP_ROOT="${blocked_root}" \
    ROR_CGROUP_CURRENT_DIR="${blocked_root}/current" \
    ROR_CGROUP_FILESYSTEM=cgroup2fs \
    bash "${CHECK_SCRIPT}" --diagnose-only 2>&1)"
blocked_status=$?
set -e
[ "${blocked_status}" -eq 2 ] || fail "non-delegated cgroup fixture must return 2 (got ${blocked_status})"
printf '%s\n' "${blocked_output}" | grep -q 'controllers are visible' || \
    fail "diagnostic must distinguish controller visibility"
printf '%s\n' "${blocked_output}" | grep -q 'RESULT: BLOCKED' || \
    fail "diagnostic must identify the delegation blocker"
printf '%s\n' "${blocked_output}" | grep -q 'outer host' || \
    fail "diagnostic must identify the outer-host boundary"

delegated_root="$(make_cgroup_tree delegated)"
delegated_output="$(ROR_CGROUP_ROOT="${delegated_root}" \
    ROR_CGROUP_CURRENT_DIR="${delegated_root}/current" \
    ROR_CGROUP_FILESYSTEM=cgroup2fs \
    bash "${CHECK_SCRIPT}" --diagnose-only 2>&1)" || \
    fail "delegated cgroup fixture should pass static diagnostics"
printf '%s\n' "${delegated_output}" | grep -q 'RESULT: READY' || \
    fail "diagnostic must report a writable delegation candidate"

partial_root="$(make_cgroup_tree delegated)"
chmod 555 "${partial_root}" \
    && chmod 444 "${partial_root}"/cgroup.{controllers,subtree_control,procs}
set +e
partial_output="$(ROR_CGROUP_ROOT="${partial_root}" \
    ROR_CGROUP_CURRENT_DIR="${partial_root}/current" \
    ROR_CGROUP_FILESYSTEM=cgroup2fs \
    bash "${CHECK_SCRIPT}" --diagnose-only 2>&1)"
partial_status=$?
set -e
[ "${partial_status}" -eq 2 ] || fail "partial cgroup delegation must remain blocked"
printf '%s\n' "${partial_output}" | grep -q 'visible cgroup mount root' || \
    fail "diagnostic must identify a non-delegated visible mount root"

fake_bin="${temp_root}/bin"
mkdir -p "${fake_bin}" "${temp_root}/runtime/release-20260831.0"
runtime="${temp_root}/runtime/release-20260831.0/runsc"
cat > "${runtime}" <<'RUNTIME'
#!/usr/bin/env bash
if [ "${ROR_FAKE_HANG_STAGE:-}" = runsc ]; then
    printf '%s\n' "$$" >> "${ROR_FAKE_PODMAN_PID_FILE}"
    sleep "${ROR_FAKE_PODMAN_HANG_SECONDS:-3}" &
    child_pid=$!
    printf '%s\n' "${child_pid}" >> "${ROR_FAKE_PODMAN_PID_FILE}"
    wait "${child_pid}"
fi
echo 'runsc version release-20260831.0'
echo 'spec: 1.2.1'
RUNTIME
chmod 755 "${runtime}"

cat > "${fake_bin}/podman" <<'PODMAN'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "${ROR_FAKE_PODMAN_LOG}"

hang_real() {
    printf '%s\n' "$$" >> "${ROR_FAKE_PODMAN_PID_FILE}"
    sleep "${ROR_FAKE_PODMAN_HANG_SECONDS:-3}" &
    child_pid=$!
    printf '%s\n' "${child_pid}" >> "${ROR_FAKE_PODMAN_PID_FILE}"
    wait "${child_pid}"
}

command_name=""
for argument in "$@"; do
    case "${argument}" in
        info|run|inspect|exec|rm|rmi|images|ps) command_name="${argument}"; break ;;
    esac
done
case "${command_name}" in
    info)
        if [ "${ROR_FAKE_HANG_STAGE:-}" = info ]; then
            hang_real
        fi
        printf 'true cgroupfs netavark\n'
        ;;
    run)
        if [ "${ROR_FAKE_HANG_STAGE:-}" = before ] ||
            [ "${ROR_FAKE_HANG_STAGE:-}" = pull ]; then
            hang_real
        fi
        : > "${ROR_FAKE_PODMAN_STATE}"
        if [ "${ROR_FAKE_PODMAN_RUN_STATUS:-0}" -ne 0 ]; then
            echo 'Error: cannot set up cgroup for root: open /sys/fs/cgroup/cgroup.subtree_control: permission denied' >&2
            exit "${ROR_FAKE_PODMAN_RUN_STATUS}"
        fi
        if [ "${ROR_FAKE_HANG_STAGE:-}" = after ]; then
            hang_real
        fi
        echo fake-container-id
        ;;
    inspect)
        printf 'true runsc\n'
        ;;
    exec)
        if [ "${ROR_FAKE_HANG_STAGE:-}" = exec ]; then
            hang_real
        fi
        printf 'synthetic=ok network=ok\n'
        ;;
    rm)
        rm -f "${ROR_FAKE_PODMAN_STATE}"
        ;;
    rmi)
        ;;
    images)
        if [ "${ROR_FAKE_HANG_STAGE:-}" = cleanup ] &&
            [[ " $* " == *' --quiet --no-trunc '* ]] &&
            [ ! -f "${ROR_FAKE_PODMAN_CLEANUP_ONCE:-}" ]; then
            : > "${ROR_FAKE_PODMAN_CLEANUP_ONCE}"
            hang_real
        fi
        if [[ " $* " == *' --format json '* ]]; then
            printf '[]\n'
        elif [ -f "${ROR_FAKE_PODMAN_STATE}" ]; then
            printf 'sha256:fake-image\n'
        fi
        ;;
    ps)
        if [ -f "${ROR_FAKE_PODMAN_STATE}" ]; then
            printf '[{"State":"created"}]\n'
        else
            printf '[]\n'
        fi
        ;;
esac
PODMAN
chmod 755 "${fake_bin}/podman"

run_probe() {
    local label="$1"
    local hang_mode="${2:-}"
    local operation_timeout="${3:-1}"
    local overall_timeout="${4:-8}"
    local cleanup_timeout="${5:-1}"
    local cleanup_overall_timeout="${6:-4}"
    local run_status="${7:-0}"
    local status=0
    local started_seconds="${SECONDS}"
    set +e
    PATH="${fake_bin}:${PATH}" \
        ROR_PODMAN_BIN="${fake_bin}/podman" \
        ROR_CGROUP_ROOT="${delegated_root}" \
        ROR_CGROUP_CURRENT_DIR="${delegated_root}/current" \
        ROR_CGROUP_FILESYSTEM=cgroup2fs \
        ROR_RUNSC_PROBE_EVIDENCE_DIR="${temp_root}/evidence-${label}" \
        ROR_RUNSC_PROBE_OPERATION_TIMEOUT_SECONDS="${operation_timeout}" \
        ROR_RUNSC_PROBE_OVERALL_TIMEOUT_SECONDS="${overall_timeout}" \
        ROR_RUNSC_PROBE_CLEANUP_TIMEOUT_SECONDS="${cleanup_timeout}" \
        ROR_RUNSC_PROBE_CLEANUP_OVERALL_TIMEOUT_SECONDS="${cleanup_overall_timeout}" \
        ROR_FAKE_PODMAN_LOG="${temp_root}/podman-${label}.log" \
        ROR_FAKE_PODMAN_STATE="${temp_root}/podman-${label}.state" \
        ROR_FAKE_PODMAN_PID_FILE="${temp_root}/podman-${label}.pids" \
        ROR_FAKE_PODMAN_CLEANUP_ONCE="${temp_root}/podman-${label}.cleanup-once" \
        ROR_FAKE_HANG_STAGE="${hang_mode}" \
        ROR_FAKE_PODMAN_HANG_SECONDS="3" \
        ROR_FAKE_PODMAN_RUN_STATUS="${run_status}" \
        bash "${CHECK_SCRIPT}" --runtime "${runtime}" > "${temp_root}/probe-${label}.log" 2>&1
    status=$?
    RUN_PROBE_DURATION=$((SECONDS - started_seconds))
    set -e
    return "${status}"
}

run_probe pass || fail "bounded fake runtime probe should pass"
assert_contains "${temp_root}/probe-pass.log" 'RESULT: PASS' "successful probe result"
assert_contains "${temp_root}/podman-pass.log" '--network pasta' "normal pasta networking"
assert_contains "${temp_root}/podman-pass.log" 'inspect' "running-container runtime identity"
assert_contains "${temp_root}/podman-pass.log" 'rm --force' "owned container cleanup"
assert_contains "${temp_root}/podman-pass.log" 'rmi --force sha256:fake-image' "owned image cleanup"
if grep -Eq -- '--privileged|--ignore-cgroups|cgroups-disabled|--network host' \
    "${temp_root}/podman-pass.log"; then
    fail "probe contains a forbidden workaround"
fi

if run_probe blocked "" 1 8 1 4 126; then
    fail "cgroup failure must block the bounded probe"
else
    blocked_probe_status=$?
fi
[ "${blocked_probe_status}" -eq 2 ] || \
    fail "cgroup failure must block the bounded probe (got ${blocked_probe_status})"
assert_contains "${temp_root}/probe-blocked.log" 'RESULT: BLOCKED' "blocked probe result"
assert_contains "${temp_root}/podman-blocked.log" 'rm --force' "failed probe cleans created container"
assert_contains "${temp_root}/podman-blocked.log" 'rmi --force sha256:fake-image' "failed probe cleans pulled image"
if [ -f "${temp_root}/podman-blocked.state" ]; then
    fail "failed probe left its owned container state"
fi

assert_hang_is_bounded() {
    local label="$1"
    local mode="$2"
    local operation_timeout="${3:-1}"
    local overall_timeout="${4:-8}"
    local status

    if run_probe "${label}" "${mode}" "${operation_timeout}" "${overall_timeout}"; then
        fail "${label} hanging child must fail closed"
    else
        status=$?
    fi
    [ "${status}" -ne 0 ] || fail "${label} hanging child returned success"
    [ "${RUN_PROBE_DURATION}" -lt 4 ] || fail "${label} exceeded its bounded test window"
    assert_contains "${temp_root}/probe-${label}.log" 'timed out|TIMEOUT|RESULT: BLOCKED|RESULT: FAIL' \
        "${label} timeout/failure result"
    if grep -q 'RESULT: PASS' "${temp_root}/probe-${label}.log"; then
        fail "${label} emitted PASS after a timeout"
    fi
    [ -s "${temp_root}/podman-${label}.pids" ] || fail "${label} did not run a real hanging executable"
    while IFS= read -r pid; do
        [ -n "${pid}" ] || continue
        if kill -0 "${pid}" 2>/dev/null; then
            fail "${label} left hanging process ${pid} alive"
        fi
    done < "${temp_root}/podman-${label}.pids"
}

assert_hang_is_bounded runsc runsc
assert_hang_is_bounded info info
assert_hang_is_bounded pull pull
assert_hang_is_bounded before before
assert_hang_is_bounded after after
assert_hang_is_bounded overall before 5 2
assert_hang_is_bounded exec exec

if run_probe cleanup cleanup 1 8 1 3; then
    fail "cleanup hanging child must fail closed"
else
    cleanup_status=$?
fi
[ "${cleanup_status}" -ne 0 ] || fail "cleanup hanging child returned success"
[ "${RUN_PROBE_DURATION}" -lt 4 ] || fail "cleanup hanging child exceeded its bounded test window"
assert_contains "${temp_root}/probe-cleanup.log" 'cleanup|timed out|TIMEOUT|RESULT: FAIL' \
    "cleanup timeout/failure result"
if grep -q 'RESULT: PASS' "${temp_root}/probe-cleanup.log"; then
    fail "cleanup timeout emitted PASS"
fi
assert_contains "${temp_root}/podman-cleanup.log" 'images --quiet --no-trunc' \
    "cleanup attempted after cleanup hang"
assert_contains "${temp_root}/podman-cleanup.log" 'rm --force' \
    "container cleanup attempted after cleanup hang"
while IFS= read -r pid; do
    [ -n "${pid}" ] || continue
    if kill -0 "${pid}" 2>/dev/null; then
        fail "cleanup left hanging process ${pid} alive"
    fi
done < "${temp_root}/podman-cleanup.pids"

echo "Podman/runsc diagnostic and bounded probe tests passed"
