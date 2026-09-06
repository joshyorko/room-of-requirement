#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SEEDER="${ROOT_DIR}/src/common/scripts/seed-vscode-home.sh"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

temp_root="$(mktemp -d)"
trap 'rm -rf "${temp_root}"' EXIT
shim_bin="${temp_root}/bin"
mkdir -p "${shim_bin}"

cat > "${shim_bin}/getent" <<'GETENT'
#!/usr/bin/env bash
exit 2
GETENT
cat > "${shim_bin}/ln" <<'LN'
#!/usr/bin/env bash
case "${ROR_SEED_RACE_KIND}" in
    directory)
        mkdir "${ROR_SEED_RACE_TARGET}"
        ;;
    directory-symlink)
        mkdir "${ROR_SEED_RACE_WINNER}"
        /usr/bin/ln -s "${ROR_SEED_RACE_WINNER}" "${ROR_SEED_RACE_TARGET}"
        ;;
esac
exec /usr/bin/ln "$@"
LN
chmod +x "${shim_bin}/getent" "${shim_bin}/ln"

for race_kind in directory directory-symlink; do
    fixture_root="${temp_root}/${race_kind}"
    config_root="${fixture_root}/config"
    home_root="${fixture_root}/home"
    target_path="${home_root}/.zshrc"
    winner_path="${target_path}"
    mkdir -p "${config_root}" "${home_root}"
    printf 'seed-content\n' > "${config_root}/.zshrc"
    if [ "${race_kind}" = "directory-symlink" ]; then
        winner_path="${fixture_root}/winner"
    fi

    PATH="${shim_bin}:/usr/bin:/bin" \
        ROR_SEED_RACE_KIND="${race_kind}" \
        ROR_SEED_RACE_TARGET="${target_path}" \
        ROR_SEED_RACE_WINNER="${winner_path}" \
        bash "${SEEDER}" "${home_root}" "${config_root}"

    [ -d "${winner_path}" ] || fail "${race_kind} winner is not a directory"
    [ -z "$(find "${winner_path}" -mindepth 1 -maxdepth 1 -print -quit)" ] || \
        fail "${race_kind} winner gained an entry during exclusive seeding"
done

echo "runtime home destination race tests passed"
