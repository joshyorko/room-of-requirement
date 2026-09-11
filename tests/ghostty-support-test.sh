#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GHOSTTY_DIR="${ROOT_DIR}/src/common/ghostty"
INSTALLER="${ROOT_DIR}/src/common/scripts/install-ghostty-support.sh"
BASHRC="${ROOT_DIR}/src/common/config/.bashrc"
ZSHRC="${ROOT_DIR}/src/common/config/.zshrc"
RUNTIME_SMOKE="${ROOT_DIR}/.github/scripts/runtime-smoke.sh"
GHOSTTY_SMOKE="${ROOT_DIR}/.github/scripts/ghostty-smoke.sh"
DOCKERFILES=(
    "${ROOT_DIR}/src/ubuntu-noble/.devcontainer/Dockerfile"
    "${ROOT_DIR}/src/debian-trixie/.devcontainer/Dockerfile"
    "${ROOT_DIR}/src/wolfi/.devcontainer/Dockerfile"
)

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

for path in \
    "${GHOSTTY_DIR}/terminfo/xterm-ghostty.terminfo" \
    "${GHOSTTY_DIR}/shell-integration/bash/bash-preexec.sh" \
    "${GHOSTTY_DIR}/shell-integration/bash/ghostty.bash" \
    "${GHOSTTY_DIR}/shell-integration/zsh/ghostty-integration" \
    "${GHOSTTY_DIR}/LICENSE" \
    "${GHOSTTY_DIR}/SOURCE.md" \
    "${INSTALLER}" \
    "${GHOSTTY_SMOKE}"; do
    [[ -f "${path}" ]] || fail "Ghostty support file is missing: ${path}"
done

[[ -x "${INSTALLER}" ]] || fail "Ghostty installer must be executable"
[[ -x "${GHOSTTY_SMOKE}" ]] || fail "Ghostty runtime smoke must be executable"
for script in "${INSTALLER}" "${GHOSTTY_SMOKE}" "${BASHRC}"; do
    bash -n "$script"
done
# Zsh syntax and behavior are checked in each provisioned image.

grep -Fqx 'xterm-ghostty|ghostty|Ghostty,' \
    "${GHOSTTY_DIR}/terminfo/xterm-ghostty.terminfo" || \
    fail "terminfo source must retain Ghostty's terminal aliases"
grep -Fq 'v1.3.1' "${GHOSTTY_DIR}/SOURCE.md" || \
    fail "Ghostty source metadata must pin v1.3.1"
grep -Fq '332b2aefc6e72d363aa93ab6ecfc86eeeeb5ed28' "${GHOSTTY_DIR}/SOURCE.md" || \
    fail "Ghostty source metadata must pin the resolved commit"
grep -Eq '[0-9a-f]{64}' "${GHOSTTY_DIR}/SOURCE.md" || \
    fail "Ghostty source metadata must record an asset checksum"

grep -Fq 'tic -x' "${INSTALLER}" || fail "Ghostty installer must preserve extended capabilities"
grep -Fq 'infocmp -x xterm-ghostty' "${INSTALLER}" || \
    fail "Ghostty installer must verify the installed terminal"

grep -Fq 'TERM:-' "${BASHRC}" || fail "Bash integration must inspect TERM"
grep -Fq 'xterm-ghostty' "${BASHRC}" || fail "Bash integration must target Ghostty"
grep -Fq '/usr/share/ror/ghostty/shell-integration/bash/ghostty.bash' "${BASHRC}" || \
    fail "Bash integration must use the image-local asset"
grep -Fq 'TERM:-' "${ZSHRC}" || fail "Zsh integration must inspect TERM"
grep -Fq 'xterm-ghostty' "${ZSHRC}" || fail "Zsh integration must target Ghostty"
grep -Fq '/usr/share/ror/ghostty/shell-integration/zsh/ghostty-integration' "${ZSHRC}" || \
    fail "Zsh integration must use the image-local asset"
grep -Fq 'GHOSTTY_RESOURCES_DIR' "${BASHRC}" && \
    fail "Bash integration must not depend on the host Ghostty resource path"
grep -Fq 'GHOSTTY_RESOURCES_DIR' "${ZSHRC}" && \
    fail "Zsh integration must not depend on the host Ghostty resource path"

for dockerfile in "${DOCKERFILES[@]}"; do
    grep -Fq 'install-ghostty-support.sh' "${dockerfile}" || \
        fail "${dockerfile} must install shared Ghostty support"
    grep -Fq 'src/common/ghostty' "${dockerfile}" || \
        fail "${dockerfile} must copy shared Ghostty assets"
done
grep -Fq 'ncurses-bin' "${DOCKERFILES[0]}" || fail "Ubuntu must declare ncurses tooling"
grep -Fq 'ncurses-bin' "${DOCKERFILES[1]}" || fail "Debian must declare ncurses tooling"
grep -Eq '^[[:space:]]+ncurses(-dev)?[[:space:]]*\\?$' "${DOCKERFILES[2]}" || \
    fail "Wolfi must declare ncurses tooling"

grep -Fq 'ghostty-smoke.sh' "${RUNTIME_SMOKE}" || \
    fail "runtime smoke must execute the Ghostty contract"

echo "Ghostty support contract tests passed"
