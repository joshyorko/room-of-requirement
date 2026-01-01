# Release & Semantic Versioning

This repository supports semantic versioned releases for container images.

## How it works
- A dedicated workflow `.github/workflows/release-publish.yaml` triggers on `push` to tags matching `v*` (for example: `v1.2.3`).
- The release workflow builds and pushes the image with both the tag (e.g. `ghcr.io/joshyorko/ror:v1.2.3`) and `latest`.

## Creating a release
- Create an annotated git tag locally and push it, for example:

  git tag -a v1.2.3 -m "Release v1.2.3"
  git push origin v1.2.3

- The `release-publish` workflow will run and publish the `v1.2.3` image.

## Notes
- We keep `latest` pointing to the latest release tag produced by the release workflow. The main `build-and-push` workflow still publishes `latest` on merges for convenience.
- Consider using a release manager action or GitHub Releases for changelog automation in the future.
