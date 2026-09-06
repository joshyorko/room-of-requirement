from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from packaging.version import Version

from maintenance_robot.downloads import DownloadsUpdater
from maintenance_robot.reporter import MaintenanceReport


_PIN_PATTERN = r"ARG IMAGE=image:(?P<version>\d+\.\d+\.\d+)-cli@sha256:[a-f0-9]+"
_DIGEST_PATTERN = r"ARG IMAGE=image:\d+\.\d+\.\d+-cli@sha256:(?P<sha256>[a-f0-9]+)"


class DownloadsUpdaterTests(unittest.TestCase):
    def _updater(self, report: MaintenanceReport) -> DownloadsUpdater:
        return DownloadsUpdater({}, Path("."), report)

    def test_does_not_replace_newer_tag_digest_with_an_older_candidate(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            path = Path(tmpdir) / "Dockerfile"
            path.write_text(f"ARG IMAGE=image:29.8.0-cli@sha256:{'a' * 64}\n", encoding="utf-8")
            report = MaintenanceReport()

            self._updater(report)._update_file(
                path, __import__("re").compile(_PIN_PATTERN), "image", Version("29.7.0"),
                sha256_pattern_str=_DIGEST_PATTERN, latest_sha256="b" * 64,
            )

            self.assertIn("29.8.0-cli@sha256:" + "a" * 64, path.read_text(encoding="utf-8"))
            self.assertEqual([], report.downloads)

    def test_does_not_write_newer_tag_without_its_matching_digest(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            path = Path(tmpdir) / "Dockerfile"
            original = f"ARG IMAGE=image:29.8.0-cli@sha256:{'a' * 64}\n"
            path.write_text(original, encoding="utf-8")

            self._updater(MaintenanceReport())._update_file(
                path, __import__("re").compile(_PIN_PATTERN), "image", Version("29.9.0"),
                sha256_pattern_str=_DIGEST_PATTERN,
            )

            self.assertEqual(original, path.read_text(encoding="utf-8"))

    def test_does_not_write_ambiguous_multiple_tag_matches_with_one_digest(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            path = Path(tmpdir) / "Dockerfile"
            original = "\n".join(
                [
                    f"ARG IMAGE=image:29.8.0-cli@sha256:{'a' * 64}",
                    f"ARG SECOND_IMAGE=image:29.8.0-cli@sha256:{'b' * 64}",
                    "",
                ]
            )
            path.write_text(original, encoding="utf-8")

            self._updater(MaintenanceReport())._update_file(
                path,
                __import__("re").compile(r"ARG .*IMAGE=image:(?P<version>\d+\.\d+\.\d+)-cli@sha256:[a-f0-9]+"),
                "image",
                Version("29.9.0"),
                sha256_pattern_str=_DIGEST_PATTERN,
                latest_sha256="c" * 64,
            )

            self.assertEqual(original, path.read_text(encoding="utf-8"))

    def test_updates_tag_and_digest_atomically_and_reports_digest_only_change(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            path = Path(tmpdir) / "Dockerfile"
            path.write_text(f"ARG IMAGE=image:29.8.0-cli@sha256:{'a' * 64}\n", encoding="utf-8")
            report = MaintenanceReport()
            updater = self._updater(report)

            updater._update_file(
                path, __import__("re").compile(_PIN_PATTERN), "image", Version("29.9.0"),
                sha256_pattern_str=_DIGEST_PATTERN, latest_sha256="b" * 64,
            )
            self.assertIn("29.9.0-cli@sha256:" + "b" * 64, path.read_text(encoding="utf-8"))
            self.assertEqual(1, len(report.downloads))

            updater._update_file(
                path, __import__("re").compile(_PIN_PATTERN), "image", Version("29.9.0"),
                sha256_pattern_str=_DIGEST_PATTERN, latest_sha256="c" * 64,
            )
            self.assertIn("29.9.0-cli@sha256:" + "c" * 64, path.read_text(encoding="utf-8"))
            self.assertEqual(2, len(report.downloads))
            self.assertEqual("29.9.0 (digest)", report.downloads[-1].updated)


if __name__ == "__main__":
    unittest.main()
