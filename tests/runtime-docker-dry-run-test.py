"""Diagnostics must validate configuration without touching live daemon state."""

import json
import os
from pathlib import Path
import shlex
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class DryRunTests(unittest.TestCase):
    def test_existing_and_absent_effective_config_are_untouched(self):
        for existing in (True, False):
            for option in ("flag", "environment"):
                with self.subTest(existing=existing, option=option), tempfile.TemporaryDirectory() as temp:
                    root = Path(temp)
                    bindir = root / "bin"
                    bindir.mkdir()
                    (bindir / "id").write_text("#!/bin/sh\necho 0\n")
                    (bindir / "id").chmod(0o755)
                    source = root / 'source "quoted".json'
                    target = root / 'live "quoted"/effective.json'
                    data = root / 'data "quoted"'
                    source.write_text(json.dumps({"data-root": str(data), "debug": True}))
                    marker = b'{"live-marker": "preserve me"}\n'
                    if existing:
                        target.parent.mkdir()
                        target.write_bytes(marker)
                        target.chmod(0o600)
                    before = target.stat() if existing else None
                    env = dict(os.environ, PATH=str(bindir) + ":" + os.environ["PATH"],
                               ROR_DOCKER_DAEMON_CONFIG=str(source),
                               ROR_DOCKER_EFFECTIVE_CONFIG=str(target),
                               ROR_DOCKER_TEST_DATA_ROOT_FSTYPE="ext4",
                               ROR_DOCKER_TEST_HAS_DOCKERD_ENTRYPOINT="0",
                               ROR_DOCKER_TEST_DOCKERD_BIN="/bin/true",
                               ROR_DOCKER_STORAGE_DRIVER="vfs",
                               ROR_DOCKER_START_DRY_RUN="1" if option == "environment" else "")
                    command = ["bash", str(ROOT / "src/common/scripts/ror-docker-start.sh")]
                    if option == "flag":
                        command.append("--dry-run")
                    result = subprocess.run(command, env=env, capture_output=True, text=True)
                    self.assertEqual(result.returncode, 0, result.stderr)
                    if existing:
                        self.assertEqual(target.read_bytes(), marker)
                        self.assertEqual(target.stat().st_mode, before.st_mode)
                        self.assertEqual(target.stat().st_ino, before.st_ino)
                    else:
                        self.assertFalse(target.parent.exists())
                    self.assertFalse(data.exists())
                    lines = result.stdout.splitlines()
                    config = json.loads(lines[0].removeprefix("# effective config: "))
                    self.assertEqual(config["data-root"], str(data))
                    self.assertTrue(config["debug"])
                    self.assertEqual(config["storage-driver"], "vfs")
                    self.assertIn("--config-file=" + str(target), shlex.split(lines[1]))


if __name__ == "__main__":
    unittest.main()
