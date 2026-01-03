from __future__ import annotations

import hashlib
import logging
import re
import requests
from pathlib import Path
from typing import Dict, Optional

from packaging.version import InvalidVersion, Version

from .github_api import fetch_latest_version as fetch_github_version
from .npm_api import fetch_latest_version as fetch_npm_version
from .pypi_api import fetch_latest_version as fetch_pypi_version
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
        logger.info("Processing %d download targets from allowlist", len(self.allowlist))
        for identifier, config in self.allowlist.items():
            logger.info("\n=== Processing: %s ===", identifier)
            source = config.get("source", "release")
            include_prerelease = bool(config.get("include_prerelease", False))
            max_major = config.get("max_major")
            version_format = config.get("version_format", "full")  # full, major_only, major_minor
            logger.info("  Source: %s, Prerelease: %s, Max Major: %s", source, include_prerelease, max_major)

            # Fetch version info based on source type
            if source == "pypi":
                package = config.get("package")
                if not package:
                    logger.warning("PyPI source requires 'package' field for %s", identifier)
                    continue
                logger.info("  Fetching PyPI package: %s", package)
                package_info = fetch_pypi_version(
                    package=package,
                    include_prerelease=include_prerelease,
                    max_major=max_major,
                )
                if package_info is None:
                    logger.warning("  ⚠ No package info found for %s", identifier)
                    continue
                version = package_info.version
                version_str = package_info.version_str
                logger.info("  ✓ Latest PyPI version: %s", version_str)
            elif source == "npm":
                package = config.get("package")
                if not package:
                    logger.warning("npm source requires 'package' field for %s", identifier)
                    continue
                logger.info("  Fetching npm package: %s", package)
                package_info = fetch_npm_version(
                    package=package,
                    include_prerelease=include_prerelease,
                    max_major=max_major,
                )
                if package_info is None:
                    logger.warning("  ⚠ No package info found for %s", identifier)
                    continue
                version = package_info.version
                version_str = package_info.version_str
                logger.info("  ✓ Latest npm version: %s", version_str)
            elif source == "custom":
                # Handle custom version fetching (e.g., Claude Code)
                stable_version_url = config.get("stable_version_url")
                if not stable_version_url:
                    logger.warning("  ⚠ Custom source requires 'stable_version_url' field for %s", identifier)
                    continue
                logger.info("  Fetching custom version from: %s", stable_version_url)
                try:
                    response = requests.get(stable_version_url, timeout=30)
                    response.raise_for_status()
                    version_str = response.text.strip()
                    version = self._to_version(version_str)
                    if version is None:
                        logger.warning("  ⚠ Could not parse version from custom source: %s", version_str)
                        continue
                    logger.info("  ✓ Latest custom version: %s", version_str)
                except Exception as e:
                    logger.warning("  ⚠ Failed to fetch custom version for %s: %s", identifier, e)
                    continue
            else:
                # GitHub release or tag
                repo = config.get("repo")
                if not repo:
                    logger.warning("  ⚠ GitHub source requires 'repo' field for %s", identifier)
                    continue
                logger.info("  Fetching GitHub %s from repo: %s", source, repo)
                feature_name = config.get("feature_name")
                if feature_name:
                    logger.info("  Filtering by feature name: %s", feature_name)
                release = fetch_github_version(
                    repo=repo,
                    source=source,
                    include_prerelease=include_prerelease,
                    max_major=max_major,
                    feature_name=feature_name,
                )
                if release is None:
                    logger.warning("  ⚠ No %s info found for %s (repo: %s)", source, identifier, repo)
                    continue
                version = release.version
                logger.info("  ✓ Latest GitHub %s version: %s (tag: %s)", source, version, release.tag)

            targets = config.get("targets", [])
            download_url_template = config.get("download_url_template")
            manifest_url_template = config.get("manifest_url_template")
            platform = config.get("platform")
            logger.info("  Processing %d target(s)", len(targets))
            for target_idx, target in enumerate(targets, 1):
                path = self.repo_root / target["file"]
                logger.info("  Target %d: %s", target_idx, path.relative_to(self.repo_root))
                if not path.exists():
                    logger.warning("    ⚠ Target file does not exist: %s", path)
                    continue

                # Check if this target has SHA256 tracking
                sha256_pattern_str = target.get("sha256_pattern")

                # Support multiple patterns per target
                patterns = target.get("patterns", [target.get("pattern")])
                if not patterns or patterns == [None]:
                    logger.warning("    ⚠ No patterns defined for %s in %s", identifier, path)
                    continue
                logger.info("    Checking %d pattern(s)", len(patterns))

                for pattern_idx, pattern_str in enumerate(patterns, 1):
                    logger.info("    Pattern %d: %s", pattern_idx, pattern_str[:80] + "..." if len(pattern_str) > 80 else pattern_str)
                    pattern = re.compile(pattern_str, re.MULTILINE)
                    self._update_file(path, pattern, identifier, version, version_format,
                                    sha256_pattern_str, download_url_template, manifest_url_template, platform)

    def _update_file(
        self,
        path: Path,
        pattern: re.Pattern[str],
        identifier: str,
        latest_version: Version,
        version_format: str = "full",
        sha256_pattern_str: Optional[str] = None,
        download_url_template: Optional[str] = None,
        manifest_url_template: Optional[str] = None,
        platform: Optional[str] = None,
    ) -> None:
        """Update all occurrences of a version pattern in a file, and optionally update SHA256."""
        text = path.read_text(encoding="utf-8")

        # Find all matches
        matches = list(pattern.finditer(text))
        if not matches:
            logger.info("      ℹ Pattern not found in file (no matches)")
            return
        logger.info("      Found %d match(es) in file", len(matches))

        updates_made = 0
        new_text = text
        first_old_version = None
        last_new_version = None

        # Process matches in reverse order to preserve offsets
        for match_idx, match in enumerate(reversed(matches), 1):
            current_version = match.group("version")
            logger.info("      Match %d: current version = %s", match_idx, current_version)
            maybe_version = self._to_version(current_version)

            if maybe_version is None:
                logger.warning("      ⚠ Current version not parseable: %s", current_version)
                continue
            logger.info("      Parsed as: %s", maybe_version)

            # Format the new version according to version_format
            formatted_version = self._format_version(latest_version, version_format)

            # For comparison, use the appropriate version parts
            if version_format == "major_only":
                # Compare major versions only
                if latest_version.major <= maybe_version.major:
                    logger.info("      ✓ Already up to date: %s >= %s (major only)",
                               current_version, latest_version)
                    continue
                logger.info("      🔄 Update available: %s -> %s (major only)",
                           current_version, formatted_version)
            elif version_format == "major_minor":
                # Compare major.minor
                if (latest_version.major, latest_version.minor) <= (maybe_version.major, maybe_version.minor):
                    logger.info("      ✓ Already up to date: %s >= %s (major.minor)",
                               current_version, latest_version)
                    continue
                logger.info("      🔄 Update available: %s -> %s (major.minor)",
                           current_version, formatted_version)
            else:  # full version comparison
                if latest_version <= maybe_version:
                    logger.info("      ✓ Already up to date: %s >= %s (full)",
                               current_version, latest_version)
                    continue
                logger.info("      🔄 Update available: %s -> %s (full)",
                           current_version, formatted_version)

            # Track first old version encountered (last in file due to reverse order)
            if first_old_version is None:
                first_old_version = current_version

            # Replace this specific occurrence
            start, end = match.span()
            old_match = new_text[start:end]
            new_match = old_match.replace(current_version, formatted_version)
            new_text = new_text[:start] + new_match + new_text[end:]
            last_new_version = formatted_version
            updates_made += 1

        if updates_made > 0:
            assert first_old_version is not None and last_new_version is not None
            path.write_text(new_text, encoding="utf-8")
            logger.info(
                "Updated %s occurrences of %s in %s (previous: %s, new: %s)",
                updates_made,
                identifier,
                path,
                first_old_version,
                last_new_version,
            )
            self.report.add_download_update(
                DownloadUpdate(
                    file=path,
                    identifier=identifier,
                    previous=first_old_version,
                    updated=last_new_version,
                )
            )

            # If SHA256 pattern is provided, update the checksum too
            if sha256_pattern_str and (download_url_template or manifest_url_template):
                logger.info("      🔐 Updating SHA256 checksum...")
                self._update_sha256(path, sha256_pattern_str, formatted_version,
                                    download_url_template, manifest_url_template, platform)

    def _update_sha256(
        self,
        path: Path,
        sha256_pattern_str: str,
        version: str,
        download_url_template: Optional[str] = None,
        manifest_url_template: Optional[str] = None,
        platform: Optional[str] = None,
    ) -> None:
        """Update SHA256 checksum for a given version."""
        # Determine if we need to fetch from manifest or compute from download
        if manifest_url_template and platform:
            # Fetch SHA256 from manifest (e.g., Claude Code)
            manifest_url = manifest_url_template.format(version=version)
            new_sha256 = self._fetch_sha256_from_manifest(manifest_url, platform)
        elif download_url_template:
            # Compute SHA256 by downloading the file
            download_url = download_url_template.format(version=version)
            new_sha256 = self._compute_sha256_from_url(download_url)
        else:
            logger.warning("      ⚠ No download_url_template or manifest_url_template provided")
            return

        if not new_sha256:
            logger.warning("      ⚠ Could not compute SHA256, skipping checksum update")
            return

        # Update SHA256 in file
        text = path.read_text(encoding="utf-8")
        sha256_pattern = re.compile(sha256_pattern_str, re.MULTILINE)
        matches = list(sha256_pattern.finditer(text))

        if not matches:
            logger.warning("      ⚠ SHA256 pattern not found in file")
            return

        if len(matches) > 1:
            logger.warning("      ⚠ Multiple SHA256 matches found, updating first occurrence only")

        match = matches[0]
        old_sha256 = match.group("sha256")

        if old_sha256 == new_sha256:
            logger.info("      ✓ SHA256 already up to date: %s", new_sha256[:16] + "...")
            return

        # Replace the SHA256
        start, end = match.span()
        old_match = text[start:end]
        new_match = old_match.replace(old_sha256, new_sha256)
        new_text = text[:start] + new_match + text[end:]
        path.write_text(new_text, encoding="utf-8")
        logger.info("      ✅ Updated SHA256: %s... -> %s...", old_sha256[:16], new_sha256[:16])

    @staticmethod
    def _fetch_sha256_from_manifest(manifest_url: str, platform: str) -> Optional[str]:
        """Fetch SHA256 checksum from a manifest JSON file."""
        try:
            logger.info("      📥 Fetching manifest: %s", manifest_url)
            response = requests.get(manifest_url, timeout=30)
            response.raise_for_status()
            manifest = response.json()
            platforms = manifest.get("platforms", {})
            platform_data = platforms.get(platform, {})
            checksum = platform_data.get("checksum")

            if checksum:
                logger.info("      ✓ Found SHA256 in manifest for %s: %s", platform, checksum)
                return checksum
            else:
                logger.warning("      ⚠ Platform %s not found in manifest or missing checksum", platform)
                return None
        except Exception as e:
            logger.warning("      ⚠ Failed to fetch SHA256 from manifest %s: %s", manifest_url, e)
            return None

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

    @staticmethod
    def _compute_sha256_from_url(url: str) -> Optional[str]:
        """Download a file and compute its SHA256 checksum."""
        try:
            logger.info("      📥 Downloading to compute SHA256: %s", url)
            response = requests.get(url, timeout=60, stream=True)
            response.raise_for_status()

            sha256_hash = hashlib.sha256()
            for chunk in response.iter_content(chunk_size=8192):
                sha256_hash.update(chunk)

            checksum = sha256_hash.hexdigest()
            logger.info("      ✓ Computed SHA256: %s", checksum)
            return checksum
        except Exception as e:
            logger.warning("      ⚠ Failed to compute SHA256 from %s: %s", url, e)
            return None
