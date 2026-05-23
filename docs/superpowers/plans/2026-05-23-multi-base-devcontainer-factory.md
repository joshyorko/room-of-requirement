# Multi-Base Devcontainer Factory Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the repository structure and configuration needed for Room of Requirement to operate as a multi-base devcontainer image factory.

**Architecture:** Shared assets move to `src/common`, variant Dockerfiles live under `src/<variant>/.devcontainer`, and the top-level devcontainer points at Ubuntu Noble for Codespaces. The existing Wolfi behavior is preserved under `src/wolfi` while Ubuntu and Debian variants share a Microsoft base-image bootstrap.

**Tech Stack:** Dev Containers, Dockerfiles, Docker Buildx Bake, GitHub Actions, Homebrew on Linux, mise, just/ujust.

---

### Task 1: Shared Asset Extraction

**Files:**
- Create: `src/common/`
- Copy from: `.devcontainer/brew/`, `.devcontainer/config/`, `.devcontainer/scripts/`, `.devcontainer/entrypoint.sh`, `.devcontainer/first-run-notice.txt`, `.devcontainer/justfile`, `.devcontainer/post-create.sh`

- [ ] **Step 1: Create the shared directory tree**

Run:

```bash
mkdir -p src/common/{brew,config,scripts}
```

Expected: directories exist.

- [ ] **Step 2: Copy existing shared assets**

Run:

```bash
cp -a .devcontainer/brew/. src/common/brew/
cp -a .devcontainer/config/. src/common/config/
cp -a .devcontainer/scripts/. src/common/scripts/
cp .devcontainer/entrypoint.sh src/common/entrypoint.sh
cp .devcontainer/first-run-notice.txt src/common/first-run-notice.txt
cp .devcontainer/justfile src/common/justfile
cp .devcontainer/post-create.sh src/common/post-create.sh
```

Expected: shared files exist with unchanged contents.

- [ ] **Step 3: Verify no shared asset was missed**

Run:

```bash
find src/common -maxdepth 3 -type f | sort
```

Expected: Brewfiles, config files, scripts, entrypoint, notice, justfile, and post-create are listed.

### Task 2: Preserve Wolfi Variant

**Files:**
- Create: `src/wolfi/.devcontainer/Dockerfile`
- Create: `src/wolfi/.devcontainer/devcontainer.json`

- [ ] **Step 1: Copy current Wolfi Dockerfile**

Run:

```bash
cp .devcontainer/Dockerfile src/wolfi/.devcontainer/Dockerfile
```

Expected: Wolfi Dockerfile exists.

- [ ] **Step 2: Update shared asset copy paths**

Replace `COPY .devcontainer/` paths with `COPY src/common/` in `src/wolfi/.devcontainer/Dockerfile`.

Expected: Wolfi variant builds from repo root and sources shared assets from `src/common`.

- [ ] **Step 3: Copy current devcontainer metadata**

Run:

```bash
cp .devcontainer/devcontainer.json src/wolfi/.devcontainer/devcontainer.json
```

Expected: Wolfi metadata remains available as an explicit variant.

### Task 3: Add Ubuntu Noble Variant

**Files:**
- Create: `src/ubuntu-noble/.devcontainer/Dockerfile`
- Create: `src/ubuntu-noble/.devcontainer/devcontainer.json`

- [ ] **Step 1: Create Ubuntu Dockerfile**

Use `mcr.microsoft.com/devcontainers/base:ubuntu-24.04`, apt install base packages, install Homebrew noninteractively, install `starship`, `mise`, `zoxide`, and `bbrew`, copy shared assets, create `ujust`, and set `/usr/local/bin/entrypoint.sh`.

- [ ] **Step 2: Create Ubuntu devcontainer metadata**

Use root context, the Ubuntu Dockerfile, `vscode` user, shared cache mounts, and the official Docker-in-Docker feature.

- [ ] **Step 3: Keep post-create behavior shared**

Set `postCreateCommand` to restore shared shell config and run `/usr/local/bin/devcontainer-post-create.sh`.

### Task 4: Add Debian Trixie Variant

**Files:**
- Create: `src/debian-trixie/.devcontainer/Dockerfile`
- Create: `src/debian-trixie/.devcontainer/devcontainer.json`

- [ ] **Step 1: Create Debian Dockerfile**

Use `mcr.microsoft.com/devcontainers/base:trixie` and the same shared bootstrap pattern as Ubuntu.

- [ ] **Step 2: Create Debian devcontainer metadata**

Use root context, the Debian Dockerfile, `vscode` user, shared cache mounts, and Docker best-effort feature wiring.

### Task 5: Point Top-Level Devcontainer At Ubuntu

**Files:**
- Modify: `.devcontainer/devcontainer.json`

- [ ] **Step 1: Change build path**

Set `build.dockerfile` to `../src/ubuntu-noble/.devcontainer/Dockerfile` while keeping context as `..`.

- [ ] **Step 2: Add Docker-in-Docker feature**

Configure `ghcr.io/devcontainers/features/docker-in-docker:2` in `features`.

- [ ] **Step 3: Remove Wolfi-only apk cleanup commands**

Remove `onCreateCommand` and `updateContentCommand` commands that edit `/etc/apk/world`.

### Task 6: Add Bake Targets

**Files:**
- Create: `docker-bake.hcl`

- [ ] **Step 1: Define targets**

Create targets for `ubuntu-noble`, `ubuntu-noble-dind`, `debian-trixie`, and `wolfi`.

- [ ] **Step 2: Define aliases**

Tag `latest` on `ubuntu-noble`, `codespaces` on `ubuntu-noble-dind`, and `secure` on `wolfi`.

- [ ] **Step 3: Validate bake syntax**

Run:

```bash
docker buildx bake --print
```

Expected: JSON build plan prints successfully.

### Task 7: Make Workflow Variant-Aware

**Files:**
- Modify: `.github/workflows/build-image.yml`

- [ ] **Step 1: Add variant input**

Add a `variant` workflow input with default `ubuntu-noble`.

- [ ] **Step 2: Lint selected variant Dockerfile**

Set hadolint path to `src/${{ inputs.variant || 'ubuntu-noble' }}/.devcontainer/Dockerfile`.

- [ ] **Step 3: Build selected variant**

Replace the `devcontainer build --workspace-folder .` path with `--config src/${variant}/.devcontainer/devcontainer.json --workspace-folder .`.

### Task 8: Update Docs

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Update overview**

Describe Room of Requirement as a multi-base factory, with Ubuntu Noble as default and Wolfi as secure/minimal.

- [ ] **Step 2: Update quick-start image tags**

Document `latest`, `codespaces`, `ubuntu-noble`, `debian-trixie`, and `secure`.

- [ ] **Step 3: Document local build commands**

Add `docker buildx bake --print` and per-variant build examples.

### Task 9: Verify

**Files:**
- All changed files

- [ ] **Step 1: Run pre-commit**

Run:

```bash
pre-commit run --all-files
```

Expected: all hooks pass, or failures are fixed.

- [ ] **Step 2: Validate bake**

Run:

```bash
docker buildx bake --print
```

Expected: bake plan includes all required targets and tags.

- [ ] **Step 3: Inspect changed files**

Run:

```bash
git status --short
git diff --stat
```

Expected: only factory migration files changed.
