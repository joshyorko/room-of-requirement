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
echo 'runsc version release-20260831.0'
echo 'spec: 1.2.1'
RUNTIME
chmod 755 "${runtime}"

cat > "${fake_bin}/podman" <<'PODMAN'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "${ROR_FAKE_PODMAN_LOG}"
command_name=""
for argument in "$@"; do
    case "${argument}" in
        info|run|inspect|exec|rm|rmi|images|ps) command_name="${argument}"; break ;;
    esac
done
case "${command_name}" in
    info)
        printf 'true cgroupfs netavark\n'
        ;;
    run)
        : > "${ROR_FAKE_PODMAN_STATE}"
        if [ "${ROR_FAKE_PODMAN_RUN_STATUS:-0}" -ne 0 ]; then
            echo 'Error: cannot set up cgroup for root: open /sys/fs/cgroup/cgroup.subtree_control: permission denied' >&2
            exit "${ROR_FAKE_PODMAN_RUN_STATUS}"
        fi
        echo fake-container-id
        ;;
    inspect)
        printf 'true runsc\n'
        ;;
    exec)
        printf 'synthetic=ok network=ok\n'
        ;;
    rm)
        rm -f "${ROR_FAKE_PODMAN_STATE}"
        ;;
    rmi)
        ;;
    images)
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
    local status=0
    set +e
    PATH="${fake_bin}:${PATH}" \
        ROR_PODMAN_BIN="${fake_bin}/podman" \
        ROR_CGROUP_ROOT="${delegated_root}" \
        ROR_CGROUP_CURRENT_DIR="${delegated_root}/current" \
        ROR_CGROUP_FILESYSTEM=cgroup2fs \
        ROR_RUNSC_PROBE_EVIDENCE_DIR="${temp_root}/evidence-$1" \
        ROR_FAKE_PODMAN_LOG="${temp_root}/podman-$1.log" \
        ROR_FAKE_PODMAN_STATE="${temp_root}/podman-$1.state" \
        ROR_FAKE_PODMAN_RUN_STATUS="${2}" \
        bash "${CHECK_SCRIPT}" --runtime "${runtime}" > "${temp_root}/probe-$1.log" 2>&1
    status=$?
    set -e
    return "${status}"
}

run_probe pass 0 || fail "bounded fake runtime probe should pass"
assert_contains "${temp_root}/probe-pass.log" 'RESULT: PASS' "successful probe result"
assert_contains "${temp_root}/podman-pass.log" '--network pasta' "normal pasta networking"
assert_contains "${temp_root}/podman-pass.log" 'inspect' "running-container runtime identity"
assert_contains "${temp_root}/podman-pass.log" 'rm --force' "owned container cleanup"
assert_contains "${temp_root}/podman-pass.log" 'rmi --force sha256:fake-image' "owned image cleanup"
if grep -Eq -- '--privileged|--ignore-cgroups|cgroups-disabled|--network host' \
    "${temp_root}/podman-pass.log"; then
    fail "probe contains a forbidden workaround"
fi

if run_probe blocked 126; then
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

echo "Podman/runsc diagnostic and bounded probe tests passed"
