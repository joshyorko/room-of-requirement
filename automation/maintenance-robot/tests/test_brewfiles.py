from __future__ import annotations

import json
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from maintenance_robot.brewfiles import BrewfileValidator


class BrewfileValidatorTests(unittest.TestCase):
    def test_validates_taps_with_tap_info_without_tapping(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            brew_dir = Path(tmpdir)
            (brew_dir / "cloud.Brewfile").write_text(
                '\n'.join(
                    [
                        'tap "hashicorp/tap"',
                        'brew "hashicorp/tap/terraform"',
                    ]
                )
                + "\n",
                encoding="utf-8",
            )

            calls: list[list[str]] = []

            def fake_run(args: list[str], **_kwargs: object) -> subprocess.CompletedProcess[str]:
                calls.append(args)
                if args == ["brew", "tap-info", "--json", "hashicorp/tap"]:
                    stdout = json.dumps(
                        [
                            {
                                "formula_names": ["hashicorp/tap/terraform"],
                                "cask_tokens": [],
                            }
                        ]
                    )
                    return subprocess.CompletedProcess(args, 0, stdout=stdout, stderr="")
                return subprocess.CompletedProcess(args, 0, stdout="{}", stderr="")

            validator = BrewfileValidator(brew_executable="brew", require_brew=True)

            with patch("maintenance_robot.brewfiles.subprocess.run", side_effect=fake_run):
                issues = validator.validate_directory(brew_dir)

            self.assertEqual([], issues)
            self.assertIn(["brew", "tap-info", "--json", "hashicorp/tap"], calls)
            self.assertNotIn(["brew", "tap", "hashicorp/tap"], calls)
            self.assertNotIn(["brew", "info", "--json=v2", "--formula", "hashicorp/tap/terraform"], calls)

    def test_accepts_tap_local_names_from_tap_info(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            brew_dir = Path(tmpdir)
            (brew_dir / "ror.Brewfile").write_text(
                "\n".join(
                    [
                        'tap "joshyorko/tools"',
                        'brew "joshyorko/tools/fizzy-symphony"',
                        'cask "joshyorko/tools/rcc"',
                    ]
                )
                + "\n",
                encoding="utf-8",
            )

            calls: list[list[str]] = []

            def fake_run(args: list[str], **_kwargs: object) -> subprocess.CompletedProcess[str]:
                calls.append(args)
                if args == ["brew", "tap-info", "--json", "joshyorko/tools"]:
                    stdout = json.dumps(
                        [
                            {
                                "formula_names": ["fizzy-symphony"],
                                "cask_tokens": ["rcc"],
                            }
                        ]
                    )
                    return subprocess.CompletedProcess(args, 0, stdout=stdout, stderr="")
                return subprocess.CompletedProcess(args, 1, stdout="", stderr="unexpected brew info call")

            validator = BrewfileValidator(brew_executable="brew", require_brew=True)

            with patch("maintenance_robot.brewfiles.subprocess.run", side_effect=fake_run):
                issues = validator.validate_directory(brew_dir)

            self.assertEqual([], issues)
            self.assertNotIn(["brew", "info", "--json=v2", "--formula", "joshyorko/tools/fizzy-symphony"], calls)
            self.assertNotIn(["brew", "info", "--json=v2", "--cask", "joshyorko/tools/rcc"], calls)

    def test_accepts_declared_tap_entries_when_tap_info_lacks_entries(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            brew_dir = Path(tmpdir)
            (brew_dir / "ror.Brewfile").write_text(
                "\n".join(
                    [
                        'tap "joshyorko/tools"',
                        'brew "joshyorko/tools/action-server"',
                        'cask "joshyorko/tools/rcc"',
                    ]
                )
                + "\n",
                encoding="utf-8",
            )

            calls: list[list[str]] = []

            def fake_run(args: list[str], **_kwargs: object) -> subprocess.CompletedProcess[str]:
                calls.append(args)
                if args == ["brew", "tap-info", "--json", "joshyorko/tools"]:
                    stdout = json.dumps(
                        [
                            {
                                "formula_names": [],
                                "cask_tokens": [],
                            }
                        ]
                    )
                    return subprocess.CompletedProcess(args, 0, stdout=stdout, stderr="")
                return subprocess.CompletedProcess(args, 1, stdout="", stderr="unexpected command")

            validator = BrewfileValidator(brew_executable="brew", require_brew=True)

            with patch("maintenance_robot.brewfiles.subprocess.run", side_effect=fake_run):
                issues = validator.validate_directory(brew_dir)

            self.assertEqual([], issues)
            self.assertNotIn(["brew", "info", "--json=v2", "--formula", "joshyorko/tools/action-server"], calls)
            self.assertNotIn(["brew", "info", "--json=v2", "--cask", "joshyorko/tools/rcc"], calls)

    def test_falls_back_to_brew_info_for_unqualified_entries(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            brew_dir = Path(tmpdir)
            (brew_dir / "cloud.Brewfile").write_text(
                "\n".join(
                    [
                        'tap "hashicorp/tap"',
                        'brew "terraform"',
                    ]
                )
                + "\n",
                encoding="utf-8",
            )

            calls: list[list[str]] = []

            def fake_run(args: list[str], **_kwargs: object) -> subprocess.CompletedProcess[str]:
                calls.append(args)
                if args == ["brew", "tap-info", "--json", "hashicorp/tap"]:
                    stdout = json.dumps(
                        [
                            {
                                "formula_names": [],
                                "cask_tokens": [],
                            }
                        ]
                    )
                    return subprocess.CompletedProcess(args, 0, stdout=stdout, stderr="")
                if args == ["brew", "info", "--json=v2", "--formula", "terraform"]:
                    return subprocess.CompletedProcess(args, 0, stdout="{}", stderr="")
                return subprocess.CompletedProcess(args, 1, stdout="", stderr="unexpected command")

            validator = BrewfileValidator(brew_executable="brew", require_brew=True)

            with patch("maintenance_robot.brewfiles.subprocess.run", side_effect=fake_run):
                issues = validator.validate_directory(brew_dir)

            self.assertEqual([], issues)
            self.assertIn(["brew", "info", "--json=v2", "--formula", "terraform"], calls)


if __name__ == "__main__":
    unittest.main()
