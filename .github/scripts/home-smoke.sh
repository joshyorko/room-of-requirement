#!/usr/bin/env bash
# Required image acceptance, never the portable hosted-shell mode of this test.
set -euo pipefail

test "$(id -u)" = 0
id vscode >/dev/null
sudo -n true
sudo -n -u vscode true
source_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export ROR_REQUIRE_PRIVILEGED_TESTS=1
bash "$source_root/tests/vscode-home-contract-test.sh"
