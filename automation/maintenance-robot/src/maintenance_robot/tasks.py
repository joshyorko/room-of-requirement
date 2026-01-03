from __future__ import annotations

import json
import logging
import subprocess
from pathlib import Path
from typing import Dict

from robocorp.tasks import task

from maintenance_robot.allowlist_loader import load_allowlist
from maintenance_robot.downloads import DownloadsUpdater
from maintenance_robot.github_actions import GitHubActionsUpdater
from maintenance_robot.homebrew import HomebrewUpdater
from maintenance_robot.reporter import MaintenanceReport
from maintenance_robot.devcontainer_lock import update_devcontainer_lockfile

logging.basicConfig(level=logging.INFO, format="[%(levelname)s] %(message)s")

PACKAGE_DIR = Path(__file__).resolve().parent
ROBOT_ROOT = PACKAGE_DIR.parent.parent
REPO_ROOT = ROBOT_ROOT.parent.parent
OUTPUT_DIR = ROBOT_ROOT / "output"


@task
def maintenance() -> None:
    """Run all maintenance tasks: update workflows, PyPI packages, and run pre-commit.

    This robot focuses on:
    1. GitHub Actions workflow version updates (github_actions.json)
    2. PyPI package updates for the maintenance robot itself (downloads.json)
    3. Homebrew version tracking (informational only)

    Homebrew tools are NOT auto-updated - they're managed via curated Brewfiles
    and updated manually or via `brew update && brew upgrade`.
    """

    allowlists = _load_allowlists()
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    report = MaintenanceReport()

    # Update GitHub Actions workflows
    actions_allowlist = allowlists.get("github_actions", {})
    workflows_dir = REPO_ROOT / ".github" / "workflows"
    if workflows_dir.exists():
        updater = GitHubActionsUpdater(actions_allowlist, report=report)
        updated_files = updater.update_workflows(workflows_dir)
        if updated_files:
            logging.info("Updated GitHub Actions workflows: %s", ", ".join(sorted(updated_files)))
    else:
        logging.info("No workflows directory found; skipping workflow updates.")

    # Update PyPI packages
    downloads_allowlist = allowlists.get("downloads", {})
    if downloads_allowlist:
        downloads_updater = DownloadsUpdater(downloads_allowlist, repo_root=REPO_ROOT, report=report)
        downloads_updater.update_targets()

    # Log Homebrew versions for informational purposes (no updates)
    homebrew_allowlist = allowlists.get("homebrew", {})
    if homebrew_allowlist:
        homebrew_updater = HomebrewUpdater(homebrew_allowlist, report=report)
        versions = homebrew_updater.update_formulas()
        if versions:
            logging.info("Homebrew formula versions (baked into image): %s", versions)

    # Regenerate devcontainer lockfile to keep feature digests pinned
    update_devcontainer_lockfile(REPO_ROOT, report)

    # Run pre-commit to auto-fix formatting issues
    _run_precommit_autofixes()

    report_path = OUTPUT_DIR / "maintenance_report.json"
    report_path.write_text(json.dumps(report.to_dict(), indent=2), encoding="utf-8")
    logging.info("Wrote maintenance report to %s", report_path)


@task
def update_workflows_only() -> None:
    """Update GitHub Actions workflows only."""
    allowlists = _load_allowlists()
    report = MaintenanceReport()
    workflows_dir = REPO_ROOT / ".github" / "workflows"
    updater = GitHubActionsUpdater(allowlists.get("github_actions", {}), report=report)
    updater.update_workflows(workflows_dir)
    _write_report(report)


@task
def update_downloads_only() -> None:
    """Update PyPI packages with version updates."""
    allowlists = _load_allowlists()
    report = MaintenanceReport()
    downloads_updater = DownloadsUpdater(
        allowlists.get("downloads", {}),
        repo_root=REPO_ROOT,
        report=report,
    )
    downloads_updater.update_targets()
    _write_report(report)


@task
def update_devcontainer_lock_only() -> None:
    """Regenerate the devcontainer lockfile only."""
    report = MaintenanceReport()
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    update_devcontainer_lockfile(REPO_ROOT, report)
    _write_report(report)


@task
def test_devcontainer_build() -> None:
    """Test devcontainer build using @devcontainers/cli."""
    logging.info("Testing devcontainer build with @devcontainers/cli...")

    try:
        # Use devcontainer CLI to build
        cmd = [
            "devcontainer", "build",
            "--workspace-folder", str(REPO_ROOT),
            "--log-level", "info",
        ]
        logging.info("Running: %s", " ".join(cmd))
        # Stream output in real-time instead of capturing it
        subprocess.run(
            cmd,
            check=True,
            cwd=str(REPO_ROOT),
        )
        logging.info("Build successful!")
    except subprocess.CalledProcessError as e:
        logging.error("Build failed with exit code %d", e.returncode)
        raise
    except FileNotFoundError:
        logging.error("devcontainer CLI not found. Ensure @devcontainers/cli is installed via npm.")
        raise


@task
def update_homebrew_only() -> None:
    """Query and log Homebrew formula versions (informational only - no file updates).

    Since we use Homebrew-first with curated Brewfiles, tools are updated via
    `brew update && brew upgrade`, not via this maintenance robot.
    """
    allowlists = _load_allowlists()
    report = MaintenanceReport()
    homebrew_updater = HomebrewUpdater(allowlists.get("homebrew", {}), report=report)
    versions = homebrew_updater.update_formulas()
    if versions:
        logging.info("Homebrew formula versions (baked into image): %s", versions)
    _write_report(report)


def _load_allowlists() -> Dict[str, Dict[str, dict]]:
    allowlists_dir = ROBOT_ROOT / "allowlists"
    return {
        "github_actions": load_allowlist(allowlists_dir / "github_actions.json"),
        "downloads": load_allowlist(allowlists_dir / "downloads.json"),
        "homebrew": load_allowlist(allowlists_dir / "homebrew.json"),
    }


def _write_report(report: MaintenanceReport) -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    report_path = OUTPUT_DIR / "maintenance_report.json"
    report_path.write_text(json.dumps(report.to_dict(), indent=2), encoding="utf-8")
    logging.info("Wrote maintenance report to %s", report_path)


def _run_precommit_autofixes() -> None:
    """Run pre-commit hooks to auto-fix formatting issues."""
    logging.info("Running pre-commit auto-fixes...")
    try:
        # Run prettier on YAML files first to fix formatting
        logging.info("Running prettier on YAML files...")
        prettier_result = subprocess.run(
            ["prettier", "--write", "**/*.{yaml,yml}"],
            cwd=str(REPO_ROOT),
            capture_output=True,
            text=True,
            shell=False,
        )
        if prettier_result.returncode == 0:
            logging.info("Prettier formatting completed")
        else:
            logging.warning("Prettier had issues: %s", prettier_result.stderr)

        # First ensure pre-commit hooks are installed (downloads all tools)
        logging.info("Installing pre-commit hooks...")
        install_result = subprocess.run(
            ["pre-commit", "install-hooks"],
            cwd=str(REPO_ROOT),
            capture_output=False,
            text=True,
        )
        if install_result.returncode != 0:
            logging.warning("Failed to install pre-commit hooks")
            return

        # Run pre-commit with output visible
        logging.info("Running pre-commit on all files...")
        result = subprocess.run(
            ["pre-commit", "run", "--all-files"],
            cwd=str(REPO_ROOT),
            capture_output=False,
            text=True,
        )

        if result.returncode == 0:
            logging.info("All pre-commit hooks passed")
        else:
            logging.info("Pre-commit completed (some hooks may have made fixes)")
    except FileNotFoundError as e:
        logging.warning("Tool not found: %s", e)
    except Exception as e:
        logging.warning("Pre-commit failed: %s", e)
