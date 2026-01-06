#!/bin/bash
# Build the devcontainer using Podman/Buildah with cache injection
# Usage: ./automation/build-podman.sh [--with-cache]
#
# Options:
#   --with-cache    Inject existing volume caches into image for instant startup
#   --push          Push to registry after build
#
# This script provides two build modes:
# 1. Standard: Uses devcontainer CLI with Podman backend
# 2. Cached:   Uses Buildah to inject Homebrew/mise caches into image layers

set -e

IMAGE_NAME="${IMAGE_NAME:-ghcr.io/joshyorko/ror:latest}"
CACHED_IMAGE_NAME="${IMAGE_NAME%:*}:cached"
WITH_CACHE=false
PUSH=false

# Parse arguments
for arg in "$@"; do
  case $arg in
    --with-cache) WITH_CACHE=true ;;
    --push) PUSH=true ;;
    *) echo "Unknown argument: $arg"; exit 1 ;;
  esac
done

echo "==> Building DevContainer with Podman..."
echo "    Image: $IMAGE_NAME"

# Step 1: Build base image using devcontainer CLI with Podman
devcontainer build \
  --workspace-folder "$(dirname "$0")/.." \
  --docker-path podman \
  --image-name "$IMAGE_NAME"

echo "==> Base image built: $IMAGE_NAME"

# Step 2: If --with-cache, use Buildah to inject volume caches
if [ "$WITH_CACHE" = true ]; then
  echo ""
  echo "==> Injecting caches with Buildah..."

  # Check if cache volumes exist
  HOMEBREW_CACHE_EXISTS=$(podman volume exists ror-homebrew-cache && echo "yes" || echo "no")
  MISE_CACHE_EXISTS=$(podman volume exists ror-mise-cache && echo "yes" || echo "no")
  NPM_CACHE_EXISTS=$(podman volume exists ror-npm-cache && echo "yes" || echo "no")

  if [ "$HOMEBREW_CACHE_EXISTS" = "no" ] && [ "$MISE_CACHE_EXISTS" = "no" ] && [ "$NPM_CACHE_EXISTS" = "no" ]; then
    echo "    No cache volumes found. Run the container first to populate caches."
    echo "    Skipping cache injection."
  else
    # Export volume data to temp directory, then use buildah to inject
    TEMP_DIR=$(mktemp -d)
    trap "rm -rf $TEMP_DIR" EXIT

    echo "    Exporting volume data..."

    # Export each cache volume using a temporary container
    if [ "$HOMEBREW_CACHE_EXISTS" = "yes" ]; then
      echo "    - Exporting Homebrew cache..."
      mkdir -p "$TEMP_DIR/homebrew"
      podman run --rm -v ror-homebrew-cache:/source:ro -v "$TEMP_DIR/homebrew:/dest" \
        alpine sh -c "cp -a /source/. /dest/ 2>/dev/null || true"
    fi

    if [ "$MISE_CACHE_EXISTS" = "yes" ]; then
      echo "    - Exporting mise cache..."
      mkdir -p "$TEMP_DIR/mise"
      podman run --rm -v ror-mise-cache:/source:ro -v "$TEMP_DIR/mise:/dest" \
        alpine sh -c "cp -a /source/. /dest/ 2>/dev/null || true"
    fi

    if [ "$NPM_CACHE_EXISTS" = "yes" ]; then
      echo "    - Exporting npm cache..."
      mkdir -p "$TEMP_DIR/npm"
      podman run --rm -v ror-npm-cache:/source:ro -v "$TEMP_DIR/npm:/dest" \
        alpine sh -c "cp -a /source/. /dest/ 2>/dev/null || true"
    fi

    # Check if we actually got any data
    if [ -z "$(ls -A "$TEMP_DIR" 2>/dev/null)" ]; then
      echo "    No cache data found in volumes. Skipping injection."
    else
      echo "    Injecting caches into image..."

      # Create working container
      CONTAINER=$(buildah from "$IMAGE_NAME")
      echo "    Created container: $CONTAINER"

      # Use buildah copy to inject the caches (works rootless)
      if [ -d "$TEMP_DIR/homebrew" ] && [ -n "$(ls -A "$TEMP_DIR/homebrew" 2>/dev/null)" ]; then
        echo "    - Injecting Homebrew cache..."
        buildah copy --chown 1000:1000 "$CONTAINER" "$TEMP_DIR/homebrew" /home/linuxbrew/.cache/Homebrew
      fi

      if [ -d "$TEMP_DIR/mise" ] && [ -n "$(ls -A "$TEMP_DIR/mise" 2>/dev/null)" ]; then
        echo "    - Injecting mise cache..."
        buildah copy --chown 1000:1000 "$CONTAINER" "$TEMP_DIR/mise" /home/vscode/.local/share/mise
      fi

      if [ -d "$TEMP_DIR/npm" ] && [ -n "$(ls -A "$TEMP_DIR/npm" 2>/dev/null)" ]; then
        echo "    - Injecting npm cache..."
        buildah copy --chown 1000:1000 "$CONTAINER" "$TEMP_DIR/npm" /home/vscode/.npm
      fi

      # Commit the cached image
      buildah commit "$CONTAINER" "$CACHED_IMAGE_NAME"
      buildah rm "$CONTAINER"

      echo ""
      echo "==> Cached image built: $CACHED_IMAGE_NAME"
      echo "    This image has caches baked in for instant startup."

      # Update IMAGE_NAME for push step
      IMAGE_NAME="$CACHED_IMAGE_NAME"
    fi
  fi
fi

# Step 3: Push if requested
if [ "$PUSH" = true ]; then
  echo ""
  echo "==> Pushing image to registry..."
  podman push "$IMAGE_NAME"
  echo "    Pushed: $IMAGE_NAME"
fi

echo ""
echo "==> Build complete!"
echo ""
echo "To use this image:"
echo "  1. Update devcontainer.json to use: \"image\": \"$IMAGE_NAME\""
echo "  2. Or run: podman run -it --privileged $IMAGE_NAME"
