#!/usr/bin/env python3
"""Validate Grype JSON, count unique IDs, and enforce Critical WITH fixes only."""

import argparse
import json
from pathlib import Path
import sys

from ci_policy import boolean, require
from image_identity import scan_identity

SEVERITIES = ("critical", "high", "medium", "low", "negligible", "unknown")


def summarize(report, expected):
    require(isinstance(report, dict), "report is not an object")
    require(isinstance(report.get("matches"), list), "matches array missing")
    subject = scan_identity(report.get("source"), expected)
    require(isinstance(report.get("descriptor"), dict)
            and report["descriptor"].get("name") == "grype", "Grype descriptor missing")
    counts = {severity: set() for severity in SEVERITIES}
    actionable = {}
    for match in report["matches"]:
        vuln, artifact = match["vulnerability"], match["artifact"]
        severity = vuln["severity"].lower()
        require(severity in counts, "unknown severity schema")
        require(isinstance(vuln["id"], str) and vuln["id"], "vulnerability ID missing")
        require(isinstance(artifact["name"], str) and artifact["name"], "package missing")
        fix = vuln["fix"]
        require(fix["state"] in ("fixed", "not-fixed", "wont-fix", "unknown"),
                "unknown fix state")
        require(isinstance(fix["versions"], list), "fix versions missing")
        require(all(isinstance(v, str) and v for v in fix["versions"]), "invalid fix version")
        require(fix["state"] != "fixed" or fix["versions"], "fixed vulnerability lacks versions")
        counts[severity].add(vuln["id"])
        if severity == "critical" and fix["state"] == "fixed":
            actionable.setdefault(vuln["id"], set()).add(
                f'{artifact["name"]}@{artifact["version"]} -> {", ".join(fix["versions"])}')
    summary = {"counts": {k: len(v) for k, v in counts.items()},
               "critical_fixed": len(actionable), "subject": subject}
    # Generate critical-with-fixes SARIF from supported JSON fields, never result.properties.severity.
    rules, results = [], []
    for ident, packages in sorted(actionable.items()):
        rules.append({"id": ident, "shortDescription": {"text": ident},
                      "properties": {"security-severity": "9.0"}})
        results.append({"ruleId": ident, "ruleIndex": len(rules) - 1, "level": "error",
                        "message": {"text": ident + ": " + "; ".join(sorted(packages))}})
    sarif = {"version": "2.1.0", "$schema": "https://json.schemastore.org/sarif-2.1.0.json",
             "runs": [{"tool": {"driver": {"name": "Grype", "rules": rules}},
                       "results": results}]}
    return summary, sarif


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("report", type=Path)
    parser.add_argument("--scanner-outcome", required=True)
    parser.add_argument("--expected-identity", required=True, type=Path)
    parser.add_argument("--enforce", default="null")
    parser.add_argument("--summary", required=True, type=Path)
    parser.add_argument("--sarif", required=True, type=Path)
    args = parser.parse_args()
    require(args.scanner_outcome == "success", "scanner execution did not succeed")
    enforce = boolean(json.loads(args.enforce))
    summary, sarif = summarize(json.loads(args.report.read_text()),
                               json.loads(args.expected_identity.read_text()))
    summary["enforce"] = enforce
    args.summary.write_text(json.dumps(summary, indent=2) + "\n")
    args.sarif.write_text(json.dumps(sarif, indent=2) + "\n")
    print(json.dumps(summary))
    require(not enforce or summary["critical_fixed"] == 0,
            "Critical vulnerabilities with available fixes")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, KeyError, TypeError, AttributeError) as exc:
        sys.exit(f"Scan gate failed: {exc}")
