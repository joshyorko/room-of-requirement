#!/usr/bin/env python3
"""Check release workflow ordering and trigger boundaries."""

from pathlib import Path
import unittest

import yaml


ROOT = Path(__file__).resolve().parents[1]


class ReleaseWorkflowTests(unittest.TestCase):
    def workflow(self):
        return yaml.load(
            (ROOT / ".github/workflows/release.yml").read_text(),
            Loader=yaml.BaseLoader,
        )

    def test_release_pr_creation_waits_for_a_successful_main_image_build(self):
        workflow = self.workflow()
        triggers = workflow["on"]

        self.assertIn("workflow_run", triggers)
        self.assertEqual(
            triggers["workflow_run"]["workflows"], ["Build Devcontainers"]
        )
        self.assertEqual(triggers["workflow_run"]["types"], ["completed"])
        self.assertEqual(
            set(triggers["push"]["paths"]),
            {".release-please-manifest.json", "CHANGELOG.md"},
        )
        condition = workflow["jobs"]["release-please"]["if"]
        for fragment in (
            "github.event_name == 'workflow_run'",
            "github.event.workflow_run.conclusion == 'success'",
            "github.event.workflow_run.head_branch == 'main'",
            "github.event_name == 'push'",
            "github.event_name == 'workflow_dispatch'",
        ):
            self.assertIn(fragment, condition)


if __name__ == "__main__":
    unittest.main()
