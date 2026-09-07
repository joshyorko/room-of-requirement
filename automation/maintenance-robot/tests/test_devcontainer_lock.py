from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from maintenance_robot import devcontainer_lock
from maintenance_robot.reporter import MaintenanceReport


class DevcontainerLockTests(unittest.TestCase):
    def test_enumerates_every_feature_config_and_excludes_featureless_configs(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            expected = {
                root / ".devcontainer" / "devcontainer.json",
                root / "src" / "debian-trixie" / ".devcontainer" / "devcontainer.json",
                root / "src" / "ubuntu-noble" / ".devcontainer" / "devcontainer.json",
                root / "templates" / "ror-starter" / ".devcontainer" / "devcontainer.json",
            }
            for path in expected:
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(json.dumps({"features": {"example/feature:1": {}}}), encoding="utf-8")
            wolfi = root / "src" / "wolfi" / ".devcontainer" / "devcontainer.json"
            wolfi.parent.mkdir(parents=True)
            wolfi.write_text(json.dumps({"features": {}}), encoding="utf-8")

            self.assertEqual(expected, set(devcontainer_lock.feature_config_paths(root)))

    def test_passes_each_feature_config_to_devcontainer_upgrade(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            config = root / "src" / "ubuntu-noble" / ".devcontainer" / "devcontainer.json"
            config.parent.mkdir(parents=True)
            config.write_text(json.dumps({"features": {"example/feature:1": {}}}), encoding="utf-8")
            commands: list[list[str]] = []

            def fake_run(command: list[str], **_kwargs: object) -> None:
                commands.append(command)
                (config.parent / "devcontainer-lock.json").write_text(
                    json.dumps({"features": {"example/feature:1": {"version": "1.0.0"}}}),
                    encoding="utf-8",
                )

            with patch.object(devcontainer_lock.shutil, "which", return_value="devcontainer"), patch.object(
                devcontainer_lock, "feature_config_paths", return_value=[config]
            ), patch.object(devcontainer_lock.subprocess, "run", side_effect=fake_run):
                devcontainer_lock.update_devcontainer_lockfile(root, MaintenanceReport())

            self.assertEqual(
                [
                    "devcontainer",
                    "upgrade",
                    "--workspace-folder",
                    str(root),
                    "--config",
                    str(config),
                    "--log-level",
                    "info",
                ],
                commands[0],
            )


if __name__ == "__main__":
    unittest.main()
