#!/bin/bash
# Relaxed error handling for Kubernetes environments where some commands may not exist yet
set -uo pipefail

log() {
  printf '[post-create] %s\n' "$*" || true
}

# Ensure basic directories exist
mkdir -p "${UV_CACHE_DIR:-$HOME/.cache/uv}" || log "Warning: Could not create UV cache directory"

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
else
  log "kubectl not detected; skipping client check."
fi

if command -v uv >/dev/null 2>&1; then
  log "uv cache directory prepared at ${UV_CACHE_DIR:-$HOME/.cache/uv}."
else
  log "uv not detected; cache directory created but tool not available yet."
fi

log "Post-create steps complete."

# Ensure script always exits successfully in Kubernetes environments
exit 0
