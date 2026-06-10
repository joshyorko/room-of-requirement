from __future__ import annotations

import logging
from dataclasses import dataclass
from functools import lru_cache
from typing import Optional

import requests
from packaging.version import InvalidVersion, Version
from tenacity import retry, retry_if_exception_type, stop_after_attempt, wait_exponential

logger = logging.getLogger(__name__)

ANACONDA_API_ROOT = "https://api.anaconda.org/package"


class CondaAPIError(RuntimeError):
    """Raised when Anaconda package API responses cannot be parsed."""


@dataclass(frozen=True)
class PackageInfo:
    version: Version
    version_str: str


@retry(
    wait=wait_exponential(multiplier=1, min=1, max=8),
    stop=stop_after_attempt(4),
    retry=retry_if_exception_type((requests.RequestException, CondaAPIError)),
)
def _get(url: str) -> dict:
    response = requests.get(url, timeout=30)
    if response.status_code >= 400:
        raise CondaAPIError(f"Anaconda API error {response.status_code}: {response.text}")
    try:
        data = response.json()
    except ValueError as exc:
        raise CondaAPIError("Failed to decode JSON from Anaconda API") from exc
    if not isinstance(data, dict):
        raise CondaAPIError("Expected dict response from Anaconda API")
    return data


@lru_cache(maxsize=128)
def fetch_latest_version(
    channel: str,
    package: str,
    platform: Optional[str] = None,
    include_prerelease: bool = False,
    max_major: Optional[int] = None,
) -> Optional[PackageInfo]:
    """Fetch the latest Conda package version for a channel, optionally scoped to a platform."""
    url = f"{ANACONDA_API_ROOT}/{channel}/{package}"
    data = _get(url)

    if platform:
        platform_versions = data.get("platforms", {})
        version_str = platform_versions.get(platform)
        if version_str:
            version = _to_allowed_version(version_str, include_prerelease, max_major)
            if version is not None:
                return PackageInfo(version=version, version_str=version_str)
            logger.debug("Skipping Conda version %s for %s/%s on %s", version_str, channel, package, platform)

    latest = data.get("latest_version")
    if latest:
        version = _to_allowed_version(latest, include_prerelease, max_major)
        if version is not None:
            return PackageInfo(version=version, version_str=latest)

    valid_versions: list[tuple[Version, str]] = []
    for version_str in data.get("versions", []):
        version = _to_allowed_version(version_str, include_prerelease, max_major)
        if version is not None:
            valid_versions.append((version, version_str))

    if not valid_versions:
        return None

    valid_versions.sort(reverse=True)
    version, version_str = valid_versions[0]
    return PackageInfo(version=version, version_str=version_str)


def _to_allowed_version(
    version_str: str,
    include_prerelease: bool,
    max_major: Optional[int],
) -> Optional[Version]:
    try:
        version = Version(version_str)
    except InvalidVersion:
        logger.debug("Skipping invalid Conda version: %s", version_str)
        return None

    if not include_prerelease and version.is_prerelease:
        return None
    if max_major is not None and version.major > max_major:
        return None
    return version
