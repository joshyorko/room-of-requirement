#!/usr/bin/env bash
set -euo pipefail

log() {
  printf '[post-create] %s\n' "$*"
}

mkdir -p "${UV_CACHE_DIR:-$HOME/.cache/uv}"

if command -v rcc >/dev/null 2>&1; then
  if ! rcc config identity -t >/dev/null 2>&1; then
    log "rcc identity configuration skipped (non-zero exit code)."
  else
    log "rcc identity configuration refreshed."
  fi
else
  log "rcc not detected on PATH; skipping identity configuration."
fi

if command -v kubectl >/dev/null 2>&1; then
  if ! kubectl version --client --output=yaml >/dev/null 2>&1; then
    log "kubectl client check skipped."
  fi
fi

if command -v uv >/dev/null 2>&1; then
  log "uv cache directory prepared at ${UV_CACHE_DIR:-$HOME/.cache/uv}."
fi

log "Post-create steps complete."
