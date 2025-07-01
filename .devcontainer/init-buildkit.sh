#!/usr/bin/env bash
set -e
if command -v docker >/dev/null; then
  echo "Warming BuildKit cache via docker compose bake…"
  docker compose bake --pull --load
fi
