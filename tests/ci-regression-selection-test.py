"""Run the workflow's regression step against failing suite sentinels."""

import fnmatch
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

import yaml

ROOT = Path(__file__).resolve().parents[1]
IMAGE_SUITES = {"runtime-home-ownership-test.sh", "vscode-home-contract-test.sh",
                "runtime-native-smoke.sh", "runtime-docker-image-smoke.sh"}


class RegressionSelectionTests(unittest.TestCase):
    def test_every_host_suite_executes_and_failure_stops_the_gate(self):
        workflow = yaml.safe_load((ROOT / ".github/workflows/build-image.yml").read_text())
        step = next(step for step in workflow["jobs"]["lint"]["steps"]
                    if step.get("name") == "CI policy and execution regressions")
        suites = sorted(p.name for p in (ROOT / "tests").iterdir()
                        if p.suffix in (".py", ".sh") and p.name not in IMAGE_SUITES)
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            shutil.copytree(ROOT / ".github/scripts", root / ".github/scripts")
            (root / "tests").mkdir()
            for suite in suites:
                content = ("import sys; sys.exit(37)\n" if suite.endswith(".py") else "exit 37\n")
                (root / "tests" / suite).write_text(content)
            # Select each independently; a omitted suite leaves the gate green.
            for suite in suites:
                for candidate in suites:
                    path = root / "tests" / candidate
                    path.write_text(("import sys; sys.exit(37)\n" if candidate.endswith(".py") else "exit 37\n")
                                    if candidate == suite else "\n")
                with self.subTest(suite=suite):
                    result = subprocess.run(["bash", "-e", "-o", "pipefail", "-c", step["run"]],
                                            cwd=root, env=os.environ, capture_output=True, text=True)
                    self.assertEqual(result.returncode, 37, result.stderr)

    def test_runtime_only_changes_trigger_pull_request_and_push(self):
        workflow = yaml.load((ROOT / ".github/workflows/build-devcontainers.yml").read_text(),
                             Loader=yaml.BaseLoader)
        for event in ("pull_request", "push"):
            for suite in (ROOT / "tests").iterdir():
                if suite.is_file():
                    with self.subTest(event=event, suite=suite.name):
                        self.assertTrue(any(fnmatch.fnmatch("tests/" + suite.name, pattern)
                                            for pattern in workflow["on"][event]["paths"]))


if __name__ == "__main__":
    unittest.main()
