#!/usr/bin/env python3
"""Create an unapplied official-formatting proposal in inherited task artifacts.

Only the grant-required outer runner may launch this driver. Originals are
passed exclusively to dart format --output=show; stdout becomes shadow files.
No original source, Git index/object, or frozen authorization is written.
"""

from __future__ import annotations

import difflib
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time
from urllib.parse import urljoin


HELPER_PATH = Path(__file__).with_name("run-main-final-gates.py")
SPEC = importlib.util.spec_from_file_location("main_final_gate_helpers", HELPER_PATH)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError("Final-gate snapshot helpers unavailable")
H = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(H)
ORIGINAL_ATTEMPT = "main-final-gate-20261023T083451Z-6af2ff9c"
INTENT = "unapplied proposal, exact17 authorization unchanged"


def raw_metadata(content: bytes) -> dict:
    return {"sha256": hashlib.sha256(content).hexdigest(), "bytes": len(content),
            "git_blob": hashlib.sha1(b"blob " + str(len(content)).encode("ascii") + b"\0" + content).hexdigest()}


def preservation_snapshot(paths: tuple[str, ...]) -> dict:
    names = tuple(dict.fromkeys((*paths, "lib/editor/editor_page.dart")))
    return {"originals_and_page": {name: raw_metadata((H.CORE / name).read_bytes()) for name in names},
            "core_analysis_options": H.file_hash(H.CORE / "analysis_options.yaml"),
            "core_package_config": H.file_hash(H.CORE / ".dart_tool/package_config.json"),
            "main_package_config": H.file_hash(H.PROJECT / ".dart_tool/package_config.json")}


def run_command(report: dict, report_path: Path, name: str, command: list[str], cwd: Path,
                stdout_path: Path, stderr_path: Path, deadline: float) -> None:
    if time.monotonic() >= deadline - 0.25:
        raise H.GateFailure("Outer execution deadline reached before next formatter")
    step = {"name": name, "argv": command, "cwd": str(cwd), "status": "STARTING",
            "pid": None, "exit_code": None, "started_utc": H.utc_now(),
            "stdout": str(stdout_path), "stderr": str(stderr_path)}
    report["commands"].append(step)
    H.write_report(report_path, report)
    with stdout_path.open("wb", buffering=0) as output, stderr_path.open("wb", buffering=0) as errors:
        child = subprocess.Popen(command, cwd=cwd, stdin=subprocess.DEVNULL, stdout=output, stderr=errors,
                                 shell=False, creationflags=subprocess.CREATE_NO_WINDOW)
        step.update(pid=child.pid, status="RUNNING")
        H.write_report(report_path, report)
        try:
            step.update(H.process_creation(child))
            H.write_report(report_path, report)
        except OSError as exc:
            step["identity_error"] = str(exc)
            H.write_report(report_path, report)
            child.wait()  # outer runner still owns this entire child tree
            raise
        code = child.wait()
        step.update(exit_code=code, terminal_utc=H.utc_now(), status="PASS" if code == 0 else "FAIL")
    H.write_report(report_path, report)
    if code != 0:
        raise H.GateFailure(f"{name} exited {code}; no later formatter started")


def run() -> int:
    artifacts, deadline = H.inherited_context()
    report_path = artifacts / "format-candidates-report.json"
    report = {"schema": 1, "suite": "format-candidate", "status": "PREFLIGHT", "intent": INTENT,
              "full_final_pass": False, "source_apply_authorized": False, "started_utc": H.utc_now(),
              "commands": [], "candidates": [], "errors": [], "preparer": H.file_hash(Path(__file__))}
    H.write_report(report_path, report)
    before = preserved = None
    paths = ()
    source_inputs = ()
    frozen = []
    try:
        prior_path = Path(os.environ["MAIN_GATE_PRIOR_REPORT"]).resolve()
        if prior_path.name != "final-gates-report.json" or prior_path.parent.name != ORIGINAL_ATTEMPT:
            raise H.GateFailure("The exact original 13-findings final report is required")
        prior = json.loads(prior_path.read_text(encoding="utf-8"))
        provenance = json.loads((H.PROJECT / H.ASSET_PATHS[2]).read_text(encoding="utf-8"))
        source_inputs = tuple(item["path"] for item in provenance["sources"])
        frozen = json.loads(H.FROZEN_MANIFEST.read_text(encoding="utf-8"))["files"]
        if len(source_inputs) != 27 or len(set(source_inputs)) != 27 or len(frozen) != 17:
            raise H.GateFailure("Expected original 27 inputs and frozen17")
        before = H.snapshot(source_inputs, frozen)
        report["before"] = before
        format_commands = [
            ("format-main", H.PROJECT, [str(H.DART), "format", "--output=none", "--set-exit-if-changed", *H.MAIN_PATHS]),
            ("format-core", H.CORE, [str(H.DART), "format", "--output=none", "--set-exit-if-changed", *H.CORE_PATHS]),
        ]
        H.validate_prior_report(before, format_commands, report)
        if H.frozen_mismatches(before, frozen):
            raise H.GateFailure("Frozen17 differs from exact authorized raw bytes")
        log = Path(prior["commands"][1]["stdout"]).resolve()
        if log.parent != prior_path.parent or not log.is_file():
            raise H.GateFailure("Original format-core stdout must be beside the original report")
        log_text = log.read_text(encoding="utf-8-sig")
        paths = tuple(re.findall(r"^Changed ((?:lib|test)/[A-Za-z0-9_./-]+\.dart)\s*$", log_text, re.MULTILINE))
        if len(paths) != 13 or len(set(paths)) != 13 or any(name not in H.CORE_PATHS for name in paths):
            raise H.GateFailure("Original stdout must identify exactly 13 distinct scoped Dart paths")
        if not re.search(r"^Formatted 41 files \(13 changed\) in .+ seconds\.$", log_text, re.MULTILINE):
            raise H.GateFailure("Original formatter summary must confirm 41 checked / 13 would change")
        report["original_format_stdout"] = {"path": str(log), **H.file_hash(log)}
        report["paths"] = list(paths)
        preserved = preservation_snapshot(paths)
        report["preservation_before"] = preserved
        shadow = artifacts / "shadow_core"
        shadow.mkdir()
        shutil.copyfile(H.CORE / "analysis_options.yaml", shadow / "analysis_options.yaml")
        core_config_path = H.CORE / ".dart_tool/package_config.json"
        config = json.loads(core_config_path.read_text(encoding="utf-8"))
        main_config = json.loads((H.PROJECT / ".dart_tool/package_config.json").read_text(encoding="utf-8"))
        core_package = next(item for item in config["packages"] if item["name"] == "qfli_studio_core")
        main_package = next(item for item in main_config["packages"] if item["name"] == "qflistudio")
        if core_package["languageVersion"] != "3.11" or main_package["languageVersion"] != "3.11":
            raise H.GateFailure("Original main/core languageVersion must both remain 3.11")
        for package in config["packages"]:
            package["rootUri"] = (shadow.as_uri() + "/" if package["name"] == "qfli_studio_core"
                                  else urljoin(core_config_path.as_uri(), package["rootUri"]))
        (shadow / ".dart_tool").mkdir()
        config_path = shadow / ".dart_tool/package_config.json"
        config_path.write_text(json.dumps(config, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        report["shadow_context"] = {"root": str(shadow), "package_config": H.file_hash(config_path),
                                    "analysis_options": H.file_hash(shadow / "analysis_options.yaml"),
                                    "core_language_version": "3.11", "main_language_version": "3.11"}
        originals = {name: (H.CORE / name).read_bytes() for name in paths}
        frozen_paths = {item["path"] for item in frozen}
        report["status"] = "RUNNING"
        for index, name in enumerate(paths, 1):
            candidate = shadow / name
            candidate.parent.mkdir(parents=True, exist_ok=True)
            run_command(report, report_path, f"show-{index:02d}-{name}",
                        [str(H.DART), "format", "--output=show", "--summary=none", name], H.CORE,
                        candidate, artifacts / f"format-show-{index:02d}.stderr.log", deadline)
            new = candidate.read_bytes()
            if not new or new == originals[name]:
                raise H.GateFailure(f"Expected nonempty changed official candidate: {name}")
            report["candidates"].append({"path": name, "candidate": str(candidate),
                                         "old": raw_metadata(originals[name]), "new": raw_metadata(new),
                                         "in_frozen17": name in frozen_paths, "intent": INTENT})
            H.write_report(report_path, report)
        run_command(report, report_path, "check-exact-13-shadow-candidates",
                    [str(H.DART), "format", "--output=none", "--set-exit-if-changed", *paths], shadow,
                    artifacts / "format-shadow-check.stdout.log", artifacts / "format-shadow-check.stderr.log", deadline)
        patch = bytearray()
        for item in report["candidates"]:
            name = item["path"]
            patch.extend(f"diff --git a/{name} b/{name}\nindex {item['old']['git_blob']}..{item['new']['git_blob']} 100644\n".encode("ascii"))
            for line in difflib.diff_bytes(difflib.unified_diff, originals[name].splitlines(keepends=True),
                                          (shadow / name).read_bytes().splitlines(keepends=True),
                                          fromfile=f"a/{name}".encode("ascii"), tofile=f"b/{name}".encode("ascii")):
                patch.extend(line if line.endswith(b"\n") else line + b"\n\\ No newline at end of file\n")
        patch_path = artifacts / "main-format-unapplied.patch"
        patch_path.write_bytes(patch)
        report["patch"] = {"path": str(patch_path), **H.file_hash(patch_path), "intent": INTENT}
        report["status"] = "PROPOSAL_READY"
    except (OSError, ValueError, KeyError, TypeError, StopIteration, H.GateFailure) as exc:
        report["status"] = "FAIL"
        report["errors"].append(f"{type(exc).__name__}: {exc}")
    finally:
        if before is not None:
            try:
                after = H.snapshot(source_inputs, frozen)
                report["after"] = after
                report["source_changes"] = H.drift(before, after)
                report["frozen17_after_mismatches"] = H.frozen_mismatches(after, frozen)
                if any(report["source_changes"].values()) or report["frozen17_after_mismatches"]:
                    report["status"] = "FAIL"
            except (OSError, ValueError, KeyError, TypeError) as exc:
                report["status"] = "FAIL"
                report["errors"].append(f"Final source snapshot: {exc}")
        if preserved is not None:
            try:
                report["preservation_after"] = preservation_snapshot(paths)
                report["originals_page_and_context_unchanged"] = report["preservation_after"] == preserved
                if not report["originals_page_and_context_unchanged"]:
                    report["status"] = "FAIL"
            except OSError as exc:
                report["status"] = "FAIL"
                report["errors"].append(f"Final original/context snapshot: {exc}")
        report["completed_utc"] = H.utc_now()
        H.write_report(report_path, report)
    print(json.dumps({"status": report["status"], "report": str(report_path), "intent": INTENT}), flush=True)
    return 0 if report["status"] == "PROPOSAL_READY" else 1


if __name__ == "__main__":
    try:
        raise SystemExit(run())
    except (OSError, ValueError, KeyError, H.GateFailure) as error:
        print(f"REFUSED: {error}", file=sys.stderr)
        raise SystemExit(2)
