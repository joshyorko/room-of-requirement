# Repository Guidelines

## Project Structure & Module Organization
This repository builds and maintains reusable DevContainer images. Keep variant Dockerfiles and configurations in `src/<variant>/.devcontainer/`; shared bootstrap scripts, configuration, tool bundles, and helpers belong in `src/common/`. The root `.devcontainer/devcontainer.json` is the default entry configuration. Curated tool bundles live in `src/common/brew/*.Brewfile`.

Automation code lives in `automation/maintenance-robot/`. Edit Python sources under [automation/maintenance-robot/src/maintenance_robot](automation/maintenance-robot/src/maintenance_robot), not `output/`, which is generated. Workflow and release logic live in `.github/workflows/`. Template payloads live in `templates/ror-starter/`.

## Build, Test, and Development Commands
- `just --list` or `ujust`: list local helper commands from [src/common/justfile](src/common/justfile).
- `ujust bbrew`: install one curated Brewfile interactively.
- `ujust brew-install-all`: install every curated Brewfile for full-image testing.
- `ujust info`: verify shell, Homebrew, Docker, and `just` inside the container.
- `pre-commit run --all-files`: run the repo’s local lint suite.
- `rcc ht vars -r automation/maintenance-robot/robot.yaml --json`: resolve the robot environment.
- `rcc run -r automation/maintenance-robot/robot.yaml --task unit-tests --silent`: run non-mutating maintenance tests.
- `rcc run -r automation/maintenance-robot/robot.yaml --task maintenance --silent`: run the maintenance robot; this updates tracked dependency/configuration files.
- `devcontainer build --workspace-folder .`: sanity-check the image locally after container changes.

## Coding Style & Naming Conventions
Follow [.editorconfig](.editorconfig): UTF-8, LF, final newline, trimmed trailing whitespace. Use 4 spaces for shell, Python, and Dockerfiles; 2 spaces for YAML, JSON, and TOML. Keep Brewfiles and scripts narrowly scoped and named by purpose, for example `cloud.Brewfile` or `fix-docker-permissions.sh`.

## Testing & Validation
Validation combines regression tests, linting, and image/runtime verification. `pre-commit` runs `hadolint`, `yamllint`, `markdownlint`, and basic file hygiene hooks. Run the relevant tests under `tests/` and `automation/maintenance-robot/tests/`. For image/bootstrap changes, run a feature-aware `devcontainer build` and disposable runtime checks. For robot changes, run the non-mutating RCC `unit-tests` task before opening a PR. Never use live maintenance updates or existing user volumes as test fixtures.

## Commit & Pull Request Guidelines
Use the existing Conventional Commit style visible in history: `feat:`, `fix:`, `chore:`. Keep subjects imperative and scoped to one change. PRs should explain user impact on the image, templates, or maintenance robot, list the commands you ran, and include logs or screenshots when behavior changed. Do not commit generated files from `automation/maintenance-robot/output/` unless the change explicitly requires refreshed artifacts.
