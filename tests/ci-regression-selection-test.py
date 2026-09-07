"""Run the workflow's regression step against failing suite sentinels."""

import fnmatch
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

import yaml

ROOT = Path(__file__).resolve().parents[1]
IMAGE_SUITES = {"runtime-home-ownership-test.sh", "vscode-home-contract-test.sh",
                "runtime-native-smoke.sh", "runtime-docker-image-smoke.sh"}


class RegressionSelectionTests(unittest.TestCase):
    def test_missing_just_is_reported_before_running_suites(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / ".github/scripts").mkdir(parents=True)
            (root / "tests").mkdir()
            binary_dir = root / "bin"
            binary_dir.mkdir()
            script = root / ".github/scripts/regressions.sh"
            shutil.copyfile(ROOT / ".github/scripts/regressions.sh", script)
            (root / "tests/ci-sentinel-test.py").write_text("raise SystemExit(37)\n")
            for name, target in (("python3", sys.executable), ("bash", "/bin/bash"),
                                 ("dirname", shutil.which("dirname"))):
                (binary_dir / name).symlink_to(target)
            for name in ("mise", "jq", "git", "sudo", "devcontainer", "cosign"):
                tool = binary_dir / name
                tool.write_text("#!/bin/sh\nexit 0\n")
                tool.chmod(0o755)
            result = subprocess.run(["/bin/bash", str(script)],
                                    env=dict(os.environ, PATH=str(binary_dir)),
                                    capture_output=True, text=True)
            self.assertEqual(result.returncode, 1, result.stderr)
            self.assertIn("Required regression tool missing: just", result.stderr)

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
