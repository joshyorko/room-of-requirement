#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

ACT_BIN=${ACT_BIN:-act}
WORKFLOW_FILE="${ROOT_DIR}/.github/workflows/rcc-maintenance.yml"
ARTIFACT_DIR=${ARTIFACT_DIR:-"${ROOT_DIR}/.act/artifacts"}
PLATFORM=${ACT_PLATFORM:-"ubuntu-latest=ghcr.io/catthehacker/ubuntu:custom-latest"}

MAINT_PUSH=${MAINTENANCE_PUSH:-false}
MAINT_BRANCH=${MAINTENANCE_TARGET_BRANCH:-maintenance/dry-run}

mkdir -p "${ARTIFACT_DIR}"

EXTRA_ARGS=("$@")

if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  EXTRA_ARGS+=("--secret" "GITHUB_TOKEN=${GITHUB_TOKEN}")
else
  printf 'Warning: GITHUB_TOKEN not set. Release downloads may be rate limited or fail for private assets.\n' >&2
fi

printf 'Using MAINTENANCE_PUSH=%s, MAINTENANCE_TARGET_BRANCH=%s\n' "${MAINT_PUSH}" "${MAINT_BRANCH}"
printf 'Act platform mapping: %s\n' "${PLATFORM}"

"${ACT_BIN}" -W "${WORKFLOW_FILE}" -j maintenance \
  --artifact-server-path "${ARTIFACT_DIR}" \
  --platform "${PLATFORM}" \
  --env MAINTENANCE_PUSH="${MAINT_PUSH}" \
  --env MAINTENANCE_TARGET_BRANCH="${MAINT_BRANCH}" \
  "${EXTRA_ARGS[@]}"
