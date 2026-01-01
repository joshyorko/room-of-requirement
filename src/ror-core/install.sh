#!/usr/bin/env bash
# ror-core Meta-Feature install script
# Minimal install - dependencies handle all actual tool installation
# This script verifies the core tools are available after feature installation

set -e

echo "Verifying Room of Requirement Core installation..."

# Verify all dependent tools are installed
echo "Checking dependencies:"
for tool in mise starship zoxide; do
    if command -v "${tool}" &>/dev/null; then
        echo "  ✓ ${tool}"
    else
        echo "  ✗ ${tool} (missing - check feature installation)"
    fi
done

echo ""
echo "✓ Room of Requirement Core ready"
