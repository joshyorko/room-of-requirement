#!/usr/bin/env python3
"""Build toolchain floors and package/runtime evidence must fail closed."""

import base64
import hashlib
import importlib
from pathlib import Path
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / ".github/scripts"))


class ToolchainTests(unittest.TestCase):
    def test_node_floor_rejects_old_other_major_and_prerelease_versions(self):
        module = importlib.import_module("build_toolchain")
        for version in ("v24.22.1", "v24.22.2", "v24.23.0"):
            module.validate_node(version)
        for version in ("v24.22.0", "v24.9.0", "v22.22.1", "v26.12.1",
                        "v24.22.1-rc.1", "24.22.1", ""):
            with self.subTest(version=version), self.assertRaises(ValueError):
                module.validate_node(version)

    def test_cli_archive_requires_expected_identity_and_matching_hashes(self):
        module = importlib.import_module("build_toolchain")
        with tempfile.TemporaryDirectory() as temp:
            archive = Path(temp) / "cli.tgz"
            archive.write_bytes(b"downloaded package")
            metadata = dict(name="@devcontainers/cli", version="0.89.0",
                            integrity="sha512-" + base64.b64encode(
                                hashlib.sha512(archive.read_bytes()).digest()).decode(),
                            shasum=hashlib.sha1(archive.read_bytes()).hexdigest())
            self.assertEqual(module.verify_package(archive, metadata)["sha256"],
                             hashlib.sha256(b"downloaded package").hexdigest())
            for change in (dict(name="other"), dict(version="0.90.0"),
                           dict(integrity="sha512-invalid"), dict(shasum="0" * 40)):
                with self.subTest(change=change), self.assertRaises(ValueError):
                    module.verify_package(archive, metadata | change)
            archive.write_bytes(b"modified package")
            with self.assertRaises(ValueError):
                module.verify_package(archive, metadata)

    def test_sbom_inventory_keeps_node_packages_without_mistaking_npm_libraries(self):
        module = importlib.import_module("node_inventory")
        node = dict(name="nodejs", versionInfo="24.22.0", SPDXID="SPDXRef-node",
                    externalRefs=[dict(referenceType="purl", referenceLocator="pkg:generic/node@24.22.0")])
        sbom = dict(spdxVersion="SPDX-2.3", packages=[node, dict(name="bash", versionInfo="5.3"),
                    dict(name="node-gyp", versionInfo="11.0.0"), dict(name="node-fetch", versionInfo="3.3.2")])
        result = module.inventory(sbom)
        self.assertEqual(result["node_packages"], [node])
        self.assertEqual(module.inventory(dict(spdxVersion="SPDX-2.3", packages=[]))["node_packages"], [])
        for invalid in ({}, dict(packages=[]), dict(spdxVersion="SPDX-2.3", packages={})):
            with self.assertRaises(ValueError):
                module.inventory(invalid)


if __name__ == "__main__":
    unittest.main()
