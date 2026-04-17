from __future__ import annotations

import logging
import re
import shutil
import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import List

logger = logging.getLogger(__name__)

_TAP_RE = re.compile(r'^\s*tap\s+"([^"]+)"')
_BREW_RE = re.compile(r'^\s*brew\s+"([^"]+)"')
_CASK_RE = re.compile(r'^\s*cask\s+"([^"]+)"')


@dataclass(frozen=True)
class BrewfileValidationIssue:
    brewfile: Path
    entry_type: str
    name: str
    detail: str


class BrewfileValidator:
    """Validate curated Brewfiles without installing their full contents."""

    def __init__(self, brew_executable: str | None = None) -> None:
        self.brew_executable = brew_executable or shutil.which("brew")

    def validate_directory(self, brew_dir: Path) -> List[BrewfileValidationIssue]:
        """Validate all Brewfiles in a directory.

        Validation intentionally mirrors brew bundle resolution closely enough to
        catch missing taps or renamed formulae before post-create hydration hits
        them.
        """
        if not self.brew_executable:
            logger.warning("brew not found in PATH; skipping curated Brewfile validation")
            return []

        brewfiles = sorted(brew_dir.glob("*.Brewfile"))
        if not brewfiles:
            logger.info("No Brewfiles found in %s", brew_dir)
            return []

        issues: List[BrewfileValidationIssue] = []

        for brewfile in brewfiles:
            taps, formulae, casks = self._parse_brewfile(brewfile)
            logger.info(
                "Validating %s (%d taps, %d formulae, %d casks)",
                brewfile.name,
                len(taps),
                len(formulae),
                len(casks),
            )

            for tap in taps:
                issue = self._run_check(brewfile, "tap", tap, ["tap", tap])
                if issue:
                    issues.append(issue)

            for formula in formulae:
                issue = self._run_check(
                    brewfile,
                    "formula",
                    formula,
                    ["info", "--json=v2", "--formula", formula],
                )
                if issue:
                    issues.append(issue)

            for cask in casks:
                issue = self._run_check(
                    brewfile,
                    "cask",
                    cask,
                    ["info", "--json=v2", "--cask", cask],
                )
                if issue:
                    issues.append(issue)

        return issues

    def _parse_brewfile(self, brewfile: Path) -> tuple[list[str], list[str], list[str]]:
        taps: list[str] = []
        formulae: list[str] = []
        casks: list[str] = []

        for raw_line in brewfile.read_text(encoding="utf-8").splitlines():
            line = raw_line.split("#", 1)[0].strip()
            if not line:
                continue

            tap_match = _TAP_RE.match(line)
            if tap_match:
                taps.append(tap_match.group(1))
                continue

            brew_match = _BREW_RE.match(line)
            if brew_match:
                formulae.append(brew_match.group(1))
                continue

            cask_match = _CASK_RE.match(line)
            if cask_match:
                casks.append(cask_match.group(1))

        return taps, formulae, casks

    def _run_check(
        self,
        brewfile: Path,
        entry_type: str,
        name: str,
        brew_args: list[str],
    ) -> BrewfileValidationIssue | None:
        assert self.brew_executable is not None

        result = subprocess.run(
            [self.brew_executable, *brew_args],
            capture_output=True,
            text=True,
            cwd=str(brewfile.parent),
        )

        if result.returncode == 0:
            return None

        detail = result.stderr.strip() or result.stdout.strip() or f"{entry_type} validation failed"
        detail = detail.splitlines()[-1]
        logger.error("Brewfile validation failed for %s %s in %s: %s", entry_type, name, brewfile.name, detail)
        return BrewfileValidationIssue(
            brewfile=brewfile,
            entry_type=entry_type,
            name=name,
            detail=detail,
        )
