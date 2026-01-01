from __future__ import annotations

import logging
import requests
from typing import Dict, Optional

from .reporter import MaintenanceReport

logger = logging.getLogger(__name__)


class HomebrewUpdater:
    """Updates Homebrew formula and cask versions by querying the Homebrew API."""

    def __init__(self, allowlist: Dict[str, dict], report: MaintenanceReport) -> None:
        self.allowlist = allowlist
        self.report = report
        self._version_cache: Dict[str, Optional[str]] = {}

    def update_formulas(self) -> Dict[str, Optional[str]]:
        """
        Query Homebrew API for all formulas/casks in the allowlist and return their versions.

        Returns:
            Dictionary mapping formula/cask names to their stable versions.
        """
        logger.info("Querying Homebrew API for %d formula(s)/cask(s)", len(self.allowlist))

        results: Dict[str, Optional[str]] = {}

        for identifier, config in self.allowlist.items():
            formula = config.get("formula")
            pkg_type = config.get("type", "formula")
            description = config.get("description", "")
            skip_check = config.get("skip_version_check", False)

            if not formula:
                logger.warning("Missing formula name for %s in allowlist", identifier)
                results[identifier] = None
                continue

            if skip_check:
                logger.info("Skipping %s: %s (skip_version_check=true)", pkg_type, formula)
                results[identifier] = None
                continue

            logger.info("Checking %s: %s (%s)", pkg_type, formula, description)
            version = self._fetch_version(formula, pkg_type)

            if version:
                logger.info("  Found version: %s", version)
                results[identifier] = version
            else:
                logger.warning("  No version found for %s: %s", pkg_type, formula)
                results[identifier] = None

        return results

    def _fetch_version(self, name: str, pkg_type: str = "formula") -> Optional[str]:
        """
        Fetch the stable version of a Homebrew formula or cask from the API.

        Args:
            name: The name of the Homebrew formula/cask (e.g., "kubernetes-cli", "claude-code")
            pkg_type: Either "formula" or "cask"

        Returns:
            The stable version string, or None if not found or on error.
        """
        cache_key = f"{pkg_type}:{name}"
        if cache_key in self._version_cache:
            return self._version_cache[cache_key]

        url = f"https://formulae.brew.sh/api/{pkg_type}/{name}.json"

        try:
            logger.debug("Fetching: %s", url)
            response = requests.get(url, timeout=30)
            response.raise_for_status()

            data = response.json()

            if pkg_type == "cask":
                version = data.get("version")
            else:
                version = data.get("versions", {}).get("stable")

            if version:
                self._version_cache[cache_key] = version
                return version
            else:
                logger.warning("No stable version found in API response for %s", name)
                self._version_cache[cache_key] = None
                return None

        except requests.RequestException as e:
            logger.error("Failed to fetch Homebrew %s %s: %s", pkg_type, name, e)
            self._version_cache[cache_key] = None
            return None
        except (KeyError, ValueError) as e:
            logger.error("Failed to parse Homebrew API response for %s: %s", name, e)
            self._version_cache[cache_key] = None
            return None
