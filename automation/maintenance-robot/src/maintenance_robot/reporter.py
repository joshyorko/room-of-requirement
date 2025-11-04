from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, List, Optional


@dataclass
class GitHubActionUpdate:
    file: Path
    action: str
    previous: str
    updated: str

    def to_dict(self) -> Dict[str, str]:
        return {
            "file": str(self.file),
            "action": self.action,
            "previous": self.previous,
            "updated": self.updated,
        }


@dataclass
class DownloadUpdate:
    file: Path
    identifier: str
    previous: str
    updated: str

    def to_dict(self) -> Dict[str, str]:
        return {
            "file": str(self.file),
            "identifier": self.identifier,
            "previous": self.previous,
            "updated": self.updated,
        }


@dataclass
class LockfileUpdate:
    feature: str
    previous: Optional[Dict[str, str]]
    updated: Optional[Dict[str, str]]

    def to_dict(self) -> Dict[str, Optional[Dict[str, str]]]:
        return {
            "feature": self.feature,
            "previous": self.previous,
            "updated": self.updated,
        }


@dataclass
class MaintenanceReport:
    github_actions: List[GitHubActionUpdate] = field(default_factory=list)
    downloads: List[DownloadUpdate] = field(default_factory=list)
    lockfile: List[LockfileUpdate] = field(default_factory=list)

    def add_action_update(self, update: GitHubActionUpdate) -> None:
        self.github_actions.append(update)

    def add_download_update(self, update: DownloadUpdate) -> None:
        self.downloads.append(update)

    def add_lockfile_update(self, update: LockfileUpdate) -> None:
        self.lockfile.append(update)

    def to_dict(self) -> Dict[str, List[Dict[str, object]]]:
        return {
            "github_actions": [item.to_dict() for item in self.github_actions],
            "downloads": [item.to_dict() for item in self.downloads],
            "lockfile": [item.to_dict() for item in self.lockfile],
        }
