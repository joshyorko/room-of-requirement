<!--
  ===========================================
  SYNC IMPACT REPORT
  ===========================================
  Version change: 1.0.0 → 1.1.0 (MINOR - expanded guidance)

  Modified principles:
    - III. Security by Default → Added justified exception clause for Docker-in-Docker

  Added sections:
    - Principle III: "Justified Exceptions" subsection with DinD allowance
    - Security & Least Privilege: Updated Docker Integration bullet

  Removed sections: None

  Templates requiring updates:
    ✅ plan-template.md - No changes needed (Constitution Check section is generic)
    ✅ spec-template.md - No changes needed (requirements structure unchanged)
    ✅ tasks-template.md - No changes needed (phase structure unchanged)

  Follow-up TODOs: None
  ===========================================
-->

# Room of Requirement Constitution

## Core Principles

### I. Automation-First Maintenance

All DevContainer assets (Dockerfile versions, GitHub Actions, tool installations) MUST be maintained through automated RCC-powered maintenance tasks, NOT manual edits.

**Rationale**: Automated maintenance ensures version pins, checksums, and allowlists remain synchronized. Manual edits introduce drift and security risks. The maintenance robot is the source of truth for dependency updates.

**Non-negotiables**:
- Regenerate artifacts only via `rcc run -r automation/maintenance-robot/robot.yaml` tasks
- Never hand-edit `devcontainer-lock.json`
- All version bumps MUST include paired SHA256 checksums
- Allowlists (`downloads.json`, `github_actions.json`) govern permitted updates

### II. Reproducible Builds

DevContainer builds MUST be deterministic and reproducible across environments (local VS Code, DevPod, Kubernetes sidecars).

**Rationale**: Cloud-native development requires consistent environments. Pinned versions and checksums guarantee identical container images regardless of build time or location.

**Non-negotiables**:
- All tool installations MUST use pinned versions with SHA256 verification
- Multi-stage Dockerfile structure MUST be preserved (base → deps → tools → final)
- ARG pins in Dockerfile are authoritative; checksums MUST match
- Docker-in-Docker via official DevContainer feature (no custom daemon setup)

### III. Security by Default

The container MUST follow the principle of least privilege. No privileged mode or elevated permissions unless explicitly justified per the exceptions below.

**Rationale**: DevContainers run untrusted code. Minimizing attack surface protects both the developer and any connected cloud resources.

**Non-negotiables**:
- Docker-in-Docker via official feature (secure container nesting)
- Tokens (GITHUB_TOKEN, etc.) stored in environment only, never in files
- Generated outputs in `automation/maintenance-robot/output/` remain untracked

**Justified Exceptions**:

The following elevated permissions are permitted ONLY when all stated mitigations are in place:

| Exception | Justification | Required Mitigations |
|-----------|---------------|----------------------|
| Docker-in-Docker privileged mode | The official `docker-in-docker` DevContainer Feature requires privileged mode to run a nested Docker daemon. Rootless alternatives lack reliable support across VS Code, DevPod, and Kubernetes sidecar patterns. | 1. Use ONLY the official `ghcr.io/devcontainers/features/docker-in-docker` Feature (no custom implementations). 2. Pin Feature version with SHA256 verification. 3. Maintain non-root `vscode` user for all application workloads. 4. Sign all published images with Cosign keyless signing. 5. Attach SBOM attestations to all images. 6. Enforce CVE scanning with fail-on-critical in CI. 7. Document path to rootless DinD adoption when ecosystem matures. |

**Transition Plan**: When rootless Docker-in-Docker achieves stable support across VS Code Remote Containers, DevPod, and Kubernetes sidecars, this exception MUST be re-evaluated and removed if the non-privileged alternative meets functional requirements.

### IV. Conventional Commits & Clear History

All commits MUST follow conventional commit format with concise, imperative subjects.

**Rationale**: Semantic versioning, automated changelogs, and clear audit trails depend on structured commit messages. History should explain what and why.

**Non-negotiables**:
- Format: `type: imperative subject` (e.g., `chore:`, `docs:`, `fix:`)
- Keep commits small and focused
- PRs MUST note scope, commands run, and any generated files
- Include before/after context for version bumps

### V. Validation Before Merge

All changes to `.devcontainer/` MUST pass the DevContainer build test before merging.

**Rationale**: Broken container builds block all downstream developers. The build test catches issues before they reach main.

**Non-negotiables**:
- Run `rcc run ... -t test-devcontainer-build` for container changes
- Attach key log excerpts if failures occur
- Lint Dockerfile with `hadolint .devcontainer/Dockerfile`
- Rehearse workflows locally with `scripts/run-maintenance-act.sh` when modifying CI

## Security & Least Privilege

This section extends Principle III with specific constraints:

- **Docker Integration**: Uses official `docker-in-docker` Feature (v2.12.4+) with privileged mode per Justified Exception above; all mitigations MUST be active
- **Kubernetes/DevPod**: Docker runs in a sidecar container sharing network/storage
- **Remote User**: Always `vscode` (non-root)
- **Shell**: ZSH as default with controlled plugin installation from trusted sources
- **External Dependencies**: Only from official sources (joshyorko/.dotfiles for shell config)
- **Supply Chain Security**: All artifacts signed with Cosign; SBOM attestations attached; CVE scanning enforced

## Development Workflow

**Local Development**:
1. Open in VS Code with Dev Containers extension
2. Container auto-builds and installs dependencies
3. Validate changes with RCC maintenance tasks

**CI/CD Pipeline** (`.github/workflows/`):
1. Triggered on push to `main` or manual dispatch
2. Builds DevContainer using `@devcontainers/cli`
3. Pushes to GitHub Container Registry (`ghcr.io/joshyorko/ror`)
4. Tags both SHA and `latest`

**Maintenance Workflow**:
1. Daily automated maintenance via `rcc-maintenance.yml`
2. Allowlist-governed updates only
3. Auto-commits approved changes using repository GITHUB_TOKEN

**Code Style**:
- Python: typed modules, `pathlib`, f-strings, standard library preferred
- Scripts: kebab-case naming
- Branches: lowercase dashed (e.g., `maintenance/dry-run`)

## Governance

This constitution supersedes all other development practices for the Room of Requirement repository.

**Amendment Process**:
1. Propose changes via PR with rationale
2. Update constitution version following semantic versioning:
   - MAJOR: Backward-incompatible principle changes or removals
   - MINOR: New principles or materially expanded guidance
   - PATCH: Clarifications, wording fixes, non-semantic refinements
3. Update `LAST_AMENDED_DATE` to amendment date
4. Propagate changes to dependent templates

**Compliance**:
- All PRs and reviews MUST verify compliance with these principles
- Complexity (additional tooling, patterns) MUST be justified against simplicity
- Use `AGENTS.md` for runtime development guidance
- Use `CLAUDE.md` for AI agent-specific instructions

**Version**: 1.1.0 | **Ratified**: 2026-01-01 | **Last Amended**: 2026-01-01
