#!/usr/bin/env python3
"""Inventory embedded Node from the tested image's SPDX, separately from CI Node."""

import argparse
import hashlib
import json
from pathlib import Path
import re
import sys

from ci_policy import require


def inventory(sbom):
    require(sbom.get("spdxVersion") == "SPDX-2.3" and isinstance(sbom.get("packages"), list),
            "Node inventory requires a valid SPDX package inventory")
    packages = []
    for package in sbom["packages"]:
        name = package.get("name", "").lower()
        if re.fullmatch(r"(?:nodejs(?:[-@].*)?|node|node-bin|node-[0-9]+)", name):
            packages.append(package)
    return dict(node_packages=packages,
                scope="SBOM-discovered packages; absence is not proof that every embedded binary was found")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("evidence", type=Path)
    args = parser.parse_args()
    sbom = args.evidence / "sbom.spdx.json"
    result = inventory(json.loads(sbom.read_text()))
    result["sbom_sha256"] = hashlib.sha256(sbom.read_bytes()).hexdigest()
    result["image"] = json.loads((args.evidence / "context.json").read_text())
    result["identity"] = json.loads((args.evidence / "identity.json").read_text())
    (args.evidence / "node-inventory.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    try:
        main()
    except (ValueError, KeyError, OSError) as exc:
        sys.exit(f"Node inventory failed: {exc}")
