from __future__ import annotations

import json
import logging
import shutil
import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Optional

from .reporter import LockfileUpdate, MaintenanceReport

logger = logging.getLogger(__name__)


@dataclass
class _LockfileDiffResult:
    changes: List[LockfileUpdate]
    created: bool = False


def update_devcontainer_lockfile(repo_root: Path, report: MaintenanceReport) -> None:
    """Ensure the devcontainer lockfile is present and up to date.

    This uses the Dev Container CLI (installed inside the RCC environment) to
    regenerate the lockfile. If the CLI isn't available, the step is skipped but
    logged so downstream tooling can react accordingly.
    """

    devcontainer_cli = shutil.which("devcontainer")
    if not devcontainer_cli:
        logger.warning(
            "devcontainer CLI not found in PATH; skipping lockfile refresh."
        )
        return

    config_dir = repo_root / ".devcontainer"
    config_file = config_dir / "devcontainer.json"
    if not config_file.exists():
        logger.info("No devcontainer configuration found; skipping lockfile update.")
        return

    # Check if there are any features to lock
    try:
        config_data = json.loads(config_file.read_text())
        features = config_data.get("features", {})
        if not features:
            logger.info("No features defined in devcontainer.json; skipping lockfile update.")
            return
    except (json.JSONDecodeError, IOError) as exc:
        logger.warning("Could not parse devcontainer.json: %s", exc)
        return

    lockfile_path = config_dir / "devcontainer-lock.json"
    old_lock = _read_lockfile(lockfile_path)

    cmd = [
        devcontainer_cli,
        "upgrade",
        "--workspace-folder",
        str(repo_root),
        "--log-level",
        "info",
    ]

    try:
        subprocess.run(cmd, cwd=str(repo_root), check=True)
    except subprocess.CalledProcessError as exc:
        logger.error("devcontainer CLI failed with exit code %s", exc.returncode)
        raise

    if not lockfile_path.exists():
        logger.warning(
            "devcontainer CLI completed but lockfile was not produced at %s",
            lockfile_path,
        )
        return

    new_lock = _read_lockfile(lockfile_path)
    diff = _diff_lockfiles(old_lock, new_lock)

    if not diff.changes:
        logger.info("Devcontainer lockfile already up to date.")
        return

    for change in diff.changes:
        report.add_lockfile_update(change)

    if diff.created:
        logger.info("Generated new devcontainer lockfile with %d entries.", len(diff.changes))
    else:
        logger.info("Updated devcontainer lockfile with %d changes.", len(diff.changes))


def _read_lockfile(path: Path) -> Dict[str, Dict[str, str]]:
    if not path.exists():
        return {}
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
        features = data.get("features", {})

        # Handle both dict and list formats for features
        if isinstance(features, dict):
            return features
        elif isinstance(features, list):
            # Convert array format to dict format
            # Array items should have an 'id' field as the key
            result = {}
            for item in features:
                if isinstance(item, dict) and "id" in item:
                    feature_id = item["id"]
                    # Remove 'id' from the entry since it's now the key
                    entry = {k: v for k, v in item.items() if k != "id"}
                    result[feature_id] = entry
            return result
        else:
            logger.warning(
                "Lockfile at %s has unexpected 'features' type %s; treating as empty.",
                path,
                type(features).__name__,
            )
            return {}
    except json.JSONDecodeError:
        logger.warning("Lockfile at %s is invalid JSON; treating as empty.", path)
        return {}


def _diff_lockfiles(
    old: Dict[str, Dict[str, str]],
    new: Dict[str, Dict[str, str]],
) -> _LockfileDiffResult:
    changes: List[LockfileUpdate] = []
    created = not bool(old) and bool(new)

    # Defensive check: ensure both old and new are dicts with string keys
    if not isinstance(old, dict):
        logger.warning("old lockfile is not a dict (type: %s); treating as empty", type(old).__name__)
        old = {}
    if not isinstance(new, dict):
        logger.warning("new lockfile is not a dict (type: %s); treating as empty", type(new).__name__)
        new = {}

    all_features = sorted(set(old.keys()) | set(new.keys()))
    for feature in all_features:
        previous = old.get(feature)
        updated = new.get(feature)
        if previous == updated:
            continue
        changes.append(
            LockfileUpdate(
                feature=feature,
                previous=_normalise_entry(previous),
                updated=_normalise_entry(updated),
            )
        )

    return _LockfileDiffResult(changes=changes, created=created)


def _normalise_entry(entry: Optional[Dict[str, str]]) -> Optional[Dict[str, str]]:
    if entry is None:
        return None
    keys = ["version", "resolved", "integrity"]
    result = {key: value for key in keys if (value := entry.get(key)) is not None}
    return result or None
