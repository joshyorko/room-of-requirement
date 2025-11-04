from __future__ import annotations

import logging
import os
from dataclasses import dataclass
from functools import lru_cache
from typing import Optional

import requests
from packaging.version import InvalidVersion, Version
from tenacity import retry, retry_if_exception_type, stop_after_attempt, wait_exponential

logger = logging.getLogger(__name__)

GITHUB_API_ROOT = "https://api.github.com"


class GitHubAPIError(RuntimeError):
    """Raised when GitHub API responses cannot be parsed."""


@dataclass(frozen=True)
class ReleaseInfo:
    tag: str
    version: Version


def _headers() -> dict[str, str]:
    token = os.getenv("GITHUB_TOKEN") or os.getenv("GH_TOKEN")
    headers = {
        "Accept": "application/vnd.github+json",
        "User-Agent": "room-of-requirement-maintenance-robot",
    }
    if token:
        headers["Authorization"] = f"Bearer {token}"
    return headers


@retry(
    wait=wait_exponential(multiplier=1, min=1, max=8),
    stop=stop_after_attempt(4),
    retry=retry_if_exception_type((requests.RequestException, GitHubAPIError)),
)
def _get(url: str) -> list[dict]:
    response = requests.get(url, headers=_headers(), timeout=30)
    if response.status_code >= 400:
        raise GitHubAPIError(f"GitHub API error {response.status_code}: {response.text}")
    try:
        data = response.json()
    except ValueError as exc:
        raise GitHubAPIError("Failed to decode JSON from GitHub API") from exc
    if not isinstance(data, list):
        raise GitHubAPIError("Expected list response from GitHub API")
    return data


def _normalize_tag(tag: str) -> Optional[ReleaseInfo]:
    if not tag:
        return None
    normalized = tag.strip()
    if normalized.startswith("refs/tags/"):
        normalized = normalized[len("refs/tags/"):]
    try:
        version = Version(normalized.lstrip("v"))
    except InvalidVersion:
        logger.debug("Skipping invalid semantic version tag: %s", normalized)
        return None
    return ReleaseInfo(tag=normalized, version=version)


@lru_cache(maxsize=128)
def fetch_latest_version(
    repo: str,
    source: str,
    include_prerelease: bool = False,
    max_major: Optional[int] = None,
) -> Optional[ReleaseInfo]:
    """Fetch the latest release/tag for a repository respecting constraints."""
    if source not in {"release", "tag"}:
        raise ValueError(f"Unsupported source type: {source}")

    url = f"{GITHUB_API_ROOT}/repos/{repo}/{'releases' if source == 'release' else 'tags'}"
    entries = _get(url)

    for entry in entries:
        tag_name = entry.get("tag_name") if source == "release" else entry.get("name")
        release_info = _normalize_tag(tag_name or "")
        if release_info is None:
            continue

        if max_major is not None and release_info.version.major > max_major:
            logger.debug(
                "Skipping %s release %s due to max_major=%s",
                repo,
                release_info.tag,
                max_major,
            )
            continue

        if not include_prerelease and source == "release":
            if entry.get("prerelease") or entry.get("draft"):
                logger.debug("Skipping pre-release/draft: %s %s", repo, release_info.tag)
                continue
        return release_info

    return None
