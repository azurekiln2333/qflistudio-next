"""Run read-only acceptance gates with explicit per-command timeouts."""
from __future__ import annotations

import argparse
import concurrent.futures
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import re
import secrets
import shutil
import subprocess
import tempfile
import threading
import time

REPO = Path(__file__).resolve().parents[4]
PROJECTS = {
    "core": REPO.parent / "qfli_studio_core",
    "studio": REPO,
    "server": REPO / "azurekiln-qfli-server",
    "moderation": REPO.parent / "azurekiln-moderation",
}
LOCK = threading.Lock()


def emit(value):
    with LOCK:
        print(json.dumps(value, ensure_ascii=True), flush=True)


def git(root, *args):
    result = subprocess.run(["git", *args], cwd=root, capture_output=True, timeout=30)
    if result.returncode:
        raise RuntimeError(result.stderr.decode("utf-8", "replace"))
    return result.stdout.decode("utf-8", "replace").strip()


def write_json(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2), encoding="utf-8")


def source_hashes(root, kind):
    folders = ["lib", "test", "tool"] if kind in {"core", "studio"} else ["src", "scripts", "test", "packages"]
    files = []
    for folder in folders:
        path = root / folder
        if path.is_dir():
            files.extend(p for p in path.rglob("*") if p.is_file() and p.suffix in {".dart", ".js", ".cjs", ".mjs", ".ets"} and not {"node_modules", "build"}.intersection(p.parts))
    for name in ["pubspec.yaml", "pubspec.lock", "analysis_options.yaml", "package.json", "package-lock.json"]:
        if (root / name).is_file():
            files.append(root / name)
    return {p.relative_to(root).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(set(files))}


def commit_audit(root, path_filter=None):
    args = ["log", "--all", "--since=2026-11-02T00:00:00+08:00", "--format=%H%x00%cI%x00%B%x00%x1e"]
    if path_filter:
        args.extend(["--", path_filter])
    raw = git(root, *args)
    results = []
    conventional = re.compile(r"^[a-z][a-z0-9-]*(?:\([^\r\n)]+\))?!?: \S.*$")
    attribution = re.compile(r"^\s*(?:(?:co-authored-by|signed-off-by|authored-by|reviewed-by|tested-by|acked-by|author|written-by)\s*:|(?:generated|written)\s+(?:with|by)\b|(?:作者|署名|签名)\s*[:：])", re.I)
    for block in raw.split("\x1e"):
        fields = block.strip().split("\x00", 2)
        if len(fields) != 3:
            continue
        sha, timestamp, body = fields
        body = body.rstrip("\x00\r\n")
        lines = body.splitlines()
        subject = lines[0] if lines else ""
        signatures = [line for line in lines if attribution.search(line) or re.search(r"generated with", line, re.I)]
        results.append({"commit": sha, "committedAt": timestamp, "subject": subject, "body": body,
                        "conventional": bool(conventional.fullmatch(subject)), "attributionLines": signatures})
    return {"since": "2026-11-02T00:00:00+08:00", "pathFilter": path_filter, "commits": results,
            "count": len(results), "violations": [item for item in results if not item["conventional"] or item["attributionLines"]]}


def clean_node_environment(data_root):
    allowed = re.compile(r"^(path|systemroot|windir|temp|tmp|appdata|localappdata|userprofile|comspec|pathext|lang|lc_all)$", re.I)
    environment = {key: value for key, value in os.environ.items() if allowed.fullmatch(key)}
    environment.update(NODE_ENV="test", DB_DRIVER="sqlite", QFLI_DATA_DIR=str(data_root),
                       QFLI_JWT_SECRET=secrets.token_hex(32), QFLI_AUDIT_SALT=secrets.token_hex(32),
                       QFLI_MODERATION_SUBJECT_SALT=secrets.token_hex(32))
    return environment


def stop_owned_tree(process):
    if process.poll() is not None:
        return
    if os.name == "nt":
        subprocess.run(["taskkill", "/PID", str(process.pid), "/T", "/F"], capture_output=True, timeout=20)
    else:
        process.kill()
    try:
        process.wait(timeout=10)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait(timeout=10)


def run_command(evidence, name, cwd, argv, timeout, environment=None):
    started = time.monotonic()
    output = evidence / (name + ".log")
    emit({"event": "start", "name": name, "timeoutSeconds": timeout, "command": argv})
    timed_out = False
    with output.open("wb") as stream:
        process = subprocess.Popen(argv, cwd=cwd, env=environment, stdout=stream, stderr=subprocess.STDOUT)
        try:
            process.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            timed_out = True
            stop_owned_tree(process)
    log = output.read_text(encoding="utf-8", errors="replace")
    result = {"name": name, "cwd": str(cwd), "command": argv, "timeoutSeconds": timeout,
              "exitCode": process.returncode, "timedOut": timed_out, "durationSeconds": round(time.monotonic() - started, 3),
              "log": str(output), "tail": "\n".join(log.splitlines()[-22:])}
    write_json(evidence / (name + ".json"), result)
    emit({"event": "finish", **result})
    return result


def syntax_gate(evidence, node):
    root = PROJECTS["server"]
    files = [root / name for name in source_hashes(root, "server") if Path(name).suffix in {".js", ".cjs", ".mjs"}]
    started = time.monotonic()
    results = []
    for path in files:
        remaining = 180 - (time.monotonic() - started)
        if remaining <= 0:
            raise TimeoutError("Server syntax check exceeded 180 seconds")
        result = subprocess.run([node, "--check", str(path)], cwd=root, capture_output=True, timeout=min(15, remaining))
        results.append({"file": path.relative_to(root).as_posix(), "exitCode": result.returncode,
                        "output": (result.stdout + result.stderr).decode("utf-8", "replace")})
    result = {"name": "server-syntax", "command": "node --check <each JavaScript file under src/scripts/test/packages>",
              "timeoutSeconds": 180, "exitCode": 0 if all(row["exitCode"] == 0 for row in results) else 1,
              "durationSeconds": round(time.monotonic() - started, 3), "checkedFiles": len(results), "files": results}
    write_json(evidence / "server-syntax.json", result)
    emit({"event": "finish", **{key: value for key, value in result.items() if key != "files"}})
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--evidence", type=Path)
    parser.add_argument("--only", choices=["all", "flutter", "node"], default="all")
    args = parser.parse_args()
    evidence = args.evidence or Path(tempfile.mkdtemp(prefix="qfli-client-acceptance-20261103-p7-"))
    evidence.mkdir(parents=True, exist_ok=True)
    node = shutil.which("node")
    flutter = shutil.which("flutter")
    npm = str(Path(node).parent / "npm.cmd") if os.name == "nt" else shutil.which("npm")
    initial = {"startedAt": dt.datetime.now(dt.timezone.utc).isoformat(), "evidenceRoot": str(evidence),
               "tools": {"node": node, "flutter": flutter, "npm": npm}, "projects": {}}
    for kind, root in PROJECTS.items():
        initial["projects"][kind] = {"root": str(root), "gitRoot": git(root, "rev-parse", "--show-toplevel"),
                                      "revision": git(root, "rev-parse", "HEAD"), "status": git(root, "status", "--short"),
                                      "sourceHashes": source_hashes(root, kind)}
    write_json(evidence / "manifest.json", initial)
    audits = {kind: commit_audit(REPO if kind == "server" else root,
                                 "azurekiln-qfli-server" if kind == "server" else None)
              for kind, root in PROJECTS.items()}
    write_json(evidence / "commit-audit.json", audits)
    emit({"event": "manifest", "evidenceRoot": str(evidence), "commitAudit": {kind: {"count": audit["count"], "violations": audit["violations"]} for kind, audit in audits.items()}})

    def flutter_group():
        results = [run_command(evidence, "flutter-version", REPO, [flutter, "--version", "--machine"], 90)]
        for kind, timeout in [("core", 600), ("studio", 300)]:
            results.append(run_command(evidence, kind + "-test", PROJECTS[kind], [flutter, "test", "--no-pub", "--reporter", "expanded", "--timeout", "2m"], timeout))
            results.append(run_command(evidence, kind + "-analyze", PROJECTS[kind], [flutter, "analyze", "--no-pub"], 240))
        results.append(run_command(evidence, "studio-preview-test", REPO,
                                   [flutter, "test", "--no-pub", "tool/preview_test.dart",
                                    "--reporter", "expanded", "--timeout", "1m"], 120))
        return results

    def server_group():
        environment = clean_node_environment(evidence / "server-fallback-data")
        return [run_command(evidence, "server-test", PROJECTS["server"], [node, "--test", "--test-timeout=60000", "test/*.test.js"], 120, environment),
                run_command(evidence, "server-lint-command", PROJECTS["server"], [npm, "run", "lint"], 60, environment), syntax_gate(evidence, node),
                run_command(evidence, "studio-script-tests", REPO,
                            [node, "--test", "--test-timeout=60000", "scripts/*.test.mjs", "scripts/compliance/*.test.mjs"], 120, environment)]

    def moderation_group():
        environment = clean_node_environment(evidence / "moderation-fallback-data")
        return [run_command(evidence, "moderation-test", PROJECTS["moderation"], [npm, "test"], 120, environment),
                run_command(evidence, "moderation-lint", PROJECTS["moderation"], [npm, "run", "lint"], 120, environment),
                run_command(evidence, "moderation-ci-tests", PROJECTS["moderation"],
                            [node, "--test", "--test-timeout=60000", "scripts/publish-ci.test.mjs"], 120, environment)]

    groups = [flutter_group, server_group, moderation_group] if args.only == "all" else ([flutter_group] if args.only == "flutter" else [server_group, moderation_group])
    results = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
        for future in concurrent.futures.as_completed([pool.submit(group) for group in groups]):
            results.extend(future.result())
    changed = {}
    for kind, root in PROJECTS.items():
        before = initial["projects"][kind]["sourceHashes"]
        after = source_hashes(root, kind)
        changed[kind] = [path for path in sorted(before.keys() | after.keys()) if before.get(path) != after.get(path)]
    summary = {"finishedAt": dt.datetime.now(dt.timezone.utc).isoformat(), "evidenceRoot": str(evidence),
               "results": results, "sourceChanges": changed,
               "auditCounts": {kind: {"count": audit["count"], "violations": len(audit["violations"])} for kind, audit in audits.items()}}
    write_json(evidence / "summary.json", summary)
    emit({"event": "complete", "evidenceRoot": str(evidence), "sourceChanges": changed,
          "results": [{"name": item["name"], "exitCode": item["exitCode"], "timedOut": item.get("timedOut", False)} for item in results]})
    if any(item["exitCode"] != 0 for item in results) or any(changed.values()):
        raise SystemExit(1)


if __name__ == "__main__":
    main()
