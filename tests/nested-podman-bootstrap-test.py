#!/usr/bin/env python3
"""Refuse unsafe bootstrap boundaries before any mutation; runtime uses a real pod."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / 'src/common/scripts/ror-nested-podman-bootstrap.sh'


class BootstrapSafety(unittest.TestCase):
    def test_unsafe_launches_never_mutate(self):
        self.assertTrue(SCRIPT.is_file(), 'nested Podman bootstrap is missing')
        cases = (
            ('nonroot', 'must run as root'),
            ('host-cgroup', 'private cgroup namespace'),
            ('pid1-mismatch', 'before starting other processes'),
            ('wrong-fs', 'cgroup v2'),
        )
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            for name, text in {
                'id': '''#!/bin/sh
if [ "$CASE" = nonroot ]; then echo 1000; else echo 0; fi
''',
                'cat': '''#!/bin/sh
case "$1" in
/proc/self/cgroup)
    if [ "$CASE" = host-cgroup ]; then echo '0::/kubepods.slice/pod/container'; else echo '0::/'; fi ;;
/proc/1/cgroup)
    if [ "$CASE" = pid1-mismatch ]; then echo '0::/other'; else echo '0::/'; fi ;;
esac
''',
                'stat': '#!/bin/sh\necho tmpfs\n',
                **{name: '#!/bin/sh\necho mutation >> "$MUTATIONS"\nexit 99\n'
                   for name in ('mount', 'mkdir', 'chown', 'chmod', 'mknod')},
            }.items():
                path = base / name
                path.write_text(text)
                path.chmod(0o755)
            for case, expected in cases:
                with self.subTest(case=case):
                    mutations = base / 'mutations'
                    result = subprocess.run(
                        ['bash', str(SCRIPT)], text=True, capture_output=True,
                        env={**os.environ, 'PATH': f'{base}:{os.environ["PATH"]}',
                             'CASE': case, 'MUTATIONS': str(mutations)}, timeout=5,
                    )
                    self.assertNotEqual(result.returncode, 0)
                    self.assertIn(expected, result.stderr)
                    self.assertFalse(mutations.exists(), result.stderr)


if __name__ == '__main__':
    unittest.main()
