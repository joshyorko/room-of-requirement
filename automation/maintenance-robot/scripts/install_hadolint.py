from __future__ import annotations

import stat
import sys
import urllib.request
from pathlib import Path


HADOLINT_VERSION = "2.14.0"
HADOLINT_URL = (
    "https://github.com/hadolint/hadolint/releases/download/"
    f"v{HADOLINT_VERSION}/hadolint-Linux-x86_64"
)


def main() -> None:
    target = Path(sys.executable).resolve().parent / "hadolint"
    urllib.request.urlretrieve(HADOLINT_URL, target)
    target.chmod(target.stat().st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)
    print(f"Installed hadolint {HADOLINT_VERSION} to {target}")


if __name__ == "__main__":
    main()
