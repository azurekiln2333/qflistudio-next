#!/usr/bin/env python3
"""Serial final gates, launched only by the grant-required outer host runner.

This driver has no independent scheduling authority or timeout/kill policy.
MAIN_GATE_ARTIFACTS, MAIN_GATE_GRANT and MAIN_GATE_DEADLINE_MONOTONIC must be
inherited from run-main-first-gate.py --suite final. The outer runner owns the
96-second execution budget and exact-identity process-tree cleanup. Commands
are serial, have durable raw logs, and stop at the first failure.
"""

from __future__ import annotations

import ctypes
from ctypes import wintypes
from datetime import datetime, timedelta, timezone
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time


TASK = Path(__file__).resolve().parent.parent
PROJECT = TASK.parent.parent.parent
CORE = PROJECT.parent / "qfli_studio_core"
DART = Path(r"D:\ProgramFiles\flutter_ohos\bin\cache\dart-sdk\bin\dart.exe")
FLUTTER_TOOLS = Path(r"D:\ProgramFiles\flutter_ohos\bin\cache\flutter_tools.snapshot")
INSPECTOR = TASK / "research/inspect-main-content-bundle.py"
FROZEN_MANIFEST = TASK / "c-publication-dependency-authorization-20261023-v2.json"
MAIN_PATHS = (
    "lib/main.dart",
    "lib/content/studio_content_repository.dart",
    "tool/generate_studio_content.dart",
    "tool/verify_studio_content.dart",
    "test/studio_content_repository_test.dart",
    "test/studio_home_release_test.dart",
)
CORE_PATHS = (
    "lib/content/local_content_adapter.dart",
    "lib/editor/editor_problems_bar.dart",
    "lib/editor/file_explorer.dart",
    "lib/editor/retained_editor_host.dart",
    "lib/editor/project_history.dart",
    "lib/pages/home_page.dart",
    "lib/pages/local_content_pages.dart",
    "lib/pages/points_page.dart",
    "lib/pages/tasks_page.dart",
    "lib/pages/tools_grid.dart",
    "lib/pages/offline_text_tool_pages.dart",
    "lib/services/points_feed.dart",
    "lib/services/task_activity_service.dart",
    "lib/tools/offline_text_tools.dart",
    "lib/workspace/editor_workspace.dart",
    "lib/workspace/saved_workspace.dart",
    "lib/workspace/workspace_store.dart",
    "lib/workspace/workspace_dialogs.dart",
    "lib/workspace/saved_workspaces_tab.dart",
    "test/main_workspace_actions_test.dart",
    "test/main_workspace_sessions_test.dart",
    "test/main_workspace_explorer_test.dart",
    "test/main_saved_workspaces_tab_test.dart",
    "test/workspace_store_test.dart",
    "test/workspace_editor_session_test.dart",
    "test/file_explorer_state_test.dart",
    "test/main_output_no_analyzer_test.dart",
    "test/main_editor_short_height_test.dart",
    "test/editor_problems_visibility_test.dart",
    "test/local_content_filters_test.dart",
    "test/home_content_repository_test.dart",
    "test/offline_text_tools_test.dart",
    "test/tools_grid_test.dart",
    "test/points_feed_test.dart",
    "test/points_page_test.dart",
    "test/tasks_page_checkin_test.dart",
    "test/task_activity_service_test.dart",
    "test/retained_editor_test.dart",
    "test/retained_editor_animation_test.dart",
    "test/editor_run_test.dart",
    "test/project_history_concurrency_test.dart",
)
ASSET_PATHS = (
    "assets/content/tutorials.json",
    "assets/content/examples.json",
    "assets/content/provenance.json",
)


class GateFailure(Exception):
    pass


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="microseconds")


def write_report(path: Path, report: dict) -> None:
    temporary = path.with_suffix(".json.tmp")
    temporary.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    os.replace(temporary, path)


def file_hash(path: Path) -> dict:
    content = path.read_bytes()
    return {"sha256": hashlib.sha256(content).hexdigest(), "bytes": len(content)}


def hash_paths(root: Path, paths: tuple[str, ...]) -> dict:
    return {relative: file_hash(root / relative) for relative in paths}


def snapshot(source_inputs: tuple[str, ...], frozen: list[dict]) -> dict:
    return {
        "observed_utc": utc_now(),
        "main_sources": hash_paths(PROJECT, MAIN_PATHS),
        "core_sources": hash_paths(CORE, CORE_PATHS),
        "provenance_inputs": hash_paths(PROJECT, source_inputs),
        "main_assets": hash_paths(PROJECT, ASSET_PATHS),
        "frozen17": hash_paths(CORE, tuple(item["path"] for item in frozen)),
        "frozen_manifest": file_hash(FROZEN_MANIFEST),
        "driver": file_hash(Path(__file__).resolve()),
        "inspector": file_hash(INSPECTOR),
        "main_pubspec": file_hash(PROJECT / "pubspec.yaml"),
    }


def frozen_mismatches(state: dict, frozen: list[dict]) -> list[str]:
    return [item["path"] for item in frozen
            if state["frozen17"][item["path"]]["sha256"].lower() != item["sha256"].lower()
            or state["frozen17"][item["path"]]["bytes"] != item["bytes"]]


def drift(before: dict, after: dict) -> dict:
    result = {}
    for group in ("main_sources", "core_sources", "provenance_inputs", "main_assets", "frozen17"):
        result[group] = [name for name, value in before[group].items() if after[group].get(name) != value]
    result["control_files"] = [name for name in ("frozen_manifest", "driver", "inspector", "main_pubspec")
                               if before[name] != after[name]]
    return result


def process_creation(proc: subprocess.Popen) -> dict:
    api = ctypes.WinDLL("kernel32", use_last_error=True)
    api.GetProcessTimes.argtypes = [wintypes.HANDLE] + [ctypes.POINTER(wintypes.FILETIME)] * 4
    api.GetProcessTimes.restype = wintypes.BOOL
    values = [wintypes.FILETIME() for _ in range(4)]
    if not api.GetProcessTimes(int(proc._handle), *(ctypes.byref(item) for item in values)):
        raise ctypes.WinError(ctypes.get_last_error())
    ticks = (values[0].dwHighDateTime << 32) | values[0].dwLowDateTime
    created = datetime(1601, 1, 1, tzinfo=timezone.utc) + timedelta(microseconds=ticks // 10)
    return {"creation_filetime_100ns": str(ticks),
            "creation_utc": created.strftime("%Y-%m-%dT%H:%M:%S") + f".{ticks % 10_000_000:07d}Z",
            "handle_value": str(int(proc._handle))}


def validate_prior_report(current: dict, commands: list[tuple], report: dict) -> None:
    value = os.environ.get("MAIN_GATE_PRIOR_REPORT", "")
    if not value:
        raise GateFailure("Remaining gates require an explicit inherited prior report path")
    path = Path(value).resolve()
    if not path.is_relative_to((TASK / ".artifacts").resolve()) or not path.is_file():
        raise GateFailure("Prior report must be an existing report in this task's .artifacts")
    prior = json.loads(path.read_text(encoding="utf-8"))
    attempted = prior["commands"]
    if prior["suite"] != "final" or prior["status"] != "FAIL" or len(attempted) != 2:
        raise GateFailure("Prior report must be the original final attempt stopped after its two format gates")
    for index, expected_status in enumerate(("PASS", "FAIL")):
        name, cwd, command = commands[index]
        item = attempted[index]
        if (item["name"] != name or item["status"] != expected_status
                or item["cwd"] != str(cwd) or item["argv"] != command
                or item["exit_code"] is None or (item["exit_code"] == 0) != (expected_status == "PASS")):
            raise GateFailure("Prior format-main PASS / format-core FAIL command evidence does not match")
    if prior["main_scope"] != list(MAIN_PATHS) or prior["core_scope"] != list(CORE_PATHS):
        raise GateFailure("Prior exact main/core scopes do not match")
    groups = ("main_sources", "core_sources", "provenance_inputs", "main_assets", "frozen17",
              "frozen_manifest", "inspector", "main_pubspec")
    mismatches = [group for group in groups
                  if current[group] != prior["before"][group]
                  or prior["after"][group] != prior["before"][group]]
    if mismatches:
        raise GateFailure(f"Current/prior hash state differs from the original before snapshot: {mismatches}")
    report["prior_report"] = {"path": str(path), **file_hash(path), "status": prior["status"]}
    report["prior_hash_comparison"] = {"matched_groups": list(groups), "ignored_group": "driver",
                                       "reason": "Driver changed solely to support this explicit continuation"}
    report["skipped_prior_commands"] = attempted
    report["unresolved_prior_gate"] = {"name": "format-core", "status": "FAIL",
                                       "prior_report": str(path), "exit_code": attempted[1]["exit_code"]}


def inherited_context() -> tuple[Path, float]:
    if os.name != "nt":
        raise GateFailure("Windows host required")
    if not os.environ.get("MAIN_GATE_GRANT", "").strip():
        raise GateFailure("Missing inherited MAIN_GATE_GRANT; use the grant-required outer runner")
    value = os.environ.get("MAIN_GATE_ARTIFACTS", "")
    if not value:
        raise GateFailure("Missing inherited MAIN_GATE_ARTIFACTS")
    artifacts = Path(value).resolve()
    if not artifacts.is_relative_to((TASK / ".artifacts").resolve()) or not artifacts.is_dir():
        raise GateFailure("Inherited artifacts must be the existing isolated task .artifacts directory")
    try:
        deadline = float(os.environ["MAIN_GATE_DEADLINE_MONOTONIC"])
    except (KeyError, ValueError) as exc:
        raise GateFailure("Missing/invalid inherited execution deadline") from exc
    if not 0 < deadline - time.monotonic() <= 96.0:
        raise GateFailure("Inherited execution deadline is expired or outside the 96-second window")
    return artifacts, deadline


def run() -> int:
    artifacts, deadline = inherited_context()
    start_at = os.environ.get("MAIN_GATE_START_AT", "format-main")
    if start_at not in ("format-main", "analyze-main"):
        raise GateFailure("Unsupported inherited MAIN_GATE_START_AT")
    remaining_only = start_at == "analyze-main"
    report_path = artifacts / "final-gates-report.json"
    bundle = artifacts / "bundle"
    report = {
        "schema": 1, "suite": "final-remaining" if remaining_only else "final",
        "status": "PREFLIGHT", "started_utc": utc_now(),
        "grant": os.environ["MAIN_GATE_GRANT"], "driver_pid": os.getpid(),
        "artifact_directory": str(artifacts), "bundle_directory": str(bundle),
        "execution_deadline_monotonic": deadline,
        "main_scope": list(MAIN_PATHS), "core_scope": list(CORE_PATHS),
        "commands": [], "errors": [],
    }
    if remaining_only:
        report.update(result_scope="remaining-six-gates-only", full_final_pass=False,
                      prior_format_failure_remains_unresolved=True)
    write_report(report_path, report)
    source_inputs = ()
    frozen = []
    before = None
    active_child = None
    active_step = None
    try:
        for path in (DART, FLUTTER_TOOLS, Path(sys.executable), INSPECTOR, FROZEN_MANIFEST,
                     PROJECT / ".dart_tool/package_config.json", CORE / ".dart_tool/package_config.json"):
            if not path.is_file():
                raise GateFailure(f"Required cached tool/config/inspector missing: {path}")
        if Path.cwd().resolve() != PROJECT.resolve():
            raise GateFailure(f"Final driver cwd must be {PROJECT}")
        provenance = json.loads((PROJECT / ASSET_PATHS[2]).read_text(encoding="utf-8"))
        records = provenance["sources"]
        source_inputs = tuple(item["path"] for item in records)
        if len(source_inputs) != 27 or len(set(source_inputs)) != 27:
            raise GateFailure("Expected exactly 27 distinct authoritative provenance inputs")
        for relative in source_inputs:
            if not (PROJECT / relative).resolve().is_relative_to(PROJECT.parent.resolve()):
                raise GateFailure(f"Provenance input outside sibling workspace: {relative}")
        manifest = json.loads(FROZEN_MANIFEST.read_text(encoding="utf-8"))
        frozen = manifest["files"]
        if len(frozen) != 17 or len({item["path"] for item in frozen}) != 17:
            raise GateFailure("Frozen authorization must contain exactly 17 distinct paths")
        for item in frozen:
            if not (CORE / item["path"]).resolve().is_relative_to(CORE.resolve()):
                raise GateFailure("Frozen manifest path outside core")
        before = snapshot(source_inputs, frozen)
        report["before"] = before
        report["frozen17_before_mismatches"] = frozen_mismatches(before, frozen)
        if report["frozen17_before_mismatches"]:
            raise GateFailure("Core frozen17 differs from the raw authorized manifest")
        commands = [
            ("format-main", PROJECT, [str(DART), "format", "--output=none", "--set-exit-if-changed", *MAIN_PATHS]),
            ("format-core", CORE, [str(DART), "format", "--output=none", "--set-exit-if-changed", *CORE_PATHS]),
            ("analyze-main", PROJECT, [str(DART), str(FLUTTER_TOOLS), "analyze", "--no-pub", "--fatal-infos", *MAIN_PATHS]),
            ("analyze-core", CORE, [str(DART), str(FLUTTER_TOOLS), "analyze", "--no-pub", "--fatal-infos", *CORE_PATHS]),
            ("generate-main-content", PROJECT, [str(DART), "tool/generate_studio_content.dart"]),
            ("verify-main-content", PROJECT, [str(DART), "tool/verify_studio_content.dart"]),
            ("build-main-bundle", PROJECT, [str(DART), str(FLUTTER_TOOLS), "build", "bundle", "--no-pub",
                                           "--debug", "--target-platform", "windows-x64", "--asset-dir", str(bundle)]),
            ("inspect-main-bundle", PROJECT, [sys.executable, "-B", str(INSPECTOR), str(bundle),
                                             "--source-root", str(PROJECT), "--byte-order", "little"]),
        ]
        start_index = 0
        if remaining_only:
            validate_prior_report(before, commands, report)
            start_index = 2
            commands = commands[start_index:]
        report["planned_commands"] = [{"name": name, "cwd": str(cwd), "argv": command}
                                      for name, cwd, command in commands]
        report["status"] = "RUNNING"
        write_report(report_path, report)
        for index, (name, cwd, command) in enumerate(commands, start_index + 1):
            if time.monotonic() >= deadline - 0.25:
                raise GateFailure("Outer execution deadline reached before next command")
            active_step = {
                "index": index, "name": name, "cwd": str(cwd), "argv": command,
                "status": "STARTING", "started_utc": utc_now(), "pid": None, "exit_code": None,
                "stdout": str(artifacts / f"final-{index:02d}-{name}.stdout.log"),
                "stderr": str(artifacts / f"final-{index:02d}-{name}.stderr.log"),
            }
            report["commands"].append(active_step)
            write_report(report_path, report)
            with Path(active_step["stdout"]).open("ab", buffering=0) as stdout, Path(active_step["stderr"]).open("ab", buffering=0) as stderr:
                active_child = subprocess.Popen(command, cwd=cwd, stdin=subprocess.DEVNULL,
                                                stdout=stdout, stderr=stderr, shell=False,
                                                creationflags=subprocess.CREATE_NO_WINDOW)
                active_step.update(pid=active_child.pid, status="RUNNING")
                write_report(report_path, report)
                active_step.update(process_creation(active_child))
                write_report(report_path, report)
                # The outer runner owns the single total deadline and taskkill
                # tree cleanup. This child never starts a competing watchdog.
                code = active_child.wait()
                active_step.update(exit_code=code, terminal_utc=utc_now(), status="PASS" if code == 0 else "FAIL")
                active_child = None
            write_report(report_path, report)
            if code != 0:
                raise GateFailure(f"{name} exited {code}; later gates were not started")
            state = snapshot(source_inputs, frozen)
            changes = drift(before, state)
            active_step["drift_after_command"] = changes
            active_step["frozen17_mismatches"] = frozen_mismatches(state, frozen)
            write_report(report_path, report)
            if any(changes.values()) or active_step["frozen17_mismatches"]:
                raise GateFailure(f"{name}: source/input/asset/frozen manifest drift; later gates were not started")
        report["status"] = "PASS"
    except (OSError, ValueError, KeyError, TypeError, GateFailure) as exc:
        report["status"] = "FAIL"
        report["errors"].append(f"{type(exc).__name__}: {exc}")
        write_report(report_path, report)
        # If instrumentation failed after Popen, stay alive with its handle so
        # the outer exact-identity tree watchdog can still enforce its budget.
        if active_child is not None:
            code = active_child.wait()
            if active_step is not None:
                active_step.update(exit_code=code, terminal_utc=utc_now(), status="FAIL")
    finally:
        if before is not None:
            try:
                after = snapshot(source_inputs, frozen)
                report["after"] = after
                report["changes"] = drift(before, after)
                report["frozen17_after_mismatches"] = frozen_mismatches(after, frozen)
                if any(report["changes"].values()) or report["frozen17_after_mismatches"]:
                    report["status"] = "FAIL"
            except (OSError, ValueError, KeyError, TypeError) as exc:
                report["status"] = "FAIL"
                report["errors"].append(f"Final snapshot: {exc}")
        report["completed_utc"] = utc_now()
        write_report(report_path, report)
    print(json.dumps({"status": report["status"], "report": str(report_path)}, ensure_ascii=False), flush=True)
    return 0 if report["status"] == "PASS" else 1


if __name__ == "__main__":
    try:
        raise SystemExit(run())
    except (OSError, ValueError, GateFailure) as error:
        print(f"REFUSED: {error}", file=sys.stderr)
        raise SystemExit(2)
