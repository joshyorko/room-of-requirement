#!/usr/bin/env bash
set -euo pipefail

source_file="/usr/share/ror/ghostty/terminfo/xterm-ghostty.terminfo"
database_dir="/usr/share/terminfo"

fail() {
    echo "install-ghostty-support: $*" >&2
    exit 1
}

[[ "$(id -u)" -eq 0 ]] || fail "must run as root"
[[ -r "${source_file}" ]] || fail "terminfo source is missing: ${source_file}"
command -v tic >/dev/null 2>&1 || fail "tic is missing"
command -v infocmp >/dev/null 2>&1 || fail "infocmp is missing"

install -d -m 0755 "${database_dir}"
tic -x -o "${database_dir}" "${source_file}"

env -u TERMINFO -u TERMINFO_DIRS TERM=xterm-ghostty \
    infocmp -x xterm-ghostty >/dev/null || \
    fail "installed xterm-ghostty entry is not readable"
