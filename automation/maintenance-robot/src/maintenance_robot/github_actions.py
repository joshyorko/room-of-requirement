from __future__ import annotations

import logging
from pathlib import Path
from typing import Dict, Iterable, Optional, Set

from packaging.version import InvalidVersion, Version
from ruamel.yaml import YAML
from ruamel.yaml.comments import CommentedMap, CommentedSeq

from .github_api import ReleaseInfo, fetch_latest_version
from .reporter import GitHubActionUpdate, MaintenanceReport

logger = logging.getLogger(__name__)


class GitHubActionsUpdater:
    def __init__(self, allowlist: Dict[str, dict], report: MaintenanceReport) -> None:
        self.allowlist = allowlist
        self.report = report
        self._release_cache: Dict[str, Optional[ReleaseInfo]] = {}
        self.yaml = YAML()
        self.yaml.preserve_quotes = True
        self.yaml.width = 1000

    def update_workflows(self, workflows_dir: Path) -> Set[str]:
        updated_files: Set[str] = set()
        candidates = list(self._iter_workflow_files(workflows_dir))
        for path in candidates:
            if self._update_workflow(path):
                updated_files.add(str(path.relative_to(workflows_dir.parent)))
        return updated_files

    def _iter_workflow_files(self, workflows_dir: Path) -> Iterable[Path]:
        for extension in ("*.yml", "*.yaml"):
            for path in workflows_dir.glob(extension):
                yield path

    def _update_workflow(self, path: Path) -> bool:
        content = path.read_text(encoding="utf-8")
        data = self.yaml.load(content)

        changed = False

        def _walk(node: object) -> None:
            nonlocal changed
            if isinstance(node, CommentedMap):
                for key in list(node.keys()):
                    value = node[key]
                    if key == "uses" and isinstance(value, str):
                        new_value = self._maybe_update_uses(value, path)
                        if new_value and new_value != value:
                            node[key] = new_value
                            changed = True
                    else:
                        _walk(value)
            elif isinstance(node, CommentedSeq):
                for item in node:
                    _walk(item)

        _walk(data)

        if changed:
            with path.open("w", encoding="utf-8") as stream:
                self.yaml.dump(data, stream)
        return changed

    def _maybe_update_uses(self, value: str, path: Path) -> Optional[str]:
        original = value.strip()
        if "@" not in original:
            return None
        if original.startswith("./") or original.startswith("../"):
            return None
        if original.startswith("docker://"):
            return None

        action, _, ref = original.partition("@")
        if action not in self.allowlist:
            return None

        ref = ref.strip()
        new_release = self._get_release(action)
        if new_release is None:
            logger.debug("No release info available for %s", action)
            return None

        current_version = self._to_version(ref)
        if current_version is None:
            logger.debug("Skipping non-version reference %s in %s", ref, path)
            return None

        if new_release.version <= current_version:
            return None

        new_value = f"{action}@{new_release.tag}"
        logger.info("Updating %s: %s -> %s", path, original, new_value)
        self.report.add_action_update(
            GitHubActionUpdate(
                file=path,
                action=action,
                previous=ref,
                updated=new_release.tag,
            )
        )
        return new_value

    def _get_release(self, action: str) -> Optional[ReleaseInfo]:
        if action not in self._release_cache:
            config = self.allowlist.get(action, {})
            repo = config.get("repo")
            if not repo:
                logger.warning("Missing repo for action %s in allowlist", action)
                self._release_cache[action] = None
            else:
                self._release_cache[action] = fetch_latest_version(
                    repo=repo,
                    source=config.get("source", "release"),
                    include_prerelease=bool(config.get("include_prerelease", False)),
                    max_major=config.get("max_major"),
                )
        return self._release_cache[action]

    @staticmethod
    def _to_version(ref: str) -> Optional[Version]:
        trimmed = ref.strip()
        if trimmed.startswith("refs/tags/"):
            trimmed = trimmed[len("refs/tags/"):]
        if trimmed.startswith("v"):
            trimmed = trimmed[1:]
        try:
            return Version(trimmed)
        except InvalidVersion:
            return None
