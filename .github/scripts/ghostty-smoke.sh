#!/usr/bin/env bash
set -euo pipefail

mode="${1:?mode must be root or vscode}"

fail() {
    echo "ghostty-smoke: $*" >&2
    exit 1
}

check_terminfo() {
    [[ "${TERM:-}" == "xterm-ghostty" ]] || fail "expected TERM=xterm-ghostty"
    env -u TERMINFO -u TERMINFO_DIRS infocmp -A /usr/share/terminfo -x xterm-ghostty >/dev/null || \
        fail "system xterm-ghostty terminfo lookup failed"
}

check_terminfo
[[ -t 1 ]] || fail "runtime smoke requires a PTY"
[[ "$(id -un)" == "$mode" ]] || fail "wrong runtime user for $mode"

case "${mode}" in
    root)
        [[ -r /usr/share/ror/ghostty/terminfo/xterm-ghostty.terminfo ]] || \
            fail "vendored terminfo source is missing"
        [[ -r /usr/share/ror/ghostty/shell-integration/bash/ghostty.bash ]] || \
            fail "vendored Bash integration is missing"
        [[ -r /usr/share/ror/ghostty/shell-integration/zsh/ghostty-integration ]] || \
            fail "vendored Zsh integration is missing"
        ;;
    vscode)
        temp_root="$(mktemp -d /tmp/ror-ghostty-smoke.XXXXXX)"
        trap 'rm -rf "${temp_root}"' EXIT
        mkdir -p "${temp_root}/home/.local/share/zinit/zinit.git"
        printf '%s\n' 'zinit() { :; }' > "${temp_root}/home/.local/share/zinit/zinit.git/zinit.zsh"
        export XDG_DATA_HOME="${temp_root}/home/.local/share"
        export GHOSTTY_RESOURCES_DIR=/nonexistent/host/ghostty

        bash_output="$(
            HOME="${temp_root}/home" TERM=xterm-ghostty \
                bash --noprofile --norc -ic '
                    source /usr/share/ror/config/.bashrc
                    declare -F __ghostty_hook >/dev/null || exit 11
                    source /usr/share/ror/config/.bashrc
                    hook_count="$(declare -p PROMPT_COMMAND | awk -F "__ghostty_hook" "{print NF - 1}")"
                    [[ "${hook_count}" == "1" ]] || exit 12
                    __ghostty_hook
                    printf "__ROR_BASH_HOOK__\n"
                '
        )"
        [[ "${bash_output}" == *"__ROR_BASH_HOOK__"* ]] || \
            fail "interactive Bash did not initialize"
        [[ "${bash_output}" == *$'\033]133;A;'* ]] || \
            fail "Bash integration did not emit a prompt marker"

        HOME="${temp_root}/home" TERM=xterm-256color \
            bash --noprofile --norc -ic '
                source /usr/share/ror/config/.bashrc
                ! declare -F __ghostty_hook >/dev/null
            ' >/dev/null 2>&1 || fail "Bash hook activated for ordinary TERM"

        HOME="${temp_root}/home" TERM=xterm-ghostty \
            bash --noprofile --norc -c '
                source /usr/share/ror/config/.bashrc
                ! declare -F __ghostty_hook >/dev/null
            ' >/dev/null 2>&1 || fail "Bash hook activated in a noninteractive shell"

        zsh_output="$(
            HOME="${temp_root}/home" ZINIT_HOME="${temp_root}/zinit" TERM=xterm-ghostty \
                zsh -f -ic '
                    source /usr/share/ror/config/.zshrc
                    source /usr/share/ror/config/.zshrc
                    (( $+functions[_ghostty_deferred_init] )) || exit 21
                    _ghostty_deferred_init
                    (( $+functions[_ghostty_precmd] )) || exit 22
                    _ghostty_precmd
                    [[ "${PS1}" == *"133;A"* ]] || exit 23
                    [[ "${(j: :)chpwd_functions}" == *"_ghostty_report_pwd"* ]] || exit 24
                    print -r -- "__ROR_ZSH_HOOK__"
                '
        )"
        [[ "${zsh_output}" == *"__ROR_ZSH_HOOK__"* ]] || \
            fail "interactive Zsh did not initialize"

        HOME="${temp_root}/home" ZINIT_HOME="${temp_root}/zinit" TERM=xterm-256color \
            zsh -f -ic '
                source /usr/share/ror/config/.zshrc
                (( ! $+functions[_ghostty_deferred_init] ))
            ' >/dev/null 2>&1 || fail "Zsh hook activated for ordinary TERM"

        HOME="${temp_root}/home" ZINIT_HOME="${temp_root}/zinit" TERM=xterm-ghostty \
            zsh -f -c '
                source /usr/share/ror/config/.zshrc
                (( ! $+functions[_ghostty_deferred_init] ))
            ' >/dev/null 2>&1 || fail "Zsh hook activated in a noninteractive shell"

        [[ "${TERM}" == "xterm-ghostty" ]] || fail "shell integration changed TERM"

        # Exercise real prompt cycles through a PTY, not only hook functions.
        cp /usr/share/ror/config/.bashrc "${temp_root}/home/.bashrc"
        cp /usr/share/ror/config/.zshrc "${temp_root}/home/.zshrc"
        command -v starship >/dev/null || fail "Starship is missing"
        for shell in bash zsh; do
            transcript="${temp_root}/${shell}.typescript"
            printf 'cd /tmp\nprintf "ROR_PTY_OK\\n"\nexit\n' | \
                HOME="${temp_root}/home" TERM=xterm-ghostty \
                script -qec "/bin/${shell} -i" "$transcript" >/dev/null
            grep -Fq $'\033]133;' "$transcript" || fail "$shell prompt markers missing"
            grep -Fq $'\033]7;kitty-shell-cwd://' "$transcript" || fail "$shell cwd markers missing"
            grep -Fq 'ROR_PTY_OK' "$transcript" || fail "$shell command failed"
        done

        for terminal in xterm-256color tmux-256color; do
            for shell in bash zsh; do
                HOME="${temp_root}/home" TERM="$terminal" \
                    "$shell" -ic 'test "$TERM" != xterm-ghostty && ! typeset -f __ghostty_hook _ghostty_precmd >/dev/null' \
                    >/dev/null 2>&1 || fail "$shell activated Ghostty for $terminal"
            done
        done
        for shell in bash zsh; do
            HOME="${temp_root}/home" TERM=xterm-ghostty ROR_GHOSTTY_SHELL_INTEGRATION=0 \
                "$shell" -ic '! typeset -f __ghostty_hook _ghostty_precmd >/dev/null' \
                >/dev/null 2>&1 || fail "$shell ignored the opt-out"
        done
        ;;
    *)
        fail "unsupported mode: ${mode}"
        ;;
esac

echo "Ghostty ${mode} runtime smoke passed"
