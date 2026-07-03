from __future__ import annotations

import json
import logging
import os
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


@dataclass(frozen=True)
class TapEntries:
    formulae: frozenset[str]
    casks: frozenset[str]

    @classmethod
    def from_tap_info(cls, tap_info: dict[str, object]) -> "TapEntries":
        return cls(
            formulae=frozenset(str(name) for name in tap_info.get("formula_names", [])),
            casks=frozenset(str(name) for name in tap_info.get("cask_tokens", [])),
        )


class BrewfileValidator:
    """Validate curated Brewfiles without installing their full contents."""

    def __init__(self, brew_executable: str | None = None, require_brew: bool | None = None) -> None:
        self.brew_executable = brew_executable or shutil.which("brew")
        self.require_brew = require_brew if require_brew is not None else _env_flag("CI") or _env_flag(
            "REQUIRE_BREWFILE_VALIDATION"
        )

    def validate_directory(self, brew_dir: Path) -> List[BrewfileValidationIssue]:
        """Validate all Brewfiles in a directory.

        Validation intentionally mirrors brew bundle resolution closely enough to
        catch missing taps or renamed formulae before image builds or
        on-demand installs hit them.
        """
        if not self.brew_executable:
            detail = "brew not found in PATH; cannot validate curated Brewfiles"
            if self.require_brew:
                logger.error(detail)
                return [
                    BrewfileValidationIssue(
                        brewfile=brew_dir,
                        entry_type="tool",
                        name="brew",
                        detail=detail,
                    )
                ]

            logger.warning("%s; skipping validation outside CI", detail)
            return []

        brewfiles = sorted(brew_dir.glob("*.Brewfile"))
        if not brewfiles:
            logger.info("No Brewfiles found in %s", brew_dir)
            return []

        issues: List[BrewfileValidationIssue] = []

        for brewfile in brewfiles:
            taps, formulae, casks = self._parse_brewfile(brewfile)
            tap_entries: dict[str, TapEntries] = {}
            logger.info(
                "Validating %s (%d taps, %d formulae, %d casks)",
                brewfile.name,
                len(taps),
                len(formulae),
                len(casks),
            )

            for tap in taps:
                issue, entries = self._load_tap_entries(brewfile, tap)
                if issue:
                    issues.append(issue)
                elif entries:
                    tap_entries[tap] = entries

            for formula in formulae:
                if self._tap_entries_include(tap_entries, "formula", formula):
                    continue

                issue = self._run_check(
                    brewfile,
                    "formula",
                    formula,
                    ["info", "--json=v2", "--formula", formula],
                )
                if issue:
                    issues.append(issue)

            for cask in casks:
                if self._tap_entries_include(tap_entries, "cask", cask):
                    continue

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

    def _load_tap_entries(
        self,
        brewfile: Path,
        tap: str,
    ) -> tuple[BrewfileValidationIssue | None, TapEntries | None]:
        assert self.brew_executable is not None

        result = subprocess.run(
            [self.brew_executable, "tap-info", "--json", tap],
            capture_output=True,
            text=True,
            cwd=str(brewfile.parent),
        )

        if result.returncode != 0:
            detail = result.stderr.strip() or result.stdout.strip() or "tap validation failed"
            detail = detail.splitlines()[-1]
            logger.error("Brewfile validation failed for tap %s in %s: %s", tap, brewfile.name, detail)
            return (
                BrewfileValidationIssue(
                    brewfile=brewfile,
                    entry_type="tap",
                    name=tap,
                    detail=detail,
                ),
                None,
            )

        try:
            tap_info = json.loads(result.stdout)
        except json.JSONDecodeError as error:
            detail = f"tap-info returned invalid JSON: {error}"
            logger.error("Brewfile validation failed for tap %s in %s: %s", tap, brewfile.name, detail)
            return (
                BrewfileValidationIssue(
                    brewfile=brewfile,
                    entry_type="tap",
                    name=tap,
                    detail=detail,
                ),
                None,
            )

        if not tap_info:
            detail = "tap-info returned no tap metadata"
            logger.error("Brewfile validation failed for tap %s in %s: %s", tap, brewfile.name, detail)
            return (
                BrewfileValidationIssue(
                    brewfile=brewfile,
                    entry_type="tap",
                    name=tap,
                    detail=detail,
                ),
                None,
            )

        return None, TapEntries.from_tap_info(tap_info[0])

    def _tap_entries_include(
        self,
        tap_entries: dict[str, TapEntries],
        entry_type: str,
        name: str,
    ) -> bool:
        tap = _tap_name_from_entry(name)
        if tap not in tap_entries:
            return False

        entries = tap_entries[tap]
        names = entries.formulae if entry_type == "formula" else entries.casks
        if _entry_name_variants(name) & names:
            return True

        # Untapped Homebrew metadata can omit entry lists even when the tap exists.
        return not names

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


def _env_flag(name: str) -> bool:
    return os.getenv(name, "").lower() in {"1", "true", "yes", "on"}


def _tap_name_from_entry(name: str) -> str | None:
    parts = name.split("/")
    if len(parts) < 3:
        return None
    return "/".join(parts[:2])


def _entry_name_variants(name: str) -> set[str]:
    return {name, name.rsplit("/", 1)[-1]}
