# Repository Guidelines

## Project Structure & Module Organization
This repository builds and maintains a reusable DevContainer image, not a traditional app. Keep image and bootstrap changes in `.devcontainer/`:
`Dockerfile`, `devcontainer.json`, `entrypoint.sh`, `post-create.sh`, and `.devcontainer/scripts/`. Curated tool bundles live in `.devcontainer/brew/*.Brewfile`.

Automation code lives in `automation/maintenance-robot/`. Edit Python sources under [automation/maintenance-robot/src/maintenance_robot](/var/home/kdlocpanda/second_brain/Areas/devcontainers/room-of-requirement/automation/maintenance-robot/src/maintenance_robot), not `output/`, which is generated. Workflow and release logic live in `.github/workflows/`. Template payloads live in `templates/ror-starter/`.

## Build, Test, and Development Commands
- `just --list` or `ujust`: list local helper commands from [.devcontainer/justfile](/var/home/kdlocpanda/second_brain/Areas/devcontainers/room-of-requirement/.devcontainer/justfile).
- `ujust bbrew`: install one curated Brewfile interactively.
- `ujust brew-install-all`: install every curated Brewfile for full-image testing.
- `ujust info`: verify shell, Homebrew, Docker, and `just` inside the container.
- `pre-commit run --all-files`: run the repo’s local lint suite.
- `rcc ht vars -r automation/maintenance-robot/robot.yaml --json`: resolve the robot environment.
- `rcc run -r automation/maintenance-robot/robot.yaml --task maintenance --silent`: run the maintenance robot.
- `devcontainer build --workspace-folder .`: sanity-check the image locally after container changes.

## Coding Style & Naming Conventions
Follow [.editorconfig](/var/home/kdlocpanda/second_brain/Areas/devcontainers/room-of-requirement/.editorconfig): UTF-8, LF, final newline, trimmed trailing whitespace. Use 4 spaces for shell, Python, and Dockerfiles; 2 spaces for YAML, JSON, and TOML. Keep Brewfiles and scripts narrowly scoped and named by purpose, for example `cloud.Brewfile` or `fix-docker-permissions.sh`.

## Testing & Validation
There is no standalone application test suite. Validation is mostly linting and build verification: `pre-commit` runs `hadolint`, `yamllint`, `markdownlint`, and basic file hygiene hooks. For `.devcontainer/` changes, run `devcontainer build` and spot-check `ujust info`. For robot changes, run the smallest relevant RCC task before opening a PR.

## Commit & Pull Request Guidelines
Use the existing Conventional Commit style visible in history: `feat:`, `fix:`, `chore:`. Keep subjects imperative and scoped to one change. PRs should explain user impact on the image, templates, or maintenance robot, list the commands you ran, and include logs or screenshots when behavior changed. Do not commit generated files from `automation/maintenance-robot/output/` unless the change explicitly requires refreshed artifacts.
