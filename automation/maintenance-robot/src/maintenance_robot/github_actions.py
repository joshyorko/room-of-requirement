from __future__ import annotations

import logging
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, Iterable, Optional, Set

from packaging.version import InvalidVersion, Version
from ruamel.yaml import YAML
from ruamel.yaml.comments import CommentedMap, CommentedSeq

from .github_api import ReleaseInfo, fetch_latest_version
from .reporter import GitHubActionUpdate, MaintenanceReport

logger = logging.getLogger(__name__)

# Regex to parse action references with optional SHA and comment
# Matches: action@sha # tag or action@tag
ACTION_REF_PATTERN = re.compile(
    r"^(?P<action>[^@]+)@(?P<ref>[a-f0-9]{40}|[^\s#]+)(?:\s*#\s*(?P<comment>.*))?$"
)


@dataclass
class UpdateResult:
    """Result of an action update with separate value and comment."""
    value: str
    comment: Optional[str] = None


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

        def _walk(node: Any) -> None:
            nonlocal changed
            if isinstance(node, CommentedMap):
                for key in list(node.keys()):
                    value = node[key]
                    if key == "uses" and isinstance(value, str):
                        result = self._maybe_update_uses(value, path)
                        if result and result.value != value:
                            node[key] = result.value
                            # Add version as end-of-line comment using ruamel.yaml
                            if result.comment:
                                node.yaml_add_eol_comment(result.comment, key)
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

    def _maybe_update_uses(self, value: str, path: Path) -> Optional[UpdateResult]:
        original = value.strip()
        if "@" not in original:
            return None
        if original.startswith("./") or original.startswith("../"):
            return None
        if original.startswith("docker://"):
            return None

        # Parse the action reference (handles both SHA-pinned and tag-based refs)
        match = ACTION_REF_PATTERN.match(original)
        if not match:
            action, _, ref = original.partition("@")
            comment_version = None
        else:
            action = match.group("action")
            ref = match.group("ref")
            comment_version = match.group("comment")

        if action not in self.allowlist:
            return None

        ref = ref.strip()
        new_release = self._get_release(action)
        if new_release is None:
            logger.debug("No release info available for %s", action)
            return None

        # Determine current version from either the ref or the comment
        current_version = None

        # If ref is a SHA (40 hex chars), look for version in comment
        if len(ref) == 40 and all(c in "0123456789abcdef" for c in ref.lower()):
            if comment_version:
                current_version = self._to_version(comment_version.strip())
            # If already pinned to the same SHA, no update needed
            if new_release.sha and ref.lower() == new_release.sha.lower():
                return None
        else:
            current_version = self._to_version(ref)

        if current_version is None:
            logger.debug("Skipping non-version reference %s in %s", ref, path)
            return None

        if new_release.version <= current_version:
            return None

        # Build new value with SHA pinning if available
        if new_release.sha:
            new_value = f"{action}@{new_release.sha}"
            version_comment = new_release.tag
            updated_display = f"{new_release.sha[:7]} # {new_release.tag}"
        else:
            new_value = f"{action}@{new_release.tag}"
            version_comment = None
            updated_display = new_release.tag

        logger.info("Updating %s: %s -> %s", path, original, f"{new_value} # {version_comment}" if version_comment else new_value)
        self.report.add_action_update(
            GitHubActionUpdate(
                file=path,
                action=action,
                previous=ref if len(ref) != 40 else f"{ref[:7]} # {comment_version or 'unknown'}",
                updated=updated_display,
            )
        )
        return UpdateResult(value=new_value, comment=version_comment)

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
                    pin_to_sha=config.get("pin_to_sha", True),
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
