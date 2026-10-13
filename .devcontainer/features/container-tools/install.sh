#!/usr/bin/env bash
set -euo pipefail

bundle="${ROR_CONTAINER_TOOLS_BUNDLE:-/usr/local/share/ror/container-tools}"
exec bash "${bundle}/install.sh"
