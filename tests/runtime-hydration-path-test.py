"""Use real mise installation/env resolution without downloading a runtime."""

import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


class HydrationRuntimePathTest(unittest.TestCase):
    def test_new_runtime_reaches_npm_and_pnpm_with_no_inherited_runtime_path(self):
        mise = shutil.which("mise")
        self.assertIsNotNone(mise, "real mise is required for runtime PATH acceptance")
        for manager, lockfile, expected_args in (
            ("npm", "package-lock.json", "ci"),
            ("pnpm", "pnpm-lock.yaml", "install --frozen-lockfile"),
        ):
            with self.subTest(manager=manager), tempfile.TemporaryDirectory(prefix="ror-mise-path-") as directory:
                fixture = Path(directory)
                project = fixture / "project"
                project.mkdir()
                plugin = fixture / "plugin"
                (plugin / "bin").mkdir(parents=True)
                payload = fixture / "payload"
                payload.mkdir()
                executable = payload / manager
                executable.write_text(
                    '#!/bin/bash\nset -eu\n'
                    'printf "%s\\n%s\\n%s\\n" "$0" "$*" "$ROR_PROJECT_ENV" > "$ROR_PATH_MARKER"\n',
                    encoding="utf-8",
                )
                executable.chmod(0o755)
                # A local ASDF plugin creates a new bin directory only during
                # real mise install. Only the external package manager is fake.
                install = plugin / "bin/install"
                install.write_text(
                    '#!/bin/bash\nset -eu\n'
                    'mkdir -p "$ASDF_INSTALL_PATH/bin"\n'
                    'cp "$ROR_RUNTIME_PAYLOAD/"* "$ASDF_INSTALL_PATH/bin/"\n',
                    encoding="utf-8",
                )
                install.chmod(0o755)
                list_all = plugin / "bin/list-all"
                list_all.write_text('#!/bin/bash\necho 1.0.0\n', encoding="utf-8")
                list_all.chmod(0o755)
                (project / "mise.toml").write_text(
                    '[tools]\n"ror-path-fixture" = "1.0.0"\n'
                    '[env]\nROR_PROJECT_ENV = "project-value"\n', encoding="utf-8"
                )
                (project / "package.json").write_text('{"name":"fixture","version":"1.0.0"}\n')
                if manager == "npm":
                    (project / lockfile).write_text(json.dumps({
                        "name": "fixture", "version": "1.0.0", "lockfileVersion": 3,
                        "packages": {"": {"name": "fixture", "version": "1.0.0"}},
                    }))
                else:
                    (project / lockfile).write_text("lockfileVersion: '9.0'\n")
                env = {
                    "PATH": f"{Path(mise).parent}:/usr/bin:/bin",
                    "HOME": str(fixture / "home"),
                    "XDG_CONFIG_HOME": str(fixture / "xdg-config"),
                    "XDG_CACHE_HOME": str(fixture / "xdg-cache"),
                    "XDG_DATA_HOME": str(fixture / "xdg-data"),
                    "XDG_STATE_HOME": str(fixture / "xdg-state"),
                    "MISE_CONFIG_DIR": str(fixture / "mise-config"),
                    "MISE_SYSTEM_CONFIG_DIR": str(fixture / "system-config"),
                    "MISE_DATA_DIR": str(fixture / "mise-data"),
                    "MISE_CACHE_DIR": str(fixture / "mise-cache"),
                    "MISE_STATE_DIR": str(fixture / "mise-state"),
                    "MISE_TRUSTED_CONFIG_PATHS": str(fixture),
                    "MISE_YES": "1",
                    "ROR_RUNTIME_PAYLOAD": str(payload),
                    "ROR_PATH_MARKER": str(fixture / "package-call"),
                    "ROR_MISE_CACHE_SEEDER": str(fixture / "absent-seeder"),
                    "npm_config_cache": str(fixture / "npm-cache"),
                }
                for key, value in env.items():
                    if key == "HOME" or key.endswith(("_DIR", "_HOME")):
                        Path(value).mkdir(parents=True, exist_ok=True)

                def run(*args):
                    return subprocess.run(args, env=env, cwd=project, capture_output=True, text=True, timeout=20)

                linked = run(mise, "plugins", "link", "ror-path-fixture", str(plugin))
                self.assertEqual(linked.returncode, 0, linked.stderr)
                runtime = fixture / "mise-data/installs/ror-path-fixture/1.0.0/bin" / manager
                self.assertFalse(runtime.exists(), "fixture must start without an installed runtime")
                hydrated = run("/bin/bash", str(ROOT / "src/common/post-create.sh"), str(project))
                self.assertTrue(runtime.is_file(), hydrated.stderr)
                self.assertEqual(hydrated.returncode, 0, hydrated.stderr)
                self.assertTrue((fixture / "package-call").exists(), "newly installed package manager was not used")
                self.assertEqual(
                    (fixture / "package-call").read_text().splitlines(),
                    [str(runtime), expected_args, "project-value"],
                )


if __name__ == "__main__":
    unittest.main()
