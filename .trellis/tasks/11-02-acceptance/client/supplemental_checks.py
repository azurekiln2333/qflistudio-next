"""Capture client probes, global source scan, and complete commit-message audit."""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess

import bounded_checks as gates


def inspect_sources(evidence):
    # Include native client adapters, tools, tests and the moderation service.
    scopes = {
        "core": ["lib", "test", "tool"],
        "studio": ["lib", "test", "tool", "scripts", "ohos/entry/src/main", "android/app/src",
                   "ios/Runner", "macos/Runner", "linux", "windows", "web"],
        "server": ["src", "scripts", "test", "packages"],
        "moderation": ["src", "scripts", "test", "packages"],
    }
    scans = {}
    for kind, root in gates.PROJECTS.items():
        existing = [folder for folder in scopes[kind] if (root / folder).is_dir()]
        command = ["rg", "--files", "--hidden", "-g", "!node_modules/**", "-g", "!build/**", *existing]
        found = subprocess.run(command, cwd=root, capture_output=True, timeout=30, check=True)
        files = [root / name for name in found.stdout.decode("utf-8").splitlines()]
        suffixes = {".dart", ".ets", ".ts", ".tsx", ".js", ".cjs", ".mjs", ".json", ".json5",
                    ".yaml", ".yml", ".html", ".xml", ".kt", ".java", ".swift", ".m", ".mm",
                    ".cc", ".cpp", ".c", ".h", ".hpp", ".cmake", ".txt"}
        sources = [path for path in files if path.suffix.lower() in suffixes and
                   not {"node_modules", "build", ".dart_tool", "ephemeral"}.intersection(path.parts)]
        matches = []
        pattern = re.compile(r"bing|web_search", re.I)
        for path in sources:
            lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
            for number, line in enumerate(lines, 1):
                if pattern.search(line):
                    matches.append({"file": path.relative_to(root).as_posix(), "line": number,
                                    "text": line, "context": lines[max(0, number - 3):number + 2]})
        scans[kind] = {"root": str(root), "scopes": existing, "pattern": pattern.pattern,
                       "fileCount": len(sources), "matches": matches,
                       "sourceHashes": {p.relative_to(root).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
                                        for p in sources}}
    gates.write_json(evidence / "global-bing-scan.json", scans)
    audits = {kind: gates.commit_audit(gates.REPO if kind == "server" else root,
                                      "azurekiln-qfli-server" if kind == "server" else None)
              for kind, root in gates.PROJECTS.items()}
    gates.write_json(evidence / "commit-audit.json", audits)
    # Correct the original audit's relative path and record all reachable refs.
    summary_path = evidence / "summary.json"
    if summary_path.exists():
        summary = json.loads(summary_path.read_text(encoding="utf-8"))
        summary["auditCounts"] = {k: {"count": v["count"], "violations": len(v["violations"])}
                                  for k, v in audits.items()}
        gates.write_json(summary_path, summary)
    manifest = json.loads((evidence / "manifest.json").read_text(encoding="utf-8"))
    drift = {}
    for kind, root in gates.PROJECTS.items():
        before = manifest["projects"][kind]["sourceHashes"]
        after = gates.source_hashes(root, kind)
        drift[kind] = [p for p in sorted(before.keys() | after.keys()) if before.get(p) != after.get(p)]
    review = {"capturedAt": dt.datetime.now(dt.timezone.utc).isoformat(),
              "gitLogScope": "--all --since=2026-11-02T00:00:00+08:00 (committer date)",
              "revisions": {k: gates.git(r, "rev-parse", "HEAD") for k, r in gates.PROJECTS.items()},
              "sourceChangesSinceFullGates": drift,
              "auditCounts": {k: {"count": v["count"], "violations": len(v["violations"])}
                              for k, v in audits.items()},
              "scanCounts": {k: {"files": v["fileCount"], "matches": len(v["matches"])}
                             for k, v in scans.items()}}
    gates.write_json(evidence / "source-review.json", review)
    gates.emit(review)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--evidence", required=True, type=Path)
    parser.add_argument("--inspect-only", action="store_true")
    parser.add_argument("--extras-only", action="store_true")
    args = parser.parse_args()
    evidence = args.evidence
    evidence.mkdir(parents=True, exist_ok=True)
    results = []
    if not args.inspect_only and not args.extras_only:
        flutter = shutil.which("flutter")
        for name, path in [("navigation-widget-final", "navigation_click_test.dart"),
                           ("ai-transport-probe-complete", "ai_transport_probe_test.dart")]:
            results.append(gates.run_command(evidence, name, gates.REPO,
                              [flutter, "test", "--no-pub", ".trellis/tasks/11-02-acceptance/client/" + path,
                               "--reporter", "expanded", "--timeout", "1m"], 120))
        results.append(gates.run_command(evidence, "core-compliance-widgets", gates.PROJECTS["core"],
                          [flutter, "test", "--no-pub", "test/auth_login_entry_test.dart",
                           "test/settings_compliance_test.dart", "test/ai_file_header_test.dart",
                           "--reporter", "expanded", "--timeout", "1m"], 120))
    if not args.inspect_only:
        flutter = shutil.which("flutter")
        node = shutil.which("node")
        environment = gates.clean_node_environment(evidence / "extra-gates-data")
        results.append(gates.run_command(evidence, "studio-preview-test", gates.REPO,
                          [flutter, "test", "--no-pub", "tool/preview_test.dart",
                           "--reporter", "expanded", "--timeout", "1m"], 120))
        results.append(gates.run_command(evidence, "studio-script-tests", gates.REPO,
                          [node, "--test", "--test-timeout=60000", "scripts/*.test.mjs",
                           "scripts/compliance/*.test.mjs"], 120, environment))
        results.append(gates.run_command(evidence, "moderation-ci-tests", gates.PROJECTS["moderation"],
                          [node, "--test", "--test-timeout=60000", "scripts/publish-ci.test.mjs"], 120, environment))
    inspect_sources(evidence)
    if any(row["exitCode"] != 0 for row in results):
        raise SystemExit(1)


if __name__ == "__main__":
    main()
