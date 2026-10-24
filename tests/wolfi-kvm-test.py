"""KVM provisioning contracts, with group tools isolated from the host."""
import os
from pathlib import Path
import subprocess
import tempfile
import tomllib
import unittest

ROOT = Path(__file__).resolve().parents[1]
HELPER = ROOT / 'src/wolfi/scripts/prepare-kvm.sh'


class KvmTests(unittest.TestCase):
    def test_image_provisions_libkrun_and_configuration(self):
        dockerfile = (ROOT / 'src/wolfi/.devcontainer/Dockerfile').read_text()
        self.assertIn('    crun \\\n', dockerfile)
        self.assertIn('    libkrun ' + chr(92), dockerfile)
        self.assertIn("grep -F '+LIBKRUN'", dockerfile)
        self.assertIn('src/wolfi/config/containers-krun.conf /etc/containers/containers.conf.d/50-krun.conf', dockerfile)
        self.assertIn('src/wolfi/scripts/prepare-kvm.sh /usr/local/bin/prepare-kvm.sh', dockerfile)
        self.assertIn('/usr/local/bin/prepare-kvm.sh', (ROOT / 'src/common/entrypoint.sh').read_text())
        config = tomllib.loads((ROOT / 'src/wolfi/config/containers-krun.conf').read_text())
        self.assertIn('run.oci.keep_original_groups=1', config['containers']['annotations'])
        self.assertEqual(config['engine']['runtimes']['krun'], ['/usr/bin/krun'])

    def run_helper(self, existing='yes', device='yes', gid='1234'):
        with tempfile.TemporaryDirectory() as directory:
            guard = Path(directory) / 'guard.sh'
            guard.write_text('''[() {
    if [[ "${2:-}" == /dev/kvm && "$1" == -c ]]; then [[ "$DEVICE" == yes ]]; return; fi
    builtin [ "$@"
}
id() { if [[ "${1:-}" == -u ]]; then echo 0; else return 0; fi; }
stat() { echo "$GID"; }
getent() { if [[ "$EXISTING" == yes ]]; then echo "existing:x:$GID:"; else return 2; fi; }
groupadd() { echo "groupadd $*"; }
usermod() { echo "usermod $*"; }
''')
            return subprocess.run(['bash', str(HELPER)], capture_output=True, text=True,
                                  env=dict(os.environ, BASH_ENV=str(guard), EXISTING=existing,
                                           DEVICE=device, GID=gid))

    def test_reuses_actual_device_group(self):
        result = self.run_helper()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('usermod -aG existing vscode', result.stdout)
        self.assertNotIn('groupadd', result.stdout)

    def test_creates_group_for_unregistered_gid(self):
        result = self.run_helper(existing='no')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('groupadd -g 1234 ror-kvm-1234', result.stdout)
        self.assertIn('usermod -aG ror-kvm-1234 vscode', result.stdout)

    def test_missing_device_does_not_change_groups(self):
        result = self.run_helper(device='no')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn('usermod', result.stdout)
        self.assertNotIn('groupadd', result.stdout)

    def test_root_owned_group_does_not_grant_root_group(self):
        result = self.run_helper(gid='0')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn('usermod', result.stdout)
        self.assertIn('Warning', result.stderr)


if __name__ == '__main__':
    unittest.main()
