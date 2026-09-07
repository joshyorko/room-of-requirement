#!/usr/bin/env python3
"""Execute the CI wrapper; require both canonical suites and strict ownership mode."""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class HomeSmokeTests(unittest.TestCase):
    def test_both_suites_are_required_and_failures_propagate(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / ".github/scripts").mkdir(parents=True)
            (root / "tests").mkdir()
            (root / "bin").mkdir()
            wrapper = root / ".github/scripts/home-smoke.sh"
            shutil.copyfile(ROOT / ".github/scripts/home-smoke.sh", wrapper)
            for name, source in {
                "id": '#!/bin/sh\nprintf "0\\n"\n',
                "sudo": ('#!/bin/sh\n'
                         '[ "${FAIL_SUDO:-0}" = 0 ] || exit "$FAIL_SUDO"\n'
                         '[ "$1" != -n ] || shift\n'
                         'if [ "$1" = -u ]; then\n'
                         '  test "$2" = vscode || exit 24\n'
                         '  export TEST_AS_VSCODE=1\n'
                         '  shift 2\n'
                         'fi\nexec "$@"\n'),
            }.items():
                path = root / "bin" / name
                path.write_text(source)
                path.chmod(0o755)
            (root / "tests/vscode-home-contract-test.sh").write_text(
                'test "${TEST_AS_VSCODE:-}" = 1 || exit 26\n'
                'echo portable >> "$CALLS"\nexit "${FAIL_PORTABLE:-0}"\n')
            (root / "tests/runtime-home-ownership-test.sh").write_text(
                'test "$ROR_REQUIRE_PRIVILEGED_OWNERSHIP_TEST" = 1 || exit 25\n'
                'echo ownership >> "$CALLS"\nexit "${FAIL_OWNERSHIP:-0}"\n')
            calls = root / "calls"
            env = dict(os.environ, PATH=str(root / "bin") + ":" + os.environ["PATH"], CALLS=str(calls))
            result = subprocess.run(["bash", str(wrapper)], env=env, capture_output=True, check=False)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(calls.read_text().splitlines(), ["portable", "ownership"])
            for failure in ("FAIL_PORTABLE", "FAIL_OWNERSHIP", "FAIL_SUDO"):
                calls.unlink(missing_ok=True)
                result = subprocess.run(["bash", str(wrapper)], env=env | {failure: "19"},
                                        capture_output=True, check=False)
                self.assertEqual(result.returncode, 19, result.stderr)
                if failure == "FAIL_PORTABLE":
                    self.assertEqual(calls.read_text().splitlines(), ["portable"])
                if failure == "FAIL_SUDO":
                    self.assertFalse(calls.exists())


if __name__ == "__main__":
    unittest.main()
