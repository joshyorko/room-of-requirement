from __future__ import annotations

import logging
from dataclasses import dataclass
from functools import lru_cache
from typing import Optional

import requests
from packaging.version import InvalidVersion, Version
from tenacity import retry, retry_if_exception_type, stop_after_attempt, wait_exponential

logger = logging.getLogger(__name__)

NPM_REGISTRY_ROOT = "https://registry.npmjs.org"


class NPMAPIError(RuntimeError):
    """Raised when npm registry API responses cannot be parsed."""


@dataclass(frozen=True)
class PackageInfo:
    version: Version
    version_str: str


@retry(
    wait=wait_exponential(multiplier=1, min=1, max=8),
    stop=stop_after_attempt(4),
    retry=retry_if_exception_type((requests.RequestException, NPMAPIError)),
)
def _get(url: str) -> dict:
    response = requests.get(url, timeout=30)
    if response.status_code >= 400:
        raise NPMAPIError(f"npm registry API error {response.status_code}: {response.text}")
    try:
        data = response.json()
    except ValueError as exc:
        raise NPMAPIError("Failed to decode JSON from npm registry API") from exc
    if not isinstance(data, dict):
        raise NPMAPIError("Expected dict response from npm registry API")
    return data


@lru_cache(maxsize=128)
def fetch_latest_version(
    package: str,
    include_prerelease: bool = False,
    max_major: Optional[int] = None,
) -> Optional[PackageInfo]:
    """Fetch the latest version for an npm package respecting constraints."""
    url = f"{NPM_REGISTRY_ROOT}/{package}"
    data = _get(url)

    # Get dist-tags for latest version
    dist_tags = data.get("dist-tags", {})
    latest_tag = dist_tags.get("latest")

    if latest_tag and not include_prerelease:
        try:
            version = Version(latest_tag)
            if max_major is not None and version.major > max_major:
                logger.debug(
                    "Latest version %s exceeds max_major=%s, checking versions",
                    latest_tag,
                    max_major,
                )
            else:
                return PackageInfo(version=version, version_str=latest_tag)
        except InvalidVersion:
            logger.warning("Invalid version from npm for %s: %s", package, latest_tag)

    # Fallback: parse all versions and find the best match
    versions_data = data.get("versions", {})
    valid_versions: list[tuple[Version, str]] = []

    for version_str in versions_data:
        try:
            version = Version(version_str)
            # Skip prereleases if not allowed
            if not include_prerelease and version.is_prerelease:
                continue
            # Skip versions exceeding max_major
            if max_major is not None and version.major > max_major:
                continue
            valid_versions.append((version, version_str))
        except InvalidVersion:
            logger.debug("Skipping invalid version: %s", version_str)

    if not valid_versions:
        return None

    # Sort and return the latest
    valid_versions.sort(reverse=True)
    version, version_str = valid_versions[0]
    return PackageInfo(version=version, version_str=version_str)
