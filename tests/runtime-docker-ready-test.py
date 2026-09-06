"""Exercise the real starter's successful socket/profile branches in /tmp."""

import json
import os
from pathlib import Path
import shutil
import signal
import socket
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
STARTER = ROOT / "src/common/scripts/ror-docker-start.sh"


class DockerReadyTest(unittest.TestCase):
    def run_ready_case(self, link_default, existing_default=False):
        with tempfile.TemporaryDirectory(prefix="ror-docker-ready-") as directory:
            fixture = Path(directory)
            bindir = fixture / "bin"
            bindir.mkdir()

            def executable(name, content):
                path = bindir / name
                path.write_text(content, encoding="utf-8")
                path.chmod(0o755)
                return str(path)

            # Force the guarded sudo boundary even when the suite runs as root.
            executable("id", "#!/bin/bash\necho 1000\n")
            executable("mountpoint", "#!/bin/bash\nexit 0\n")
            executable("sudo", r'''#!/bin/bash
set -eu
case "$1" in
    find | mount | chown) exit 0 ;;
    mkdir | install | chmod | ln | tee)
        operation="$1"
        shift
        for argument in "$@"; do
            case "$argument" in
                -* | [0-7][0-7][0-7] | [0-7][0-7][0-7][0-7]) ;;
                "$ROR_READY_FIXTURE" | "$ROR_READY_FIXTURE"/*) ;;
                *) echo "unsafe fixture operation: $operation $argument" >&2; exit 97 ;;
            esac
        done
        exec "/usr/bin/$operation" "$@" ;;
    "$ROR_READY_FIXTURE/bin/daemon") exec "$@" ;;
    *) echo "unexpected sudo operation: $1" >&2; exit 98 ;;
esac
''')
            daemon = executable("daemon", f"#!{sys.executable}\n" + '''
import json, os, socket, sys
from pathlib import Path
args = dict(arg[2:].split("=", 1) for arg in sys.argv[1:])
root = Path(os.environ["ROR_READY_FIXTURE"])
assert args["host"] == "unix://" + str(root / "custom/docker.sock")
config = json.loads(Path(args["config-file"]).read_text())
assert config["data-root"] == str(root / 'data "quoted"')
(root / "daemon-args.json").write_text(json.dumps(sys.argv[1:]))
server = socket.socket(socket.AF_UNIX)
server.bind(args["host"].removeprefix("unix://"))
server.listen()
while True:
    conn, _ = server.accept()
    with conn:
        assert conn.recv(4096).startswith(b"GET /info HTTP/1.0")
        conn.sendall(b'HTTP/1.0 200 OK\\r\\n\\r\\n{"ServerVersion":"fixture"}')
''')
            client = executable("client", f"#!{sys.executable}\n" + '''
import json, os, socket, sys
from pathlib import Path
root = Path(os.environ["ROR_READY_FIXTURE"])
assert sys.argv[1:] == ["--host", "unix://" + str(root / "custom/docker.sock"), "info"]
try:
    with socket.socket(socket.AF_UNIX) as conn:
        conn.settimeout(1)
        conn.connect(sys.argv[2].removeprefix("unix://"))
        conn.sendall(b"GET /info HTTP/1.0\\r\\n\\r\\n")
        response = conn.recv(4096)
except (OSError, TimeoutError):
    sys.exit(1)
assert json.loads(response.split(b"\\r\\n\\r\\n", 1)[1])["ServerVersion"] == "fixture"
(root / "client-ready").touch()
''')
            default_socket = fixture / "default/docker.sock"
            default_inode = None
            if existing_default:
                default_socket.parent.mkdir()
                with socket.socket(socket.AF_UNIX) as old:
                    old.bind(str(default_socket))
                default_inode = default_socket.stat().st_ino

            source_config = fixture / "daemon.json"
            source_config.write_text("{}\n", encoding="utf-8")
            env = {
                "PATH": f"{bindir}:{Path(shutil.which('jq')).parent}:/usr/bin:/bin",
                "TMPDIR": str(fixture),
                "ROR_READY_FIXTURE": str(fixture),
                "ROR_DOCKER_DAEMON_CONFIG": str(source_config),
                "ROR_DOCKER_EFFECTIVE_CONFIG": str(fixture / 'effective "quoted".json'),
                "ROR_DOCKER_DATA_ROOT": str(fixture / 'data "quoted"'),
                "ROR_DOCKER_TEST_DATA_ROOT_FSTYPE": "ext4",
                "ROR_DOCKER_TEST_HAS_DOCKERD_ENTRYPOINT": "0",
                "ROR_DOCKER_TEST_DOCKERD_BIN": daemon,
                "ROR_DOCKER_TEST_DOCKER_BIN": client,
                "ROR_DOCKER_TEST_DEFAULT_SOCKET": str(default_socket),
                "ROR_DOCKER_TEST_PROFILE_DIR": str(fixture / "profile.d"),
                "ROR_DOCKER_START_TIMEOUT_SECONDS": "5",
            }
            log = fixture / "starter.log"
            with log.open("w") as output:
                process = subprocess.Popen(
                    ["/bin/bash", str(STARTER), "--socket", str(fixture / "custom/docker.sock"),
                     "--link-default", str(link_default).lower()],
                    env=env, stdout=output, stderr=output, start_new_session=True,
                )
                try:
                    status = process.wait(timeout=12)
                finally:
                    # Only this test's session and synthetic API process.
                    try:
                        os.killpg(process.pid, signal.SIGTERM)
                    except ProcessLookupError:
                        pass
                    process.wait(timeout=5)
            self.assertEqual(status, 0, log.read_text())
            self.assertTrue((fixture / "client-ready").exists(), log.read_text())
            self.assertEqual(
                json.loads((fixture / "daemon-args.json").read_text()),
                [f"--host=unix://{fixture}/custom/docker.sock",
                 f'--config-file={fixture}/effective "quoted".json'],
            )
            self.assertEqual((fixture / "custom/docker.sock").stat().st_mode & 0o777, 0o660)
            profile = fixture / "profile.d/ror-docker-host.sh"
            if link_default and not existing_default:
                self.assertTrue(default_socket.is_symlink())
                self.assertEqual(os.readlink(default_socket), str(fixture / "custom/docker.sock"))
                self.assertFalse(profile.exists())
            else:
                if existing_default:
                    self.assertEqual(default_socket.stat().st_ino, default_inode)
                    self.assertFalse(default_socket.is_symlink())
                else:
                    self.assertFalse(default_socket.exists())
                self.assertTrue(profile.is_file(), log.read_text())
                self.assertEqual(profile.stat().st_mode & 0o777, 0o644)
                sourced = subprocess.run(
                    ["/bin/bash", "-c", 'source "$1"; printf "%s" "$DOCKER_HOST"', "fixture", str(profile)],
                    capture_output=True, text=True, env={"PATH": "/usr/bin:/bin"}, check=True,
                )
                self.assertEqual(sourced.stdout, f"unix://{fixture}/custom/docker.sock")

    def test_custom_socket_exports_profile_when_linking_disabled(self):
        self.run_ready_case(False)

    def test_custom_socket_links_absent_default(self):
        self.run_ready_case(True)

    def test_existing_default_socket_is_preserved_and_custom_profile_exported(self):
        self.run_ready_case(True, existing_default=True)


if __name__ == "__main__":
    unittest.main()
