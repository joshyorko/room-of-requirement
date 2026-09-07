#!/usr/bin/env bash
set -euo pipefail

apk_world="${ROR_APK_WORLD:-/etc/apk/world}"

apk update
apk add --no-cache --upgrade \
    ca-certificates \
    openssl \
    openjpeg \
    busybox
apk cache clean

sed -i '/^gcompat\([=<>~].*\)\?$/d' "${apk_world}" 2>/dev/null || true
