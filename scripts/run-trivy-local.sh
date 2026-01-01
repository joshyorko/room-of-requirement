#!/usr/bin/env bash
set -euo pipefail

IMAGE=${1:-ghcr.io/joshyorko/ror:latest}

echo "Running Trivy scan for image: $IMAGE"

docker run --rm -v "$PWD":/work -w /work aquasecurity/trivy:latest image --severity HIGH,CRITICAL $IMAGE

echo "Done."
