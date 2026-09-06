#!/usr/bin/env bash
# Required image acceptance, never the portable hosted-shell mode of this test.
set -euo pipefail

test "$(id -u)" = 0
id vscode >/dev/null
sudo -n true
sudo -n -u vscode true
source_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
sudo -n -u vscode bash "$source_root/tests/vscode-home-contract-test.sh"
ROR_REQUIRE_PRIVILEGED_OWNERSHIP_TEST=1 bash "$source_root/tests/runtime-home-ownership-test.sh"
