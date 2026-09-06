#!/usr/bin/env bash
# Hosted regressions. Image-only suites run in runtime-smoke.sh/home-smoke.sh.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."

for tool in python3 mise jq git sudo devcontainer cosign; do
    command -v "$tool" >/dev/null || { echo "Required regression tool missing: $tool" >&2; exit 1; }
done
python3 -c 'import yaml'

for suite in tests/*-test.py; do
    echo "Running $suite"
    python3 "$suite"
done
for suite in tests/*-test.sh; do
    case "${suite##*/}" in
        # These must run in the provisioned candidate with root/vscode split.
        runtime-home-ownership-test.sh|vscode-home-contract-test.sh) continue ;;
    esac
    echo "Running $suite"
    bash "$suite"
done
