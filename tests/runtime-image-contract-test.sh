#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APK_WRAPPER="${ROOT_DIR}/src/wolfi/scripts/apk-wrapper.sh"
SECURITY_UPDATE="${ROOT_DIR}/src/wolfi/scripts/security-update.sh"
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
call_log="${temp_root}/calls.log"
world_file="${temp_root}/world"

[ -f "${APK_WRAPPER}" ] || fail "maintained apk wrapper is missing"
[ -f "${SECURITY_UPDATE}" ] || fail "maintained Wolfi security update script is missing"

cat > "${temp_root}/apk-real" <<'APK_REAL'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${ROR_APK_TEST_CALL_LOG}"
exit "${ROR_APK_TEST_REAL_STATUS:-0}"
APK_REAL
chmod +x "${temp_root}/apk-real"

run_wrapper() {
    ROR_APK_REAL="${temp_root}/apk-real" \
        ROR_APK_WORLD="${world_file}" \
        ROR_APK_TEST_CALL_LOG="${call_log}" \
        ROR_APK_TEST_REAL_STATUS="${ROR_APK_TEST_REAL_STATUS:-0}" \
        bash "${APK_WRAPPER}" "$@"
}

printf 'busybox\ngcompat\n' > "${world_file}"
: > "${call_log}"
set +e
ROR_APK_TEST_REAL_STATUS=23 run_wrapper update
update_status=$?
set -e
[[ "${update_status}" -eq 23 ]] || fail "apk update failure was not propagated"
grep -Fxq 'update' "${call_log}" || fail "one-argument apk update was not delegated"

: > "${call_log}"
run_wrapper --version
grep -Fxq -- '--version' "${call_log}" || fail "apk --version was not delegated"

: > "${call_log}"
run_wrapper add --no-cache gcompat
[[ ! -s "${call_log}" ]] || fail "gcompat-only add should not invoke apk.real"

: > "${call_log}"
set +e
ROR_APK_TEST_REAL_STATUS=19 run_wrapper add --no-cache gcompat curl
add_status=$?
set -e
[[ "${add_status}" -eq 19 ]] || fail "filtered apk add failure was not propagated"
grep -Fxq 'add --no-cache curl' "${call_log}" || \
    fail "apk add did not preserve options and supported package operands"

: > "${call_log}"
run_wrapper add 'gcompat=1.2.3' gcompat-extra curl
grep -Fxq 'add gcompat-extra curl' "${call_log}" || \
    fail "apk wrapper must filter versioned gcompat without filtering similarly named packages"

: > "${call_log}"
run_wrapper add --repository https://packages.example.invalid gcompat
[[ ! -s "${call_log}" ]] || fail "apk add options must not count as package operands"

: > "${call_log}"
run_wrapper info gcompat
grep -Fxq 'info gcompat' "${call_log}" || \
    fail "gcompat filtering must be limited to apk add package operands"
if grep -Fxq 'gcompat' "${world_file}"; then
    fail "apk wrapper did not remove stale gcompat world entry"
fi

update_bin="${temp_root}/update-bin"
mkdir -p "${update_bin}"
cat > "${update_bin}/apk" <<'APK'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${ROR_APK_TEST_CALL_LOG}"
case "$1" in
    update)
        exit "${ROR_APK_TEST_UPDATE_STATUS:-0}"
        ;;
    add)
        exit "${ROR_APK_TEST_ADD_STATUS:-0}"
        ;;
    cache)
        exit "${ROR_APK_TEST_CACHE_STATUS:-0}"
        ;;
esac
APK
chmod +x "${update_bin}/apk"

run_security_update() {
    PATH="${update_bin}:/usr/bin:/bin" \
        ROR_APK_WORLD="${world_file}" \
        ROR_APK_TEST_CALL_LOG="${call_log}" \
        ROR_APK_TEST_UPDATE_STATUS="${ROR_APK_TEST_UPDATE_STATUS:-0}" \
        ROR_APK_TEST_ADD_STATUS="${ROR_APK_TEST_ADD_STATUS:-0}" \
        ROR_APK_TEST_CACHE_STATUS="${ROR_APK_TEST_CACHE_STATUS:-0}" \
        bash "${SECURITY_UPDATE}"
}

for failure in update add cache; do
    : > "${call_log}"
    set +e
    case "${failure}" in
        update) ROR_APK_TEST_UPDATE_STATUS=41 run_security_update ;;
        add) ROR_APK_TEST_ADD_STATUS=42 run_security_update ;;
        cache) ROR_APK_TEST_CACHE_STATUS=43 run_security_update ;;
    esac
    status=$?
    set -e
    [[ "${status}" -ne 0 ]] || fail "apk ${failure} failure must fail the image update"
done

for dockerfile in "${DOCKERFILES[@]}"; do
    if grep -Eq '^[[:space:]]*HEALTHCHECK' "${dockerfile}"; then
        fail "${dockerfile} must omit the meaningless healthcheck"
    fi
    if grep -Eq 'useradd.*linuxbrew|su[[:space:]]+-[[:space:]]+linuxbrew|chown[[:space:]]+-R[[:space:]]+vscode:vscode[[:space:]]+/home/linuxbrew' \
        "${dockerfile}"; then
        fail "${dockerfile} must install Homebrew with vscode as its final owner"
    fi
    grep -Eq 'su[[:space:]]+-[[:space:]]+vscode[[:space:]]+-c.*Homebrew/install' "${dockerfile}" || \
        fail "${dockerfile} must run the Homebrew installer as vscode"
done

for package in build-base ruby-dev playwright; do
    grep -Eq "^[[:space:]]*${package}[[:space:]\\]*$" "${WOLFI_DOCKERFILE}" || \
        fail "Wolfi must retain ${package} capability"
done

grep -Eq 'src/wolfi/scripts/security-update.sh[[:space:]]+/usr/local/bin/ror-security-update.sh' \
    "${WOLFI_DOCKERFILE}" || fail "Wolfi image must execute the maintained security update script"
grep -Eq 'src/wolfi/scripts/apk-wrapper.sh[[:space:]]+/sbin/apk' \
    "${WOLFI_DOCKERFILE}" || fail "Wolfi image must install the maintained apk wrapper"

echo "runtime image contract tests passed"
