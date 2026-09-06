from __future__ import annotations

import unittest
from pathlib import Path
from unittest.mock import patch

from maintenance_robot import tasks


class MaintenanceTaskTests(unittest.TestCase):
    def test_validates_the_canonical_brewfile_directory(self) -> None:
        canonical = tasks.REPO_ROOT / "src" / "common" / "brew"
        with patch.object(tasks, "BrewfileValidator") as validator_type:
            validator_type.return_value.validate_directory.return_value = []
            self.assertEqual([], tasks._validate_curated_brewfiles())

        validator_type.return_value.validate_directory.assert_called_once_with(canonical)

    def test_unit_tests_runs_unittest_within_the_robot_root(self) -> None:
        with patch.object(tasks.subprocess, "run") as run:
            tasks.unit_tests()

        self.assertEqual(
            [
                tasks.sys.executable,
                "-B",
                "-m",
                "unittest",
                "discover",
                "-s",
                "tests",
                "-v",
            ],
            run.call_args.args[0],
        )
        self.assertEqual(str(tasks.ROBOT_ROOT), run.call_args.kwargs["cwd"])
        self.assertTrue(run.call_args.kwargs["check"])


if __name__ == "__main__":
    unittest.main()
