"""Run project/global task isolation against the installed real mise CLI."""

from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
HYDRATOR = ROOT / "src/common/post-create.sh"


class MiseTaskScopeTest(unittest.TestCase):
    def test_global_setup_is_ignored_and_project_setup_runs(self):
        mise = shutil.which("mise")
        self.assertIsNotNone(mise, "real mise is required for task-scope acceptance")
        with tempfile.TemporaryDirectory(prefix="ror-mise-scope-") as directory:
            fixture = Path(directory)
            project = fixture / "project"
            project.mkdir()
            config = fixture / "config"
            config.mkdir()
            (config / "config.toml").write_text(
                "[tasks.setup]\nrun = 'touch \"$ROR_SCOPE_GLOBAL_MARKER\"'\n", encoding="utf-8"
            )
            project_config = project / "mise.toml"
            project_config.write_text("[tools]\n", encoding="utf-8")
            # Do not inherit real user config, caches, exported shell functions,
            # tool declarations, or mise activation from the invoking shell.
            env = {
                "PATH": f"{Path(mise).parent}:/usr/bin:/bin",
                "HOME": str(fixture / "home"),
                "XDG_CONFIG_HOME": str(fixture / "xdg-config"),
                "XDG_CACHE_HOME": str(fixture / "xdg-cache"),
                "XDG_DATA_HOME": str(fixture / "xdg-data"),
                "XDG_STATE_HOME": str(fixture / "xdg-state"),
                "MISE_CONFIG_DIR": str(config),
                "MISE_DATA_DIR": str(fixture / "mise-data"),
                "MISE_CACHE_DIR": str(fixture / "mise-cache"),
                "MISE_STATE_DIR": str(fixture / "mise-state"),
                "MISE_SYSTEM_CONFIG_DIR": str(fixture / "system-config"),
                "MISE_TRUSTED_CONFIG_PATHS": str(fixture),
                "MISE_YES": "1",
                "ROR_MISE_CACHE_SEEDER": str(fixture / "absent-seeder"),
                "ROR_SCOPE_GLOBAL_MARKER": str(fixture / "global-setup-ran"),
            }
            for key, value in env.items():
                if key == "HOME" or key.endswith(("_DIR", "_HOME")):
                    Path(value).mkdir(parents=True, exist_ok=True)

            def run(*args):
                return subprocess.run(
                    args, cwd=project, env=env, capture_output=True, text=True, timeout=20
                )

            # The global fixture must really be visible before testing exclusion.
            listed = run(mise, "tasks", "ls", "--name-only")
            self.assertEqual(listed.returncode, 0, listed.stderr)
            self.assertIn("setup", listed.stdout.splitlines())
            hydrated = run("/bin/bash", str(HYDRATOR), str(project))
            self.assertEqual(hydrated.returncode, 0, hydrated.stderr)
            self.assertFalse((fixture / "global-setup-ran").exists(), hydrated.stderr)

            # Local shadowing must still execute the project's own setup once.
            project_config.write_text(
                '[tasks.setup]\nrun = "printf local >> project-setup-ran"\n',
                encoding="utf-8",
            )
            hydrated = run("/bin/bash", str(HYDRATOR), str(project))
            self.assertEqual(hydrated.returncode, 0, hydrated.stderr)
            self.assertEqual((project / "project-setup-ran").read_text(), "local")
            self.assertFalse((fixture / "global-setup-ran").exists())


if __name__ == "__main__":
    unittest.main()
