# Tasks: Modular DevContainer Architecture

**Input**: Design documents from `/specs/001-modular-devcontainer-architecture/`
**Prerequisites**: plan.md ✅, spec.md ✅, research.md ✅, data-model.md ✅, contracts/ ✅

**Tests**: Not explicitly requested - test tasks omitted per template guidelines.

**Organization**: Tasks grouped by user story for independent implementation and testing.

## Format: `[ID] [P?] [Story?] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2)
- Include exact file paths in descriptions

---

## Phase 1: Setup (Project Initialization)

**Purpose**: Repository restructuring and tooling setup

- [X] T001 Create feature directory structure per plan at features/
- [X] T002 [P] Create templates directory structure at templates/ror-starter/
- [X] T003 [P] Install @devcontainers/cli globally for feature building
- [X] T004 [P] Configure hadolint for Dockerfile linting in .github/workflows/
- [X] T005 [P] Create .editorconfig for consistent formatting across Bash/Dockerfile

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

### Base Image Foundation

- [x] T006 Create multi-stage Dockerfile base stage with Wolfi OS at .devcontainer/Dockerfile
- [x] T007 Configure vscode user with UID/GID mapping in .devcontainer/Dockerfile
- [x] T008 Set UTF-8 locale and timezone configuration in .devcontainer/Dockerfile
- [x] T009 [P] Install Wolfi system packages (posix-libc-utils, libstdc++, bash, git, curl, openssh, ca-certificates) in .devcontainer/Dockerfile

### Homebrew Foundation

- [x] T010 Install Homebrew/Linuxbrew in .devcontainer/Dockerfile with linuxbrew user setup
- [x] T011 Configure Homebrew PATH (/home/linuxbrew/.linuxbrew/bin) in .devcontainer/Dockerfile
- [x] T012 [P] Set Homebrew environment variables (HOMEBREW_PREFIX, HOMEBREW_CELLAR) in .devcontainer/Dockerfile
- [x] T013 Configure vscode user permissions for Homebrew directories in .devcontainer/Dockerfile

### Shell Configuration

- [x] T014 Install ZSH via Wolfi apk in .devcontainer/Dockerfile
- [x] T015 Create default .zshrc with Starship/mise/zoxide initialization at .devcontainer/config/.zshrc
- [x] T016 [P] Configure shell history persistence in .devcontainer/devcontainer.json

### DevContainer Configuration

- [x] T017 Create base devcontainer.json with Wolfi image reference at .devcontainer/devcontainer.json
- [x] T018 [P] Configure docker-in-docker feature (v2.13.0) in .devcontainer/devcontainer.json
- [x] T019 [P] Configure volume mounts for caching (Homebrew, mise, npm) in .devcontainer/devcontainer.json
- [x] T020 Create devcontainer-lock.json for version pinning at .devcontainer/devcontainer-lock.json

**Checkpoint**: Foundation ready - user story implementation can now begin

---

## Phase 3: User Story 1 - Instant Development Environment Setup (Priority: P1) 🎯 MVP

**Goal**: Developers can spin up fully-configured environment in <60s first pull, <15s subsequent

**Independent Test**: Open project with devcontainer.json referencing ror:latest, verify environment ready within time threshold

### Pre-built Image Implementation

- [x] T021 [US1] Add mise-en-place installation stage in .devcontainer/Dockerfile
- [x] T022 [US1] Configure mise shims at /usr/local/share/mise/shims in .devcontainer/Dockerfile
- [X] T023 [US1] Pre-install default toolset (node@lts, python@latest, go@latest) via mise in .devcontainer/Dockerfile
- [X] T024 [P] [US1] Add Starship installation via direct binary download in .devcontainer/Dockerfile
- [X] T025 [P] [US1] Add zoxide installation via direct binary download in .devcontainer/Dockerfile

### Project Hydration Script

- [x] T026 [US1] Create post-create.sh with Brewfile detection and brew bundle install at .devcontainer/post-create.sh
- [x] T027 [US1] Add .mise.toml detection and mise install to post-create.sh
- [x] T028 [US1] Add package.json detection and npm/pnpm install to post-create.sh
- [x] T029 [US1] Add mise setup task detection and execution to post-create.sh
- [x] T030 [US1] Configure postCreateCommand in devcontainer.json to run post-create.sh

### PATH Configuration

- [x] T031 [US1] Configure PATH precedence (mise shims > Homebrew > /usr/local/bin > /usr/bin) in .devcontainer/Dockerfile
- [x] T032 [US1] Verify PATH configuration in default .zshrc at .devcontainer/config/.zshrc

### Image Size Optimization

- [X] T033 [US1] Implement multi-stage build to minimize final image size in .devcontainer/Dockerfile
- [x] T034 [US1] Add .dockerignore to exclude unnecessary files from build context at .devcontainer/.dockerignore

**Checkpoint**: User Story 1 complete - developers can pull ror:latest and start in <60s

---

## Phase 4: User Story 2 - Polyglot Tool Management (Priority: P1)

**Goal**: Unified tool manager handling Python, Node.js, Go from single .mise.toml

**Independent Test**: Create project with .mise.toml, verify specified versions are active

### mise Configuration

- [x] T035 [US2] Configure mise trust settings for /workspace in .devcontainer/Dockerfile
- [x] T036 [US2] Add mise activate to default .zshrc for interactive sessions at .devcontainer/config/.zshrc
- [x] T037 [US2] Configure mise environment variable loading (experimental direnv) in .devcontainer/config/mise.toml

### mise Feature (Atomic)

- [X] T038 [P] [US2] Create devcontainer-feature.json for mise Feature at features/mise/devcontainer-feature.json
- [X] T039 [US2] Create install.sh for mise Feature at features/mise/install.sh
- [X] T040 [P] [US2] Create README.md for mise Feature at features/mise/README.md

### Default Toolset Configuration

- [X] T041 [US2] Create default mise global config with node@lts, python@latest, go@latest at .devcontainer/config/mise.toml
- [X] T042 [US2] Document tool version override patterns in quickstart.md

**Checkpoint**: User Story 2 complete - .mise.toml drives tool versions automatically

---

## Phase 5: User Story 3 - Modular Feature Composition (Priority: P2)

**Goal**: Platform engineers can compose custom environments with discrete Features

**Independent Test**: Create devcontainer.json referencing individual features, verify each installs correctly

### Atomic Features

- [x] T043 [P] [US3] Create devcontainer-feature.json for Starship Feature at features/starship/devcontainer-feature.json
- [x] T044 [P] [US3] Create install.sh for Starship Feature at features/starship/install.sh
- [x] T045 [P] [US3] Create starship.toml configuration at features/starship/config/starship.toml

- [x] T046 [P] [US3] Create devcontainer-feature.json for zoxide Feature at features/zoxide/devcontainer-feature.json
- [x] T047 [P] [US3] Create install.sh for zoxide Feature at features/zoxide/install.sh

- [x] T048 [P] [US3] Create devcontainer-feature.json for Nushell Feature at features/nushell/devcontainer-feature.json
- [x] T049 [P] [US3] Create install.sh for Nushell Feature at features/nushell/install.sh

### Meta-Feature (ror-core)

- [x] T050 [US3] Create devcontainer-feature.json for ror-core Meta-Feature with dependsOn at features/ror-core/devcontainer-feature.json
- [x] T051 [US3] Create install.sh for ror-core Meta-Feature at features/ror-core/install.sh
- [x] T052 [P] [US3] Create README.md for ror-core Meta-Feature at features/ror-core/README.md

### CLI Tools Feature (Homebrew-based)

- [x] T053 [P] [US3] Create devcontainer-feature.json for ror-cli-tools Feature at features/ror-cli-tools/devcontainer-feature.json
- [x] T054 [US3] Create install.sh with Homebrew bundle install at features/ror-cli-tools/install.sh
- [x] T055 [P] [US3] Create default Brewfile with kubectl, helm, k9s, jq, yq, gh at features/ror-cli-tools/Brewfile

### Specialty Tools Feature

- [x] T056 [P] [US3] Create devcontainer-feature.json for ror-specialty Feature at features/ror-specialty/devcontainer-feature.json
- [x] T057 [US3] Create install.sh with direct binary downloads (Sema4.AI, dagger, etc.) at features/ror-specialty/install.sh
- [x] T058 [P] [US3] Add SHA256 checksum verification to specialty tools install script

### Starter Template

- [x] T059 [P] [US3] Create devcontainer.json for ror-starter Template at templates/ror-starter/.devcontainer/devcontainer.json
- [x] T060 [P] [US3] Create example Brewfile for ror-starter Template at templates/ror-starter/.devcontainer/Brewfile
- [x] T061 [P] [US3] Create example .mise.toml for ror-starter Template at templates/ror-starter/.mise.toml
- [x] T062 [P] [US3] Create post-create.sh for ror-starter Template at templates/ror-starter/.devcontainer/post-create.sh
- [x] T063 [US3] Create devcontainer-template.json for ror-starter at templates/ror-starter/devcontainer-template.json

**Checkpoint**: User Story 3 complete - Features can be composed independently

---

## Phase 6: User Story 4 - Secure Supply Chain Verification (Priority: P2)

**Goal**: All artifacts cryptographically signed with verifiable provenance and SBOMs

**Independent Test**: Run cosign verify against published image, validate SBOM attestation

### Image Build Workflow

- [x] T064 [US4] Create build-image.yml workflow at .github/workflows/build-image.yml
- [x] T065 [US4] Add Cosign signing step with keyless signing to build-image.yml
- [x] T066 [US4] Add Syft SBOM generation (SPDX format) to build-image.yml
- [x] T067 [US4] Add SBOM attestation attachment via cosign attest to build-image.yml
- [x] T068 [US4] Add Grype CVE scanning with fail-on-critical to build-image.yml
- [x] T069 [P] [US4] Add SLSA provenance generation to build-image.yml

### Feature Build Workflow

- [x] T070 [US4] Create build-features.yml workflow at .github/workflows/build-features.yml
- [x] T070a [US4] Configure GHCR authentication with GITHUB_TOKEN permissions (packages: write) in build-features.yml
- [x] T071 [US4] Add devcontainers/action for Feature publishing to build-features.yml
- [x] T072 [P] [US4] Add Cosign signing for Features to build-features.yml

### Tagging Strategy

- [x] T073 [US4] Implement tagging strategy (latest, stable, semver, sha) in build-image.yml
- [x] T074 [P] [US4] Add release-please for automated versioning at .github/workflows/release.yml
- [x] T074a [P] [US4] Configure release-please changelog generation (CHANGELOG.md, release notes) in .github/workflows/release.yml

**Checkpoint**: User Story 4 complete - all artifacts signed with SBOM attestations

---

## Phase 7: User Story 5 - Modern Terminal Experience (Priority: P3)

**Goal**: Modern shell with Starship prompt, zoxide navigation, ZSH history

**Independent Test**: Open terminal, verify Starship renders <100ms, zoxide navigation works

### Starship Configuration

- [x] T075 [US5] Create optimized starship.toml for containers at .devcontainer/config/starship.toml
- [x] T076 [US5] Disable container and docker_context modules in starship.toml
- [x] T077 [P] [US5] Configure git_status and cmd_duration modules in starship.toml

### ZSH Configuration

- [x] T078 [US5] Configure ZSH history settings (HISTSIZE, SAVEHIST) in default .zshrc
- [x] T079 [P] [US5] Add zoxide init to default .zshrc with z alias
- [x] T080 [P] [US5] Add Ctrl+R history search configuration to default .zshrc

### Nushell Integration

- [x] T081 [US5] Create default config.nu for Nushell at .devcontainer/config/nushell/config.nu
- [x] T082 [P] [US5] Configure Nushell as VS Code terminal profile option in devcontainer.json

**Checkpoint**: User Story 5 complete - modern terminal experience functional

---

## Phase 8: User Story 6 - Stable Version Pinning (Priority: P3)

**Goal**: Teams can pin to specific semantic versions for reproducibility

**Independent Test**: Reference ror:v2.1.0, rebuild weeks later, venvironment

### Version Management

- [x] T083 [US6] Configure semantic versioning in release-please workflow
- [x] T084 [US6] Implement stable tag update in release workflow (monthly)
- [x] T085 [P] [US6] Document version pinning patterns in quickstart.md

### Feature Versioning

- [x] T086 [US6] Implement Feature version pinning in devcontainer-feature.json files
- [x] T087 [P] [US6] Document Feature version override patterns in README files

**Checkpoint**: User Story 6 complete - version pinning enables reproducible environments

---

## Phase 9: Maintenance Automation

**Purpose**: Extend existing RCC maintenance robot for new Wolfi + Homebrew + mise architecture

**⚠️ CRITICAL**: The existing downloads.json tracks Ubuntu-era tools that are now obsolete or relocated. Must clean up before adding new sources.

### 9A: Cleanup Obsolete Entries from downloads.json

- [x] T088 Remove obsolete direct-download tools from downloads.json (kind, k3d, k9s, awscli, uv, duckdb, rcc, nodejs) - these moved to Homebrew or mise
- [x] T089 [P] Remove obsolete DevContainer feature entries from downloads.json (common-utils-feature, kubectl-helm-minikube-feature, github-cli-feature) - replaced by Homebrew

### 9B: Add New Direct Download Tools to downloads.json

- [x] T090 Add mise entry to downloads.json (repo: jdx/mise, target: .devcontainer/Dockerfile ARG MISE_VERSION/MISE_SHA256)
- [x] T091 [P] Add starship entry to downloads.json (repo: starship/starship, target: .devcontainer/Dockerfile ARG STARSHIP_VERSION/STARSHIP_SHA256)
- [x] T092 [P] Add zoxide entry to downloads.json (repo: ajeetdsouza/zoxide, target: .devcontainer/Dockerfile ARG ZOXIDE_VERSION/ZOXIDE_SHA256)

### 9C: Update Specialty Tools Targets in downloads.json

- [x] T093 Update action-server target path in downloads.json from .devcontainer/Dockerfile to features/ror-specialty/install.sh
- [x] T094 [P] Update dagger target path in downloads.json to features/ror-specialty/install.sh
- [ ] T095 [P] Update claude-code target path in downloads.json to features/ror-specialty/install.sh (TODO: claude-code not yet in install.sh)
- [x] T096 [P] Update container-use target path in downloads.json to features/ror-specialty/install.sh
- [ ] T097 [P] Update devspace target path in downloads.json to features/ror-specialty/install.sh (TODO: devspace not yet in install.sh)
- [ ] T098 [P] Update hauler target path in downloads.json to features/ror-specialty/install.sh (TODO: hauler not yet in install.sh)

### 9D: Homebrew Version Tracking (New Source Type)

- [x] T099 Create homebrew.json allowlist at automation/maintenance-robot/allowlists/homebrew.json with formulas: kubectl, helm, k9s, jq, yq, gh, awscli
- [x] T100 Create homebrew.py module at automation/maintenance-robot/src/maintenance_robot/homebrew.py to query Homebrew API (formulae.brew.sh/api/formula/{name}.json)
- [x] T101 Update tasks.py to load homebrew.json allowlist and call HomebrewUpdater
- [x] T102 [P] Add update-homebrew task to robot.yaml at automation/maintenance-robot/robot.yaml

### 9E: GitHub Actions Allowlist Updates

- [x] T103 Add sigstore/cosign-installer action to github_actions.json for image signing
- [x] T104 [P] Add anchore/sbom-action (Syft) to github_actions.json for SBOM generation
- [x] T105 [P] Add anchore/scan-action (Grype) to github_actions.json for CVE scanning
- [x] T106 [P] Add devcontainers/ci action to github_actions.json for Feature publishing

### 9F: Workflow & Integration Updates

- [x] T107 Update rcc-maintenance.yml workflow to handle new artifact types at .github/workflows/rcc-maintenance.yml
- [x] T108 [P] Update maintenance report schema to include Homebrew updates in reporter.py
- [ ] T109 Validate maintenance robot runs successfully with new configuration (rcc run -r automation/maintenance-robot/robot.yaml -t maintenance)

---

## Phase 10: Polish & Cross-Cutting Concerns

**Purpose**: Improvements affecting multiple user stories

- [ ] T093 [P] Update README.md with new architecture documentation at README.md
- [ ] T094 [P] Update AGENTS.md with new development patterns at AGENTS.md
- [ ] T095 [P] Update CLAUDE.md with new tool references at CLAUDE.md
- [ ] T096 Run hadolint validation on .devcontainer/Dockerfile
- [ ] T097 Run devcontainer build to validate full image
- [ ] T098 Validate quickstart.md scenarios end-to-end
- [ ] T098a Verify SBOM attestation retrieval via cosign verify-attestation
- [ ] T099 Measure and document image size (target: <500MB compressed)
- [ ] T100 Measure and document startup times (target: <60s first pull, <15s cached)
- [x] T101 Validate Nushell is available but ZSH remains default shell (verify $SHELL and chsh -l output)

---

## Dependencies & Execution Order

### Phase Dependencies

```
Phase 1 (Setup)
     ↓
Phase 2 (Foundational) ← BLOCKS ALL USER STORIES
     ↓
┌────┴────┬────────┬────────┬────────┬────────┐
↓         ↓        ↓        ↓        ↓        ↓
US1(P1)  US2(P1)  US3(P2)  US4(P2)  US5(P3)  US6(P3)
                    ↓
Phase 9 (Maintenance) - Requires US3 for Feature install.sh targets
     ↓
Phase 10 (Polish) - After all desired stories complete
```

### User Story Dependencies

| Story | Depends On | Can Parallel With |
|-------|------------|-------------------|
| US1 (Instant Setup) | Phase 2 | US2 |
| US2 (Polyglot Tools) | Phase 2 | US1 |
| US3 (Modular Features) | Phase 2, US1 (for base image) | US4, US5, US6 |
| US4 (Supply Chain) | US1 (image to sign) | US3, US5, US6 |
| US5 (Terminal) | Phase 2 | US3, US4, US6 |
| US6 (Version Pinning) | US4 (release workflow) | US5 |

### Within Each User Story

- Config files before scripts that use them
- Dockerfile stages in order (base → tools → config)
- Features before Meta-Feature
- Workflows after artifacts they build

### Parallel Opportunities

**Phase 1 (all [P])**: T001, T002, T003, T004, T005
**Phase 2**: T009, T012, T016, T018, T019 (different concerns)
**US1**: T024, T025 (different tools)
**US3**: T043-T049 (different features), T055, T059-T062 (templates)
**US4**: T069, T072, T074 (different workflows)
**US5**: T077, T079, T080, T082 (different configs)
**Phase 9**: T088-T089 (cleanup), T091-T092 (new tools), T094-T098 (target updates), T102-T106 (GitHub Actions), T108 (reporter)

---

## Implementation Strategy

### MVP First (User Stories 1 + 2)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL)
3. Complete Phase 3: US1 (Instant Setup)
4. Complete Phase 4: US2 (Polyglot Tools)
5. **STOP and VALIDATE**: Test pre-built image independently
6. Deploy ror:latest for early feedback

### Incremental Delivery

| Milestone | Includes | Value Delivered |
|-----------|----------|-----------------|
| MVP | US1 + US2 | Working Wolfi+Homebrew+mise image |
| Beta | + US3 | Modular Features available |
| RC | + US4 | Signed artifacts, SBOMs |
| GA | + US5 + US6 | Full terminal experience, versioning |

### Task Count Summary

| Phase | Tasks | Parallelizable |
|-------|-------|----------------|
| Setup | 5 | 4 |
| Foundational | 15 | 6 |
| US1 (P1) | 14 | 3 |
| US2 (P1) | 8 | 3 |
| US3 (P2) | 21 | 15 |
| US4 (P2) | 13 | 4 |
| US5 (P3) | 8 | 5 |
| US6 (P3) | 5 | 2 |
| Maintenance | 22 | 14 |
| Polish | 10 | 3 |
| **TOTAL** | **121** | **59** |

---

## Notes

- [P] tasks = different files, no dependencies on other in-progress tasks
- [US#] label maps task to specific user story for traceability
- Homebrew is first-class: PATH configured, Brewfile hydration automated
- Each user story independently completable and testable
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
