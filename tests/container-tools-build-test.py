#!/usr/bin/env python3
"""Integrity checks for the container-tool source builder."""

import importlib.util
import io
import os
from pathlib import Path
import sys
import shutil
import subprocess
import tarfile
import tempfile
import unittest

HELPERS = Path(__file__).resolve().parents[1] / 'src/common/container-tools'
sys.path.insert(0, str(HELPERS))


class SourceBuildTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        specification = importlib.util.spec_from_file_location('container_build', HELPERS / 'build.py')
        cls.builder = importlib.util.module_from_spec(specification)
        specification.loader.exec_module(cls.builder)

    def archive(self, directory, name, link=None):
        path = directory / 'source.tar.gz'
        with tarfile.open(path, 'w:gz') as archive:
            member = tarfile.TarInfo(name)
            if link:
                member.type = tarfile.SYMTYPE
                member.linkname = link
                archive.addfile(member)
            else:
                member.size = 4
                archive.addfile(member, io.BytesIO(b'data'))
        return path

    def test_checksum_mismatch_prevents_extraction(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            archive = self.archive(root, 'release/go.mod')
            with self.assertRaisesRegex(ValueError, 'checksum'):
                self.builder.extract_source(archive, '0' * 64, root / 'out')
            self.assertFalse((root / 'out').exists())

    def test_archive_parent_traversal_is_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            archive = self.archive(root, 'release/../../escaped')
            with self.assertRaisesRegex(ValueError, 'unsafe'):
                self.builder.extract_source(archive, self.builder.sha256(archive), root / 'out')
            self.assertFalse((root / 'escaped').exists())

    def test_archive_symlink_escape_is_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            archive = self.archive(root, 'release/link', '../../escaped')
            with self.assertRaisesRegex(ValueError, 'unsafe'):
                self.builder.extract_source(archive, self.builder.sha256(archive), root / 'out')

    def test_extracts_single_source_root(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            archive = self.archive(root, 'release/go.mod')
            extracted = self.builder.extract_source(archive, self.builder.sha256(archive), root / 'out')
            self.assertEqual((extracted / 'go.mod').read_bytes(), b'data')

    def test_parses_real_go_build_metadata_and_replacements(self):
        metadata = '/out/bin/ctr: go1.27.2\n\tpath\tgithub.com/containerd/containerd/v2/cmd/ctr\n\tmod\tgithub.com/containerd/containerd/v2\t(devel)\t\n\tdep\tgolang.org/x/net\tv0.60.0\th1:abc=\n\tbuild\tCGO_ENABLED=0\n'
        self.builder.validate_go_metadata(metadata, static=True)
        with self.assertRaisesRegex(ValueError, 'x/net'):
            self.builder.validate_go_metadata(metadata.replace('v0.60.0', 'v0.59.0'), static=True)
        with self.assertRaisesRegex(ValueError, 'replacement'):
            self.builder.validate_go_metadata(metadata.replace('\tbuild\tCGO_ENABLED=0', '\t=>\t./patched\t(devel)\t\n\tbuild\tCGO_ENABLED=0'), static=True)

    def test_archive_absolute_path_is_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            archive = self.archive(root, '/tmp/escaped')
            with self.assertRaisesRegex(ValueError, 'unsafe'):
                self.builder.extract_source(archive, self.builder.sha256(archive), root / 'out')

    def test_podman_support_preserves_generators_and_rootless_units(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / 'source'
            units = source / 'contrib/systemd/system'
            units.mkdir(parents=True)
            (units / 'podman-clean-transient.service.in').write_text(
                'Requires=local-fs.target\nAfter=local-fs.target\n'
                'ExecStart=@@PODMAN@@ system reset\n')
            (units / 'podman.socket').write_text('[Socket]\nListenStream=%t/podman.sock\n')
            user = source / 'contrib/systemd/user'
            user.mkdir()
            (user / 'podman-user-wait-network-online.service').write_text('[Service]\n')
            tmpfiles = source / 'contrib/tmpfile'
            tmpfiles.mkdir()
            (tmpfiles / 'podman.conf').write_text('d /run/podman 0755 root root -\n')
            payload = root / 'payload'
            (payload / 'usr/bin').mkdir(parents=True)
            (payload / 'usr/bin/podman').write_bytes(b'podman')
            (payload / 'usr/libexec/podman').mkdir(parents=True)
            (payload / 'usr/libexec/podman/quadlet').write_bytes(b'quadlet')
            self.builder.stage_podman_support(source, payload)
            self.assertEqual((payload / 'usr/bin/podmansh').read_bytes(), b'podman')
            for kind, name in [('system', 'podman-system-generator'),
                               ('user', 'podman-user-generator')]:
                generator = payload / f'usr/lib/systemd/{kind}-generators' / name
                self.assertEqual(generator.read_bytes(), b'quadlet')
            rootless = (payload / 'usr/lib/systemd/user/podman-clean-transient.service').read_text()
            self.assertEqual(rootless, 'ExecStart=/usr/bin/podman system reset\n')
            system = (payload / 'usr/lib/systemd/system/podman-clean-transient.service').read_text()
            self.assertIn('Requires=local-fs.target', system)
            self.assertTrue((payload / 'usr/lib/tmpfiles.d/podman.conf').is_file())

    def test_parses_only_elf_needed_libraries(self):
        metadata = (
            'Dynamic section at offset 0x2d80 contains 29 entries:\n'
            ' 0x0000000000000001 (NEEDED) Shared library: [libgpgme.so.45]\n'
            ' 0x0000000000000001 (NEEDED) Shared library: [libsqlite3.so.0]\n'
            ' 0x000000000000001d (RUNPATH) Library runpath: [/unrelated]\n')
        self.assertEqual(self.builder.elf_dependencies(metadata),
                         {'so:libgpgme.so.45', 'so:libsqlite3.so.0'})
        self.assertEqual(self.builder.elf_dependencies(
            'There is no dynamic section in this file.\n'), set())

    @unittest.skipUnless(shutil.which('cc') and shutil.which('readelf'),
                         'ELF fixture compilation requires cc and readelf')
    def test_dependencies_from_real_dynamic_and_static_elf_fixtures(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            dynamic_source = root / 'dynamic.c'
            dynamic_source.write_text('#include <stdio.h>\nint main(void) { return puts("test") < 0; }\n')
            static_source = root / 'static.c'
            static_source.write_text('void _start(void) { for (;;) {} }\n')
            dynamic = root / 'dynamic'
            static = root / 'static'
            subprocess.run(['cc', dynamic_source, '-o', dynamic], check=True)
            subprocess.run(['cc', '-nostdlib', '-static', '-fno-stack-protector',
                            '-Wl,-e,_start', static_source, '-o', static], check=True)
            actual = self.builder.native_dependencies([dynamic, static], ['runtime-helper'],
                                                       dict(os.environ))
            self.assertEqual(actual, ['runtime-helper', 'so:libc.so.6'])

    def test_rejects_old_standard_library_and_wrong_cgo(self):
        with self.assertRaisesRegex(ValueError, 'go1.27.2'):
            self.builder.validate_go_metadata('/out/bin/ctr: go1.27.1\n\tbuild\tCGO_ENABLED=0\n', static=True)
        with self.assertRaisesRegex(ValueError, 'CGO_ENABLED'):
            self.builder.validate_go_metadata('/out/bin/podman: go1.27.2\n\tbuild\tCGO_ENABLED=0\n', static=False)


if __name__ == '__main__':
    unittest.main()
