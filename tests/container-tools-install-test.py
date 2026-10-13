"""Exercise the source-built tool installer without changing host tools."""

import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
INSTALLER = ROOT / "src/common/container-tools/install.sh"
DESTINATIONS = {
    "docker-compose": "/usr/local/bin/docker-compose",
    "docker-buildx": "/usr/libexec/docker/cli-plugins/docker-buildx",
    "containerd": "/usr/bin/containerd",
    "ctr": "/usr/bin/ctr",
    "containerd-shim-runc-v2": "/usr/bin/containerd-shim-runc-v2",
}
PLUGIN_DIRS = (
    "/usr/local/lib/docker/cli-plugins",
    "/usr/local/libexec/docker/cli-plugins",
    "/usr/lib/docker/cli-plugins",
    "/usr/libexec/docker/cli-plugins",
)


class ContainerToolsInstallTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="ror-container-tools-")
        self.addCleanup(self.temporary.cleanup)
        self.fixture = Path(self.temporary.name)
        self.bundle = self.fixture / "bundle"
        self.root = self.fixture / "root"
        (self.bundle / "bin").mkdir(parents=True)
        (self.root / "etc").mkdir(parents=True)
        (self.root / "etc/os-release").write_text("ID=debian\n")
        self.manifest = {
            "go_version": "go1.27.2",
            "x_net_version": "v0.60.0",
            "artifacts": [],
        }
        for name, destination in DESTINATIONS.items():
            self.add_artifact(f"bin/{name}", f"patched {name}\n".encode(), destination)
        self.env = os.environ | {
            "ROR_CONTAINER_TOOLS_BUNDLE": str(self.bundle),
            "ROR_CONTAINER_TOOLS_ROOT": str(self.root),
        }

    def add_artifact(self, path, content, destination=None):
        artifact = self.bundle / path
        artifact.parent.mkdir(parents=True, exist_ok=True)
        artifact.write_bytes(content)
        entry = {"path": path, "sha256": hashlib.sha256(content).hexdigest()}
        if destination is not None:
            entry["destination"] = destination
        self.manifest["artifacts"].append(entry)

    def run_installer(self):
        (self.bundle / "manifest.json").write_text(json.dumps(self.manifest) + "\n")
        return subprocess.run(
            ["bash", str(INSTALLER)], env=self.env, text=True,
            capture_output=True, timeout=15,
        )

    def assert_no_install(self):
        self.assertFalse((self.root / "usr").exists())
        self.assertFalse((self.fixture / "apk-call").exists())

    def fake_apk(self, exit_code=0):
        commands = self.fixture / "commands"
        commands.mkdir()
        apk = commands / "apk"
        apk.write_text(
            '#!/usr/bin/env bash\nset -euo pipefail\n'
            'printf "%s\\n" "$@" > "$ROR_APK_CALL"\n'
            f"exit {exit_code}\n"
        )
        apk.chmod(0o755)
        self.env["PATH"] = f"{commands}:{self.env['PATH']}"
        self.env["ROR_APK_CALL"] = str(self.fixture / "apk-call")

    def add_apk(self):
        self.add_artifact("apk/buildah-1.45.2-r1000.apk", b"local APK fixture")

    def test_installs_patched_tools_and_restores_all_plugin_links(self):
        existing = self.root / "usr/local/bin/docker-compose"
        existing.parent.mkdir(parents=True)
        existing.write_text("vulnerable compose\n")
        for plugin_dir in PLUGIN_DIRS:
            directory = self.root / plugin_dir.lstrip("/")
            directory.mkdir(parents=True, exist_ok=True)
            (directory / "docker-compose").write_text("old plugin\n")
            (directory / "docker-buildx").write_text("old plugin\n")
        startup = self.root / "usr/local/share/docker-init.sh"
        startup.parent.mkdir(parents=True)
        startup.write_text("existing DinD startup\n")
        config = self.root / "etc/docker/daemon.json"
        config.parent.mkdir()
        config.write_text('{"existing":true}\n')
        result = self.run_installer()
        self.assertEqual(result.returncode, 0, result.stderr)
        for name, destination in DESTINATIONS.items():
            installed = self.root / destination.lstrip("/")
            self.assertEqual(installed.read_text(), f"patched {name}\n")
            self.assertEqual(installed.stat().st_mode & 0o777, 0o755)
        for name in ("docker-compose", "docker-buildx"):
            authoritative = self.root / DESTINATIONS[name].lstrip("/")
            for plugin_dir in PLUGIN_DIRS:
                link = self.root / plugin_dir.lstrip("/") / name
                if link != authoritative:
                    self.assertTrue(link.is_symlink())
                    self.assertEqual(link.resolve(), authoritative)
        provenance = self.root / "usr/share/ror/container-tools/manifest.json"
        self.assertEqual(provenance.read_bytes(), (self.bundle / "manifest.json").read_bytes())
        self.assertEqual(startup.read_text(), "existing DinD startup\n")
        self.assertEqual(config.read_text(), '{"existing":true}\n')
        self.assertTrue((self.bundle / "bin/docker-compose").exists())

    def test_checksum_failure_rejects_entire_bundle_before_writing(self):
        (self.bundle / "bin/ctr").write_text("tampered\n")
        result = self.run_installer()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("checksum", result.stderr.lower())
        self.assert_no_install()

    def test_feature_restores_tools_overwritten_by_docker_in_docker(self):
        shutil.copyfile(INSTALLER, self.bundle / "install.sh")
        result = self.run_installer()
        self.assertEqual(result.returncode, 0, result.stderr)
        compose = self.root / "usr/local/bin/docker-compose"
        compose.write_text("DinD bundled compose\n")
        buildx = self.root / "usr/libexec/docker/cli-plugins/docker-buildx"
        buildx.write_text("DinD bundled buildx\n")
        result = subprocess.run(
            ["bash", str(ROOT / ".devcontainer/features/container-tools/install.sh")],
            env=self.env, text=True, capture_output=True, timeout=15,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(compose.read_text(), "patched docker-compose\n")
        self.assertEqual(buildx.read_text(), "patched docker-buildx\n")

    def test_missing_manifest_rejects_before_writing(self):
        result = subprocess.run(
            ["bash", str(INSTALLER)], env=self.env, text=True,
            capture_output=True, timeout=15,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assert_no_install()

    def test_incomplete_tool_manifest_rejects_before_writing(self):
        self.manifest["artifacts"].pop()
        result = self.run_installer()
        self.assertNotEqual(result.returncode, 0)
        self.assert_no_install()

    def test_artifact_symlink_escape_rejects_before_writing(self):
        ctr = self.bundle / "bin/ctr"
        outside = self.fixture / "ctr"
        ctr.rename(outside)
        ctr.symlink_to(outside)
        result = self.run_installer()
        self.assertNotEqual(result.returncode, 0)
        self.assert_no_install()

    def test_missing_artifact_rejects_entire_bundle_before_writing(self):
        (self.bundle / "bin/ctr").unlink()
        result = self.run_installer()
        self.assertNotEqual(result.returncode, 0)
        self.assert_no_install()

    def test_malformed_manifest_rejects_before_writing(self):
        for value in ({}, {"artifacts": []}, {"artifacts": "incorrect"}):
            with self.subTest(manifest=value):
                self.manifest = value
                result = self.run_installer()
                self.assertNotEqual(result.returncode, 0)
                self.assert_no_install()

    def test_invalid_json_rejects_before_writing(self):
        (self.bundle / "manifest.json").write_text("not json\n")
        result = subprocess.run(
            ["bash", str(INSTALLER)], env=self.env, text=True,
            capture_output=True, timeout=15,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assert_no_install()

    def test_unsafe_artifact_path_rejects_before_writing(self):
        self.manifest["artifacts"][-1]["path"] = "../outside"
        result = self.run_installer()
        self.assertNotEqual(result.returncode, 0)
        self.assert_no_install()

    def test_invalid_destination_rejects_before_writing(self):
        self.manifest["artifacts"][-1]["destination"] = "/usr/bin/../../outside"
        result = self.run_installer()
        self.assertNotEqual(result.returncode, 0)
        self.assert_no_install()

    def test_wolfi_installs_verified_local_apks_without_network_or_repositories(self):
        (self.root / "etc/os-release").write_text('ID="wolfi"\n')
        self.add_apk()
        self.fake_apk()
        result = self.run_installer()
        self.assertEqual(result.returncode, 0, result.stderr)
        arguments = (self.fixture / "apk-call").read_text().splitlines()
        self.assertEqual(arguments, [
            "--root", str(self.root), "add", "--no-network",
            "--repositories-file", "/dev/null", "--allow-untrusted", "--upgrade",
            str(self.bundle / "apk/buildah-1.45.2-r1000.apk"),
        ])
        self.assertFalse((self.root / "etc/apk").exists())

    def test_apk_checksum_failure_prevents_apk_and_binary_install(self):
        (self.root / "etc/os-release").write_text("ID=wolfi\n")
        self.add_apk()
        self.fake_apk()
        (self.bundle / "apk/buildah-1.45.2-r1000.apk").write_text("tampered")
        result = self.run_installer()
        self.assertNotEqual(result.returncode, 0)
        self.assert_no_install()

    def test_apk_failure_propagates_before_binary_install(self):
        (self.root / "etc/os-release").write_text("ID=wolfi\n")
        self.add_apk()
        self.fake_apk(exit_code=42)
        result = self.run_installer()
        self.assertEqual(result.returncode, 42, result.stderr)
        self.assertFalse((self.root / "usr").exists())

    def test_debian_never_installs_apks(self):
        self.add_apk()
        self.fake_apk(exit_code=42)
        result = self.run_installer()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse((self.fixture / "apk-call").exists())


if __name__ == "__main__":
    unittest.main()
