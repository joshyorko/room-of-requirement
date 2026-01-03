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
    sha: Optional[str] = None  # Commit SHA for pinning


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
def _get(url: str, per_page: int = 100, max_pages: int = 3) -> list[dict]:
    """Fetch paginated results from GitHub API.

    Args:
        url: API endpoint URL
        per_page: Results per page (max 100)
        max_pages: Maximum number of pages to fetch

    Returns:
        Aggregated list of results from all pages
    """
    all_results = []
    page = 1

    while page <= max_pages:
        paginated_url = f"{url}{'&' if '?' in url else '?'}per_page={per_page}&page={page}"
        response = requests.get(paginated_url, headers=_headers(), timeout=30)
        if response.status_code >= 400:
            raise GitHubAPIError(f"GitHub API error {response.status_code}: {response.text}")
        try:
            data = response.json()
        except ValueError as exc:
            raise GitHubAPIError("Failed to decode JSON from GitHub API") from exc
        if not isinstance(data, list):
            raise GitHubAPIError("Expected list response from GitHub API")

        if not data:  # No more results
            break

        all_results.extend(data)
        page += 1

    return all_results


def _normalize_tag(tag: str, sha: Optional[str] = None) -> Optional[ReleaseInfo]:
    if not tag:
        return None
    normalized = tag.strip()
    if normalized.startswith("refs/tags/"):
        normalized = normalized[len("refs/tags/"):]
    try:
        version = Version(normalized.lstrip("v"))
        return ReleaseInfo(tag=normalized, version=version, sha=sha)
    except InvalidVersion:
        pass

    # DevContainer features use tag format: feature_<name>_<version>
    if normalized.startswith("feature_"):
        remainder = normalized[len("feature_"):]
        if "_" in remainder:
            _, _, version_part = remainder.rpartition("_")
            if version_part:
                try:
                    version = Version(version_part.lstrip("v"))
                    return ReleaseInfo(tag=normalized, version=version, sha=sha)
                except InvalidVersion:
                    logger.debug("Skipping invalid feature tag: %s", normalized)
                    return None

    # Sema4.ai action-server uses tag format: sema4ai-action_server-<version>
    if "sema4ai-action_server-" in normalized:
        _, _, version_part = normalized.rpartition("sema4ai-action_server-")
        if version_part:
            try:
                version = Version(version_part.lstrip("v"))
                return ReleaseInfo(tag=normalized, version=version, sha=sha)
            except InvalidVersion:
                logger.debug("Skipping invalid action-server tag: %s", normalized)
                return None

    logger.debug("Skipping invalid semantic version tag: %s", normalized)
    return None


def _get_tag_sha(repo: str, tag: str) -> Optional[str]:
    """Fetch the commit SHA for a specific tag.

    Args:
        repo: GitHub repository in format owner/repo
        tag: Tag name (e.g., 'v4.0.0')

    Returns:
        The full commit SHA if found, None otherwise
    """
    # First try refs/tags endpoint
    url = f"{GITHUB_API_ROOT}/repos/{repo}/git/refs/tags/{tag}"
    try:
        response = requests.get(url, headers=_headers(), timeout=30)
        if response.status_code == 200:
            data = response.json()
            obj = data.get("object", {})
            # If it's a tag object, we need to dereference it
            if obj.get("type") == "tag":
                # Annotated tag - need to fetch the tag object to get commit SHA
                tag_url = obj.get("url")
                if tag_url:
                    tag_response = requests.get(tag_url, headers=_headers(), timeout=30)
                    if tag_response.status_code == 200:
                        tag_data = tag_response.json()
                        commit_obj = tag_data.get("object", {})
                        return commit_obj.get("sha")
            elif obj.get("type") == "commit":
                # Lightweight tag - points directly to commit
                return obj.get("sha")
    except (requests.RequestException, ValueError) as exc:
        logger.debug("Failed to fetch tag SHA for %s@%s: %s", repo, tag, exc)

    return None


@lru_cache(maxsize=128)
def fetch_latest_version(
    repo: str,
    source: str,
    include_prerelease: bool = False,
    max_major: Optional[int] = None,
    feature_name: Optional[str] = None,
    pin_to_sha: bool = True,
) -> Optional[ReleaseInfo]:
    """Fetch the latest release/tag for a repository respecting constraints.

    Args:
        repo: GitHub repository in format owner/repo
        source: 'release' or 'tag'
        include_prerelease: Whether to include prereleases
        max_major: Maximum major version to consider
        feature_name: For devcontainers/features repo, filter by feature name (e.g., 'docker-in-docker')
        pin_to_sha: Whether to fetch the commit SHA for pinning (default True)
    """
    if source not in {"release", "tag"}:
        raise ValueError(f"Unsupported source type: {source}")

    url = f"{GITHUB_API_ROOT}/repos/{repo}/{'releases' if source == 'release' else 'tags'}"
    entries = _get(url)

    for entry in entries:
        tag_name = entry.get("tag_name") if source == "release" else entry.get("name")

        # For devcontainers/features, filter by feature name first
        if feature_name and repo == "devcontainers/features":
            if not tag_name or not tag_name.startswith(f"feature_{feature_name}_"):
                continue

        # Get SHA from the entry if available (tags endpoint includes commit info)
        sha = None
        if source == "tag":
            commit_info = entry.get("commit", {})
            sha = commit_info.get("sha")

        release_info = _normalize_tag(tag_name or "", sha=sha)
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

        # Fetch SHA if not available and pinning is enabled
        if pin_to_sha and release_info.sha is None:
            sha = _get_tag_sha(repo, release_info.tag)
            if sha:
                release_info = ReleaseInfo(
                    tag=release_info.tag,
                    version=release_info.version,
                    sha=sha,
                )

        return release_info

    return None
