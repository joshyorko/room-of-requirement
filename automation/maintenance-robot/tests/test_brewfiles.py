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


if __name__ == "__main__":
    unittest.main()
