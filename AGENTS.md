# Repository Guidelines

## Project Structure & Modules
- `.devcontainer/` contains the Dockerfile, `devcontainer.json`, and lockfile that define the workspace image. Treat ARG pins and checksums as authoritative.
- `automation/maintenance-robot/` hosts the RCC-powered updater; Python sources live under `automation/maintenance-robot/src/maintenance_robot/`.
- `.github/workflows/` holds CI (daily maintenance, CI/CD helpers). Generated artifacts under `automation/maintenance-robot/output/` are ignored.
- `scripts/` includes helpers like `run-maintenance-act.sh` for local workflow rehearsal with `act`.

## Build, Test, and Development Commands
- Full maintenance sweep: `rcc run -r automation/maintenance-robot/robot.yaml -t maintenance`
- Workflow-only update: `rcc run -r automation/maintenance-robot/robot.yaml -t update-workflows`
- Download-only update: `rcc run -r automation/maintenance-robot/robot.yaml -t update-downloads`
- Devcontainer build check: `rcc run -r automation/maintenance-robot/robot.yaml -t test-devcontainer-build` (requires `@devcontainers/cli`)
- Lint Dockerfile: `hadolint .devcontainer/Dockerfile`
- Rehearse maintenance GitHub Action locally: `scripts/run-maintenance-act.sh` (set `GITHUB_TOKEN` to avoid rate limits)

## Coding Style & Naming
- Python automation follows typed modules, `pathlib`, and clear logging; prefer f-strings and standard library over extra deps.
- Keep Dockerfile ARG pins and SHA256 checksums paired; maintain multi-stage build structure.
- Use conventional commits seen in history (`chore:`, `docs:`, `fix:`) with concise, imperative subjects.
- Prefer snake_case for Python, kebab-case for scripts, and lowercase dashed branch names (e.g., `maintenance/dry-run`).

## Testing Guidelines
- No app test suite; validation centers on automation: run the relevant `rcc` task and ensure it completes without errors.
- For container changes, run `rcc ... -t test-devcontainer-build` before submitting; attach key log excerpts if failures occur.
- Regenerate artifacts only via the robot tasks; do not hand-edit `devcontainer-lock.json`.

## Commit & Pull Request Guidelines
- Keep commits small and focused; include the maintenance task or script used when relevant.
- PRs should note scope, commands run, and any generated files. Link related issues or maintenance tickets.
- Include before/after context for Dockerfile or workflow version bumps; mention if checksums were updated alongside versions.
- Screenshots are unnecessary unless documenting UI from a downstream sample.

## Security & Configuration Tips
- Do not introduce privileged Docker settings; the image assumes Docker-in-Docker with least privilege.
- Store tokens (e.g., `GITHUB_TOKEN`) in the environment, not in files. Generated outputs under `automation/maintenance-robot/output/` remain untracked.
