from __future__ import annotations

import unittest
from unittest.mock import patch

from maintenance_robot import github_api


class GitHubReleaseSelectionTests(unittest.TestCase):
    def setUp(self) -> None:
        github_api.fetch_latest_version.cache_clear()

    def tearDown(self) -> None:
        github_api.fetch_latest_version.cache_clear()

    def test_selects_greatest_allowed_release_independent_of_api_order(self) -> None:
        entries = [
            {"tag_name": "v2.8.0", "prerelease": False, "draft": False},
            {"tag_name": "v3.1.0", "prerelease": False, "draft": False},
        ]
        with patch.object(github_api, "_get", return_value=entries), patch.object(
            github_api, "_get_tag_sha", return_value="c" * 40
        ):
            release = github_api.fetch_latest_version("owner/repo", "release")

        self.assertIsNotNone(release)
        assert release is not None
        self.assertEqual("v3.1.0", release.tag)

    def test_rejects_prerelease_tag_when_stable_only(self) -> None:
        entries = [
            {"name": "v4.0.0rc1", "commit": {"sha": "a" * 40}},
            {"name": "v3.9.0", "commit": {"sha": "b" * 40}},
        ]
        with patch.object(github_api, "_get", return_value=entries):
            release = github_api.fetch_latest_version(
                "owner/repo", "tag", include_prerelease=False
            )

        self.assertIsNotNone(release)
        assert release is not None
        self.assertEqual("v3.9.0", release.tag)

    def test_rejects_draft_releases_even_when_prereleases_are_allowed(self) -> None:
        entries = [
            {"tag_name": "v5.0.0", "prerelease": False, "draft": True},
            {"tag_name": "v4.0.0", "prerelease": False, "draft": False},
        ]
        with patch.object(github_api, "_get", return_value=entries), patch.object(
            github_api, "_get_tag_sha", return_value="d" * 40
        ):
            release = github_api.fetch_latest_version(
                "owner/repo", "release", include_prerelease=True
            )

        self.assertIsNotNone(release)
        assert release is not None
        self.assertEqual("v4.0.0", release.tag)


if __name__ == "__main__":
    unittest.main()
