from __future__ import annotations

import logging
import re
from pathlib import Path
from typing import Dict, List, Optional, Tuple

from packaging.version import InvalidVersion, Version

from .github_api import fetch_latest_version
from .reporter import DownloadUpdate, MaintenanceReport

logger = logging.getLogger(__name__)


class DownloadsUpdater:
    """Enhanced downloads updater with multi-pattern support and smart detection."""

    def __init__(
        self,
        allowlist: Dict[str, dict],
        repo_root: Path,
        report: MaintenanceReport,
    ) -> None:
        self.allowlist = allowlist
        self.repo_root = repo_root
        self.report = report

    def update_targets(self) -> None:
        """Process all downloads from allowlist with comprehensive pattern matching."""
        for identifier, config in self.allowlist.items():
            repo = config.get("repo")
            source = config.get("source", "release")
            include_prerelease = bool(config.get("include_prerelease", False))
            max_major = config.get("max_major")
            version_format = config.get("version_format", "full")  # full, major_only, major_minor

            release = fetch_latest_version(
                repo=repo,
                source=source,
                include_prerelease=include_prerelease,
                max_major=max_major,
            )
            if release is None:
                logger.debug("No release info for %s", identifier)
                continue

            targets = config.get("targets", [])
            for target in targets:
                path = self.repo_root / target["file"]
                if not path.exists():
                    logger.debug("Target file does not exist: %s", path)
                    continue

                # Support multiple patterns per target
                patterns = target.get("patterns", [target.get("pattern")])
                if not patterns or patterns == [None]:
                    logger.warning("No patterns defined for %s in %s", identifier, path)
                    continue

                for pattern_str in patterns:
                    pattern = re.compile(pattern_str, re.MULTILINE)
                    self._update_file(path, pattern, identifier, release.version, version_format)

    def _update_file(
        self,
        path: Path,
        pattern: re.Pattern[str],
        identifier: str,
        latest_version: Version,
        version_format: str = "full",
    ) -> None:
        """Update all occurrences of a version pattern in a file."""
        text = path.read_text(encoding="utf-8")

        # Find all matches
        matches = list(pattern.finditer(text))
        if not matches:
            logger.debug("Pattern %s not found in %s", pattern.pattern, path)
            return

        updates_made = 0
        new_text = text

        # Process matches in reverse order to preserve offsets
        for match in reversed(matches):
            current_version = match.group("version")
            maybe_version = self._to_version(current_version)

            if maybe_version is None:
                logger.debug("Current version not parseable: %s in %s", current_version, path)
                continue

            # Format the new version according to version_format
            formatted_version = self._format_version(latest_version, version_format)

            # For comparison, use the appropriate version parts
            if version_format == "major_only":
                # Compare major versions only
                if latest_version.major <= maybe_version.major:
                    logger.debug("Version %s already up to date (>= %s) in %s",
                               current_version, latest_version, path)
                    continue
            elif version_format == "major_minor":
                # Compare major.minor
                if (latest_version.major, latest_version.minor) <= (maybe_version.major, maybe_version.minor):
                    logger.debug("Version %s already up to date (>= %s) in %s",
                               current_version, latest_version, path)
                    continue
            else:  # full version comparison
                if latest_version <= maybe_version:
                    logger.debug("Version %s already up to date (>= %s) in %s",
                               current_version, latest_version, path)
                    continue

            # Replace this specific occurrence
            start, end = match.span()
            old_match = new_text[start:end]
            new_match = old_match.replace(current_version, formatted_version)
            new_text = new_text[:start] + new_match + new_text[end:]
            updates_made += 1

        if updates_made > 0:
            path.write_text(new_text, encoding="utf-8")
            logger.info(
                "Updated %s occurrences of %s in %s (previous: %s, new: %s)",
                updates_made,
                identifier,
                path,
                current_version,
                formatted_version,
            )
            self.report.add_download_update(
                DownloadUpdate(
                    file=path,
                    identifier=identifier,
                    previous=current_version,
                    updated=formatted_version,
                )
            )

    @staticmethod
    def _format_version(version: Version, format_type: str) -> str:
        """Format a version according to the specified format."""
        if format_type == "major_only":
            return str(version.major)
        elif format_type == "major_minor":
            return f"{version.major}.{version.minor}"
        else:  # full
            return str(version)

    @staticmethod
    def _to_version(raw: str) -> Optional[Version]:
        """Parse version string, handling common prefixes."""
        cleaned = raw.lstrip("vV")
        try:
            return Version(cleaned)
        except InvalidVersion:
            return None
