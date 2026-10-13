"""Verify unsigned source-built APKs against the actual Wolfi package manager."""

import hashlib
import importlib.util
import io
from pathlib import Path
import shutil
import subprocess
import tarfile
import tempfile
import unittest
import zlib


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    "package_apk", ROOT / "src/common/container-tools/package_apk.py"
)
PACKAGE_APK = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(PACKAGE_APK)


def members(path):
    """Retain gzip member boundaries; decompressing the whole APK hides them."""
    remaining = path.read_bytes()
    result = []
    while remaining:
        decoder = zlib.decompressobj(31)
        unpacked = decoder.decompress(remaining) + decoder.flush()
        consumed = len(remaining) - len(decoder.unused_data)
        result.append((remaining[:consumed], unpacked))
        remaining = decoder.unused_data
    return result


class SourceBuiltApkTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="ror-source-apk-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.payload = self.root / "payload"
        binary_dir = self.payload / "usr/bin"
        binary_dir.mkdir(parents=True)
        binary_dir.chmod(0o755)
        self.binary = binary_dir / "ror-apk-fixture"
        self.binary.write_text("#!/bin/sh\nprintf 'source-build-fixture\\n'\n")
        self.binary.chmod(0o755)
        (binary_dir / "ror-apk-fixture-link").symlink_to(self.binary.name)
        self.output = self.root / "ror-apk-fixture-1.0.0-r1000.apk"

    def package(self, **changes):
        arguments = dict(
            name="ror-apk-fixture", version="1.0.0-r1000", arch="x86_64",
            dependencies=["busybox"], payload=self.payload, output=self.output,
        )
        arguments.update(changes)
        PACKAGE_APK.create_apk(**arguments)

    def test_two_members_include_data_hash_and_per_file_checksums(self):
        self.package()
        streams = members(self.output)
        self.assertEqual(len(streams), 2, "unsigned APK must contain control and data streams")
        with tarfile.open(fileobj=io.BytesIO(streams[0][1])) as control:
            self.assertEqual(control.getnames(), [".PKGINFO"])
            metadata = control.extractfile(".PKGINFO").read().decode()
        self.assertIn("maintainer = Room of Requirement\n", metadata)
        self.assertIn("depend = busybox\n", metadata)
        self.assertIn("datahash = " + hashlib.sha256(streams[1][0]).hexdigest(), metadata)
        with tarfile.open(fileobj=io.BytesIO(streams[1][1])) as data:
            executable = data.getmember("usr/bin/ror-apk-fixture")
            link = data.getmember("usr/bin/ror-apk-fixture-link")
            self.assertEqual(executable.mode, 0o755)
            self.assertEqual(data.getmember("usr/bin").mode, 0o755)
            self.assertTrue(link.issym())
            self.assertEqual(link.linkname, self.binary.name)
            self.assertEqual(
                executable.pax_headers["APK-TOOLS.checksum.SHA1"],
                hashlib.sha1(self.binary.read_bytes()).hexdigest(),
            )
            self.assertEqual(
                link.pax_headers["APK-TOOLS.checksum.SHA1"],
                hashlib.sha1(link.linkname.encode()).hexdigest(),
            )

    def test_identical_payloads_produce_identical_packages(self):
        self.package()
        first = self.output.read_bytes()
        self.binary.touch()
        self.package(output=self.root / "second.apk")
        self.assertEqual(first, (self.root / "second.apk").read_bytes())

    def test_invalid_inputs_do_not_create_package(self):
        for changes in (
            {"payload": self.root / "absent"}, {"arch": "amd64"},
            {"version": "1.0.0-r2"}, {"dependencies": ["busybox\npkgname = spoof"]},
            {"provides": ["virtual-name\npkgname = spoof"]},
            {"output": self.payload / "nested.apk"},
        ):
            with self.subTest(changes=changes), self.assertRaises((ValueError, FileNotFoundError)):
                self.package(**changes)
        self.assertFalse(self.output.exists())

    @unittest.skipUnless(shutil.which("docker"), "Docker required for real apk-tools acceptance")
    def test_real_apk_tools_installs_metadata_mode_content_and_symlink(self):
        self.package(provides=[
            "ror-apk-alias=1.0.0-r1000", "cmd:ror-apk-fixture=1.0.0-r1000",
        ])
        script = """
set -eu
cat > /tmp/fixture.apk
apk add --no-network --allow-untrusted /tmp/fixture.apk
apk info -e ror-apk-fixture
apk info -v ror-apk-fixture
apk info -R ror-apk-fixture
apk add --no-network ror-apk-alias=1.0.0-r1000 cmd:ror-apk-fixture=1.0.0-r1000
test "$(stat -c %a /usr/bin/ror-apk-fixture)" = 755
test "$(stat -c %a /usr/bin)" = 755
test "$(readlink /usr/bin/ror-apk-fixture-link)" = ror-apk-fixture
test "$(/usr/bin/ror-apk-fixture-link)" = source-build-fixture
awk 'BEGIN { RS="" } /P:ror-apk-fixture\\n/ { print }' /lib/apk/db/installed
"""
        installed = subprocess.run(
            ["docker", "run", "--rm", "-i", "cgr.dev/chainguard/wolfi-base:latest",
             "/bin/sh", "-c", script],
            input=self.output.read_bytes(), capture_output=True, timeout=60,
        )
        self.assertEqual(installed.returncode, 0, installed.stderr.decode())
        output = installed.stdout.decode()
        self.assertIn("ror-apk-fixture-1.0.0-r1000", output)
        self.assertIn("V:1.0.0-r1000\n", output)
        self.assertIn("m:Room of Requirement\n", output)
        self.assertIn("D:busybox\n", output)
        self.assertIn("p:ror-apk-alias=1.0.0-r1000 cmd:ror-apk-fixture=1.0.0-r1000\n", output)


if __name__ == "__main__":
    unittest.main()
