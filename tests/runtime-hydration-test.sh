#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HYDRATOR="${ROOT_DIR}/src/common/post-create.sh"
JUSTFILE="${ROOT_DIR}/src/common/justfile"
MISE_CONFIG="${ROOT_DIR}/src/common/config/mise.toml"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

temp_root="$(mktemp -d)"
trap 'rm -rf "${temp_root}"' EXIT
export ROR_TEST_CALL_LOG="${temp_root}/calls.log"
export ROR_MISE_CACHE_SEEDER="${temp_root}/missing-mise-cache-seeder"

record_call() {
    printf '%s\n' "$*" >> "${ROR_TEST_CALL_LOG}"
}

brew() {
    record_call "brew $*"
    if [ "${1:-}" = "--version" ]; then
        printf 'Homebrew fixture\n'
    fi
    if [ "${1:-}" = "bundle" ]; then
        return "${ROR_TEST_BREW_STATUS:-0}"
    fi
}

mise() {
    record_call "mise $*"
    case "$*" in
        "activate bash")
            return 0
            ;;
        "tasks ls --name-only")
            if [ "${ROR_TEST_HAS_SETUP:-0}" = "1" ]; then
                printf 'setup\n'
            fi
            ;;
        "run setup")
            return "${ROR_TEST_SETUP_STATUS:-0}"
            ;;
        "install")
            return "${ROR_TEST_MISE_STATUS:-0}"
            ;;
    esac
}

npm() {
    record_call "npm $*"
    return "${ROR_TEST_NPM_STATUS:-0}"
}

pnpm() {
    record_call "pnpm $*"
    return "${ROR_TEST_PNPM_STATUS:-0}"
}

yarn() {
    record_call "yarn $*"
    return "${ROR_TEST_YARN_STATUS:-0}"
}

export -f record_call brew mise npm pnpm yarn

assert_call() {
    local expected="$1"
    grep -Fxq "${expected}" "${ROR_TEST_CALL_LOG}" || \
        fail "expected call '${expected}'; got: $(tr '\n' ';' < "${ROR_TEST_CALL_LOG}")"
}

assert_no_call_matching() {
    local pattern="$1"
    if grep -Eq "${pattern}" "${ROR_TEST_CALL_LOG}"; then
        fail "unexpected call matching '${pattern}': $(tr '\n' ';' < "${ROR_TEST_CALL_LOG}")"
    fi
}

all_project="${temp_root}/all-project"
mkdir -p "${all_project}/.devcontainer"
printf 'brew "jq"\n' > "${all_project}/Brewfile"
printf 'brew "yq"\n' > "${all_project}/.devcontainer/Brewfile"
printf '[tools]\nnode = "24"\n' > "${all_project}/.mise.toml"
printf '{}\n' > "${all_project}/package.json"
printf '{}\n' > "${all_project}/package-lock.json"
: > "${ROR_TEST_CALL_LOG}"
bash "${HYDRATOR}" "${all_project}" > "${temp_root}/all-output.log" 2>&1

assert_call "brew bundle install --file=Brewfile"
assert_call "brew bundle install --file=.devcontainer/Brewfile"
assert_call "mise install"
assert_call "npm ci"
assert_no_call_matching '^brew update([[:space:]]|$)'
assert_no_call_matching '^mise install node@'
assert_no_call_matching '^npm install -g '
assert_no_call_matching '^npm cache clean'

npm_failure="${temp_root}/npm-failure"
mkdir -p "${npm_failure}"
printf '{}\n' > "${npm_failure}/package.json"
printf '{}\n' > "${npm_failure}/package-lock.json"
: > "${ROR_TEST_CALL_LOG}"
set +e
ROR_TEST_NPM_STATUS=42 bash "${HYDRATOR}" "${npm_failure}" \
    > "${temp_root}/npm-failure.log" 2>&1
npm_status=$?
set -e
[[ "${npm_status}" -ne 0 ]] || fail "npm dependency failure must fail hydration"
if grep -q 'completed successfully' "${temp_root}/npm-failure.log"; then
    fail "failed npm hydration must not report success"
fi

brew_failure="${temp_root}/brew-failure"
mkdir -p "${brew_failure}"
printf 'brew "jq"\n' > "${brew_failure}/Brewfile"
: > "${ROR_TEST_CALL_LOG}"
set +e
ROR_TEST_BREW_STATUS=31 bash "${HYDRATOR}" "${brew_failure}" \
    > "${temp_root}/brew-failure.log" 2>&1
brew_status=$?
set -e
[[ "${brew_status}" -ne 0 ]] || fail "Brewfile failure must fail hydration"

mise_project="${temp_root}/mise-project"
mkdir -p "${mise_project}"
printf '[tools]\npython = "3.13"\n' > "${mise_project}/mise.toml"
: > "${ROR_TEST_CALL_LOG}"
bash "${HYDRATOR}" "${mise_project}" > "${temp_root}/mise-output.log" 2>&1
assert_call "mise install"

: > "${ROR_TEST_CALL_LOG}"
set +e
ROR_TEST_MISE_STATUS=28 bash "${HYDRATOR}" "${mise_project}" \
    > "${temp_root}/mise-failure.log" 2>&1
mise_status=$?
set -e
[[ "${mise_status}" -ne 0 ]] || fail "mise install failure must fail hydration"

: > "${ROR_TEST_CALL_LOG}"
ROR_TEST_HAS_SETUP=1 bash "${HYDRATOR}" "${mise_project}" \
    > "${temp_root}/mise-setup.log" 2>&1
assert_call "mise run setup"

: > "${ROR_TEST_CALL_LOG}"
set +e
ROR_TEST_HAS_SETUP=1 ROR_TEST_SETUP_STATUS=29 bash "${HYDRATOR}" "${mise_project}" \
    > "${temp_root}/mise-setup-failure.log" 2>&1
setup_status=$?
set -e
[[ "${setup_status}" -ne 0 ]] || fail "mise setup task failure must fail hydration"

: > "${ROR_TEST_CALL_LOG}"
just --justfile "${JUSTFILE}" --working-directory "${temp_root}" runtime-defaults \
    > "${temp_root}/runtime-defaults.log" 2>&1
assert_call "mise use --global node@lts python@latest go@latest ruby@latest"

python3 - "${MISE_CONFIG}" <<'PY'
import pathlib
import sys
import tomllib

config = tomllib.loads(pathlib.Path(sys.argv[1]).read_text())
assert "tools" not in config
assert config["settings"]["auto_install"] is False
assert config["settings"]["ruby"]["compile"] is False
PY

echo "runtime hydration tests passed"
