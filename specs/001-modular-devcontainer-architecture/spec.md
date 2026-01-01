# Feature Specification: Modular DevContainer Architecture

**Feature Branch**: `001-modular-devcontainer-architecture`
**Created**: January 1, 2026
**Status**: Draft
**Input**: User description: "Advancing the Room of Requirement: A Comprehensive Development Strategy for Modular, Secure, and Bleeding-Edge Dev Environments"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Instant Development Environment Setup (Priority: P1)

As a developer joining a project, I want to spin up a fully-configured development environment in seconds without downloading multi-gigabyte images or waiting for lengthy apt-get sequences, so that I can start productive work immediately.

**Why this priority**: This is the core value proposition of the Room of Requirement. Without instant startup, the entire architecture fails its fundamental promise of "batteries-included" convenience. This directly addresses the friction of multi-gigabyte downloads and build-time latency.

**Independent Test**: Can be tested by opening any project with a `devcontainer.json` referencing `ror:latest` and verifying environment is ready within target time threshold.

**Acceptance Scenarios**:

1. **Given** a fresh machine with Docker installed, **When** a developer opens a project with the RoR template, **Then** the environment should be fully usable within 60 seconds on a 100Mbps connection.
2. **Given** a previously pulled `ror:latest` image, **When** a developer creates a new container, **Then** the environment should be interactive within 15 seconds.
3. **Given** a project with a `.mise.toml` file specifying Python 3.12 and Node 20, **When** the container starts, **Then** the `postCreateCommand` should hydrate project-specific tools in under 30 seconds.
4. **Given** a project with a `Brewfile` specifying CLI tools like `kubectl`, `helm`, and `jq`, **When** the container starts, **Then** the `postCreateCommand` should install all Brewfile dependencies automatically within the startup time budget.

---

### User Story 2 - Polyglot Tool Management (Priority: P1)

As a full-stack developer working across multiple languages, I want a unified tool manager that handles Python, Node.js, Go, and other runtimes from a single configuration file, so that I don't need to juggle multiple version managers and their conflicting configurations.

**Why this priority**: Tool version management is the most common pain point in development environments. This story directly replaces the fragmented ecosystem of nvm, pyenv, and asdf with mise-en-place, providing immediate productivity gains.

**Independent Test**: Can be tested by creating a project with a `.mise.toml` file and verifying all specified tool versions are available and active.

**Acceptance Scenarios**:

1. **Given** a `.mise.toml` file specifying `node = "20.10.0"` and `python = "3.12"`, **When** I open a terminal in the container, **Then** `node --version` outputs `v20.10.0` and `python --version` outputs `Python 3.12.x`.
2. **Given** a project directory with environment variables defined in `.mise.toml`, **When** I navigate into that directory, **Then** the environment variables are automatically loaded without requiring manual `source` commands.
3. **Given** multiple projects with different tool versions, **When** I switch between project directories, **Then** the tool versions automatically switch to match each project's requirements.

---

### User Story 3 - Modular Feature Composition (Priority: P2)

As a platform engineer, I want to compose custom development environments by mixing and matching discrete DevContainer Features, so that I can create tailored environments for different teams without maintaining separate monolithic Dockerfiles.

**Why this priority**: Composability enables long-term maintainability and team customization. While the pre-built image serves most users, advanced teams need the ability to customize without forking the entire project.

**Independent Test**: Can be tested by creating a `devcontainer.json` that references individual features (e.g., `mise`, `starship`) and verifying each component installs correctly.

**Acceptance Scenarios**:

1. **Given** a `devcontainer.json` referencing only the `ror-core` Meta-Feature, **When** the container builds, **Then** all dependent features (mise, starship, zoxide) are installed in correct dependency order.
2. **Given** a custom `devcontainer.json` referencing `mise` and `starship` features individually, **When** the container builds, **Then** both tools are available and configured without conflicts.
3. **Given** an update to the `mise` feature version, **When** the `ror-core` Meta-Feature is rebuilt, **Then** the change propagates automatically to the `ror:latest` image.
4. **Given** a `devcontainer.json` referencing `ror-cli-tools` Feature, **When** the container builds, **Then** Homebrew installs the default bundle (kubectl, helm, k9s, jq, yq, gh) unless overridden by a project-level Brewfile.

---

### User Story 4 - Secure Supply Chain Verification (Priority: P2)

As a security-conscious organization, I want every container image and feature to be cryptographically signed with verifiable provenance and comprehensive SBOMs, so that I can trust what code is running in my development environments and meet compliance requirements.

**Why this priority**: Supply chain security is non-negotiable for enterprise adoption. While not blocking initial usage, this enables regulated industries to adopt the Room of Requirement.

**Independent Test**: Can be tested by running `cosign verify` against any published image and validating the SBOM attestation.

**Acceptance Scenarios**:

1. **Given** the published `ror:latest` image on GHCR, **When** I run signature verification with cosign, **Then** the signature validates successfully against the repository's identity.
2. **Given** a security scanner querying the image, **When** requesting the SBOM, **Then** a complete software bill of materials in SPDX or CycloneDX format is returned with all packages and their versions.
3. **Given** a build pipeline with vulnerability scanning, **When** a Critical CVE with available fix is detected, **Then** the build fails and the image is not published until remediated.

---

### User Story 5 - Modern Terminal Experience (Priority: P3)

As a developer who spends significant time in the terminal, I want a modern shell experience with intelligent prompts, smart directory navigation, and persistent command history, so that my productivity is enhanced by context-aware tooling.

**Why this priority**: While not essential for basic functionality, modern CLI tools significantly improve daily productivity and represent a key differentiator for the "bleeding edge" promise.

**Independent Test**: Can be tested by opening a terminal and verifying Starship prompt and zoxide navigation are functional.

**Acceptance Scenarios**:

1. **Given** a terminal session in the container, **When** the prompt loads, **Then** Starship displays the current directory, git status (if applicable), and active tool versions in under 100ms.
2. **Given** frequently visited directories, **When** I use `z <partial-name>`, **Then** zoxide jumps to the most relevant matching directory.
3. **Given** a previous terminal session where I ran complex commands, **When** I start a new container and search history with Ctrl+R, **Then** my previous commands are available and searchable through ZSH's built-in history search.

---

### User Story 6 - Stable Version Pinning (Priority: P3)

As a team lead managing a long-running project, I want to pin our development environment to a specific semantic version, so that our team has a consistent, reproducible environment that doesn't change unexpectedly.

**Why this priority**: Version stability is critical for teams that prioritize reproducibility over bleeding-edge features. This enables enterprise adoption patterns.

**Independent Test**: Can be tested by referencing a specific version tag (e.g., `ror:v2.1.0`) and verifying it remains unchanged over time.

**Acceptance Scenarios**:

1. **Given** a `devcontainer.json` referencing `ror:v2.1.0`, **When** I rebuild my container weeks later, **Then** I receive the exact same environment with identical tool versions.
2. **Given** the `ror:stable` tag, **When** checking its contents, **Then** it points to the last monthly release rather than daily builds.
3. **Given** a published feature version `mise:1.2.0`, **When** that version is referenced directly, **Then** the exact version is installed regardless of newer releases.

---

### Edge Cases

- What happens when a user's project `.mise.toml` requests a tool version not pre-cached in `ror:latest`? (Expected: mise downloads and installs on first use)
- How does the system handle conflicting Feature versions when a user specifies both `ror-core` and a standalone `mise` feature with different options? (Expected: explicit user-specified options override Meta-Feature defaults)
- How does the system behave when run on arm64 vs amd64 architectures? (Expected: multi-arch images are published for both platforms)
- What happens if a user attempts to use Nushell as their default shell for VS Code backend tasks? (Expected: POSIX-compatible shell remains for backend; Nushell available as terminal profile option)

## Requirements *(mandatory)*

### Functional Requirements

#### Base Image & OS Foundation
- **FR-001**: System MUST use Wolfi OS as the base image foundation to provide glibc compatibility and minimal attack surface.
- **FR-002**: System MUST include `posix-libc-utils`, `libstdc++`, `bash`, `git`, `curl`, `openssh`, and `ca-certificates` packages for VS Code Server compatibility.
- **FR-003**: System MUST configure a non-root user (`vscode`) with appropriate permissions for bind mount compatibility.
- **FR-004**: System MUST set UTF-8 locale to ensure proper terminal rendering and internationalization.

#### Tool Management (mise-en-place)
- **FR-005**: System MUST install mise-en-place as the universal polyglot tool manager.
- **FR-006**: System MUST configure mise shims in the global PATH (`/usr/local/share/mise/shims`) for non-interactive script access.
- **FR-007**: System MUST pre-install a default toolset (Node.js LTS, Python latest stable, Go latest stable) via mise in the base image for language runtimes requiring version management.
- **FR-008**: System MUST support project-specific tool versions via `.mise.toml` or `.mise/config.toml` files.
- **FR-009**: System MUST support automatic environment variable loading from mise configuration when entering directories.

#### CLI Tooling
- **FR-010**: System MUST install and configure Starship as the default cross-shell prompt.
- **FR-011**: System MUST provide a curated Starship configuration optimized for container usage (suppressed Docker module, optimized git status).
- **FR-012**: System MUST install zoxide for intelligent directory navigation with `z` alias.
- **FR-013**: System MUST install Nushell as an available alternative shell (not default).

#### Modular Architecture
- **FR-014**: Repository MUST be structured as a monorepo containing Features, Templates, and Image definitions.

#### Package Management Integration
- **FR-028**: System MUST install Homebrew in the base image and configure appropriate user permissions for the `linuxbrew` user, with `/home/linuxbrew/.linuxbrew/bin` prioritized in the system `$PATH`.
- **FR-029**: System MUST support project-level `Brewfile` hydration via `postCreateCommand`, automatically running `brew bundle install` when a `Brewfile` is present in the project root.
- **FR-030**: The `ror-cli-tools` Feature MUST include a default Brewfile containing: `kubectl`, `helm`, `k9s`, `jq`, `yq`, and `gh`. Users MAY override this by providing their own Brewfile in their project root.
- **FR-015**: System MUST implement the Meta-Feature pattern where `ror-core` uses `dependsOn` to orchestrate atomic features.
- **FR-016**: Features MUST be published as OCI artifacts to GitHub Container Registry.
- **FR-017**: System MUST provide a starter Template (`ror-starter`) for new projects.

#### Supply Chain Security
- **FR-018**: System MUST generate SBOMs (Software Bill of Materials) for every published image.
- **FR-019**: System MUST sign all artifacts (Features, Templates, Images) using Sigstore/Cosign keyless signing.
- **FR-020**: System MUST attach SBOM attestations to images in the OCI registry.
- **FR-021**: Build pipeline MUST fail if Critical CVEs with available fixes are detected.

#### Distribution & Versioning
- **FR-022**: ~~System MUST publish multi-architecture images (amd64, arm64).~~ **DEFERRED** - amd64 only for initial release per Clarification Session 2026-01-01; arm64 support planned for future iteration.
- **FR-023**: System MUST implement the defined tagging strategy: `latest`, `stable`, and semantic versions.
- **FR-024**: System MUST automate version bumping and changelog generation using conventional commits.

#### Maintenance Automation
- **FR-031**: The maintenance robot MUST be updated to track new direct-download tools (mise, starship, zoxide) in `downloads.json` with SHA256 checksum verification.
- **FR-032**: The maintenance robot MUST support Homebrew formula version tracking via a new `homebrew.json` allowlist querying the Homebrew API.
- **FR-033**: The maintenance robot MUST update target paths for specialty tools to reference `features/ror-specialty/install.sh` instead of the Dockerfile.
- **FR-034**: The `github_actions.json` allowlist MUST include new supply chain security actions (cosign-installer, sbom-action, scan-action, devcontainers/ci).
- **FR-035**: The maintenance robot MUST remove obsolete tool entries (kind, k3d, k9s, awscli, nodejs, etc.) that have migrated to Homebrew or mise management.

#### Shell & Package Strategy (Added via Clarification)
- **FR-025**: System MUST provide a default `.zshrc` that initializes Starship but is designed to be overridden by user dotfiles injected via Codespaces/DevPod.
- **FR-026**: System MUST use Wolfi `apk` packages where available; direct binary downloads with SHA256 verification for tools not in Wolfi repos.
- **FR-027**: Specialty tools (Sema4.AI, dagger, claude-code, container-use, hauler, devspace) MUST be packaged as optional DevContainer Features, not baked into the base image.

### Key Entities

- **Feature**: A discrete, versioned DevContainer component (e.g., mise, starship) packaged as an OCI artifact with its own `devcontainer-feature.json` manifest.
- **Meta-Feature**: A Feature that aggregates other Features via `dependsOn`, providing a single installation point for a complete toolchain.
- **Template**: A boilerplate `devcontainer.json` configuration that references Features or Images, distributed to help users bootstrap new projects.
- **Pre-built Image**: The `ror:latest` OCI container image that embeds all Features for instant startup, eliminating build-time latency.
- **SBOM**: Software Bill of Materials documenting all packages, libraries, and dependencies in an artifact for security auditing.
- **Attestation**: Cryptographic proof attached to an OCI artifact verifying its provenance and contents.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Developers can start a fully-functional development environment in under 60 seconds on first pull (100Mbps connection) and under 15 seconds on subsequent starts.
- **SC-002**: The `ror:latest` image size is under 500MB compressed (at least 50% smaller than `mcr.microsoft.com/devcontainers/universal:2` baseline, typically ~1.5GB compressed).
- **SC-003**: Zero Critical or High CVEs remain unfixed in `ror:latest` for more than 24 hours after a fix is available in Wolfi packages.
- **SC-004**: 100% of published artifacts (Features, Templates, Images) pass cosign signature verification.
- **SC-005**: All published images include complete SBOM attestations with 100% package coverage.
- **SC-006**: Tool version switches via mise complete in under 500ms for cached tools.
- **SC-007**: Starship prompt renders in under 100ms in typical project directories.
- **SC-008**: Feature updates propagate to the `ror:latest` image within one CI pipeline run (typically under 30 minutes).
- **SC-009**: Users can compose custom environments using individual Features without dependency conflicts.

## Assumptions

- **A-001**: Target users have Docker or a compatible container runtime installed on their host machine.
- **A-002**: GitHub Container Registry (GHCR) will be the primary distribution channel for all artifacts.
- **A-003**: VS Code with the Remote-Containers extension is the primary IDE target, though the environment should work with any Dev Container-compatible tool.
- **A-004**: Network connectivity is available during initial image pull and optional tool installation.
- **A-005**: Users accept reasonable defaults unless they explicitly customize via their own configurations.
- **A-006**: The existing `automation/maintenance-robot` infrastructure will be extended (not replaced) to support the new architecture - see FR-031 through FR-035 for specific requirements.

## Dependencies

- **D-001**: Wolfi OS package ecosystem must include all required packages or acceptable alternatives.
- **D-002**: mise-en-place must support all target language runtimes (Node.js, Python, Go, etc.).
- **D-003**: GitHub Actions OIDC must be available for keyless signing with Sigstore.
- **D-004**: GHCR must support OCI artifact types for Feature and Template distribution.
- **D-005**: DevContainer specification must continue to support the `dependsOn` property for Meta-Features.

## Out of Scope

- **OS-001**: Support for non-Linux development containers (Windows containers, macOS native).
- **OS-002**: Graphical/GUI application support within the container.
- **OS-003**: Alternative base images (Alpine, Debian) - Wolfi is the sole supported foundation.
- **OS-004**: Kubernetes-native development tooling beyond what is already in the current RoR (k3d, kubectl, k9s remain as-is).

## Clarifications

### Session 2026-01-01

- Q: What is the migration strategy for existing users of the current Ubuntu-based `ror:latest` image? → A: Hard cutover - replace `ror:latest` immediately with the new Wolfi-based image (no parallel publishing or deprecation period)

### Session 2026-01-01 (Shell & Architecture)

- Q: How should Starship and Oh My Zsh coexist? → A: **Starship replaces Oh My Zsh entirely** for prompt rendering. Oh My Zsh framework will NOT be installed. Standalone Zsh plugins (autosuggestions, syntax-highlighting) may be evaluated later, but Starship is the primary shell experience. This is a clean break from the Microsoft Universal base image approach.

- Q: How should the new Wolfi image handle shell configuration given that dotfiles are injected via Codespaces/DevPod? → A: **Sensible defaults + injection-friendly**. Ship a lightweight default `.zshrc` that initializes Starship, but design it to be overridden/extended by user's injected dotfiles. Works out-of-box for users without dotfiles; power users get their configs via platform injection.

- Q: What happens to the existing cloud/K8s tooling (kind, k3d, k9s, aws-cli, dagger, claude-code, etc.)? → A: **Tiered approach**:
  - **Core CLI tools (K8s, cloud CLI)**: Delivered via `ror-cli-tools` Homebrew Feature (kubectl, helm, k3d, k9s, aws-cli, jq, yq, gh) - installed on demand via Brewfile
  - **Language runtimes**: Managed by mise (Node.js, Python, Go) - not baked in
  - **Specialty tools**: Optional DevContainer Features (Sema4.AI action-server/rcc, dagger, claude-code, container-use, hauler, devspace)

- Q: How should the build handle tools not available as Wolfi packages? → A: **Wolfi packages first, fallback to direct binaries**. Use `apk` for tools available in Wolfi repos (automatic CVE patching). For specialty tools not in Wolfi, continue the existing pattern of direct binary downloads with SHA256 checksum verification.

- Q: How should the new Wolfi image handle arm64 architecture? → A: **amd64 only initially**. Ship amd64 architecture first; add arm64 support later when tool ecosystem matures. This is a pragmatic choice given many specialty tools (claude-code, etc.) lack arm64 binaries. FR-023 (multi-arch) is deferred to a future iteration.

### Updated Requirements Based on Clarifications

*The following requirements have been integrated into the main Functional Requirements section:*
- FR-010 (amended): Starship replaces Oh My Zsh - see FR-010 above
- FR-023 (deferred): Multi-architecture support - see FR-023 above
- FR-026, FR-027, FR-028: Added to main requirements section
