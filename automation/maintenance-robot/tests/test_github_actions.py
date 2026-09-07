from __future__ import annotations

import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from packaging.version import Version

from maintenance_robot.github_actions import GitHubActionsUpdater
from maintenance_robot.github_api import ReleaseInfo
from maintenance_robot.reporter import MaintenanceReport


class GitHubActionsUpdaterTests(unittest.TestCase):
    def test_updates_sha_pinned_action_from_ruamel_eol_version_comment(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            workflow = Path(tmpdir) / "workflow.yml"
            old_sha = "a" * 40
            new_sha = "b" * 40
            workflow.write_text(
                f"steps:\n  - uses: actions/checkout@{old_sha} # v6.0.0\n",
                encoding="utf-8",
            )
            updater = GitHubActionsUpdater(
                {"actions/checkout": {"repo": "actions/checkout"}},
                MaintenanceReport(),
            )

            with patch.object(
                updater,
                "_get_release",
                return_value=ReleaseInfo("v7.0.1", Version("7.0.1"), new_sha),
            ):
                self.assertTrue(updater._update_workflow(workflow))

            content = workflow.read_text(encoding="utf-8")
            self.assertRegex(content, rf"actions/checkout@{new_sha}\s+# v7\.0\.1")

    def test_keeps_sha_pin_without_a_trustworthy_version_comment(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            workflow = Path(tmpdir) / "workflow.yml"
            old_sha = "a" * 40
            workflow.write_text(
                f"steps:\n  - uses: actions/checkout@{old_sha}\n",
                encoding="utf-8",
            )
            updater = GitHubActionsUpdater(
                {"actions/checkout": {"repo": "actions/checkout"}},
                MaintenanceReport(),
            )

            with patch.object(
                updater,
                "_get_release",
                return_value=ReleaseInfo("v7.0.1", Version("7.0.1"), "b" * 40),
            ):
                self.assertFalse(updater._update_workflow(workflow))

            self.assertIn(old_sha, workflow.read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
