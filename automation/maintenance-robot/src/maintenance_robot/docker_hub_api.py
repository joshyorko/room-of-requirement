from __future__ import annotations

import logging
import re
from dataclasses import dataclass
from typing import Optional

import requests
from packaging.version import InvalidVersion, Version
from tenacity import retry, retry_if_exception_type, stop_after_attempt, wait_exponential

logger = logging.getLogger(__name__)

DOCKER_HUB_API_ROOT = "https://hub.docker.com/v2/repositories"


class DockerHubAPIError(RuntimeError):
    """Raised when Docker Hub API responses cannot be parsed."""


@dataclass(frozen=True)
class DockerHubTagInfo:
    tag: str
    version: Version
    digest: Optional[str] = None


def _normalize_digest(digest: Optional[str]) -> Optional[str]:
    if not digest:
        return None
    return digest.removeprefix("sha256:")


@retry(
    wait=wait_exponential(multiplier=1, min=1, max=8),
    stop=stop_after_attempt(4),
    retry=retry_if_exception_type((requests.RequestException, DockerHubAPIError)),
)
def fetch_latest_version(
    repo: str,
    tag_regex: str,
    include_prerelease: bool = False,
    max_major: Optional[int] = None,
    page_size: int = 100,
    max_pages: int = 5,
) -> Optional[DockerHubTagInfo]:
    """Fetch the highest-version Docker Hub tag matching the configured regex."""

    pattern = re.compile(tag_regex)
    candidates: list[DockerHubTagInfo] = []

    for page in range(1, max_pages + 1):
        url = f"{DOCKER_HUB_API_ROOT}/{repo}/tags?page_size={page_size}&page={page}"
        response = requests.get(url, timeout=30)
        if response.status_code >= 400:
            raise DockerHubAPIError(
                f"Docker Hub API error {response.status_code}: {response.text}"
            )
        try:
            payload = response.json()
        except ValueError as exc:
            raise DockerHubAPIError("Failed to decode JSON from Docker Hub API") from exc

        results = payload.get("results")
        if not isinstance(results, list):
            raise DockerHubAPIError("Expected list response from Docker Hub API")
        if not results:
            break

        for entry in results:
            tag_name = entry.get("name", "")
            match = pattern.fullmatch(tag_name)
            if match is None:
                continue

            version_raw = match.groupdict().get("version", "")
            if not version_raw:
                logger.debug("Skipping Docker Hub tag without version group: %s", tag_name)
                continue

            try:
                version = Version(version_raw.lstrip("vV"))
            except InvalidVersion:
                logger.debug("Skipping invalid Docker Hub tag version: %s", tag_name)
                continue

            if version.is_prerelease and not include_prerelease:
                continue
            if max_major is not None and version.major > max_major:
                continue

            digest = _normalize_digest(entry.get("digest"))
            candidates.append(DockerHubTagInfo(tag=tag_name, version=version, digest=digest))

        if not payload.get("next"):
            break

    if not candidates:
        return None

    return max(candidates, key=lambda candidate: candidate.version)
