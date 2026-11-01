#!/usr/bin/env python3
"""Source-only host-gate artifact. Run only after an explicit named slot grant.

Example (the grant must quote the real scheduling authorization):
    python run-main-first-gate.py --grant "Note/main released; main accepted" \
        --suite first --next-owner Web338

This script is Windows-only and uses the cached Flutter tool directly. Test
suites invoke Flutter exactly once; final launches the serial final-gate driver.
No suite selects a device or runs pub.
The 110-second plan reserves 96 seconds for tests, 8 for terminal cleanup, and
4 for channel publication. Windows scheduling/termination cannot provide a hard
real-time guarantee: unconfirmed exit is recorded as HOLD, never RELEASE.

Only this file is the deliverable; preparing it does not authorize execution.
"""

from __future__ import annotations

import argparse
import ctypes
from ctypes import wintypes
from datetime import datetime, timedelta, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time
import uuid


DART = Path(r"D:\ProgramFiles\flutter_ohos\bin\cache\dart-sdk\bin\dart.exe")
FLUTTER_TOOLS = Path(r"D:\ProgramFiles\flutter_ohos\bin\cache\flutter_tools.snapshot")
CORE = Path(r"D:\MyNewProjects\qfli_studio_core")
TASK = Path(__file__).resolve().parent.parent
PROJECT = TASK.parent.parent.parent
CHANNEL = "qfli-core-release-sync"
TEST_SECONDS = 96.0
CLEANUP_SECONDS = 8.0
PUBLISH_SECONDS = 4.0
TOTAL_SECONDS = 110.0
TEST_SUITES = {
    "project-switch": (
        "test/workspace_project_switch_test.dart",
    ),
    "project-switch-regressions": (
        "test/workspace_project_switch_test.dart",
        "test/workspace_dialog_layout_test.dart",
        "test/main_workspace_explorer_test.dart",
        "test/main_workspace_sessions_test.dart",
        "test/file_explorer_state_test.dart",
        "test/retained_editor_test.dart",
        "test/main_editor_short_height_test.dart",
    ),
    "project-switch-analysis": (
        "lib/editor/file_explorer.dart",
        "lib/editor/editor_page.dart",
        "lib/editor/retained_editor_host.dart",
        "test/workspace_project_switch_test.dart",
    ),
    "workspace-dialog": (
        "test/workspace_dialog_layout_test.dart",
    ),
    "workspace-dialog-regressions": (
        "test/workspace_dialog_layout_test.dart",
        "test/main_workspace_actions_test.dart",
        "test/file_explorer_state_test.dart",
        "test/main_workspace_sessions_test.dart",
        "test/retained_editor_test.dart",
        "test/main_editor_short_height_test.dart",
    ),
    "workspace-dialog-analysis": (
        "lib/workspace/workspace_dialogs.dart",
        "lib/editor/file_explorer.dart",
        "test/workspace_dialog_layout_test.dart",
    ),
    "first": (
        "test/main_workspace_actions_test.dart",
        "test/local_content_filters_test.dart",
        "test/home_navigation_test.dart",
    ),
    "regressions": (
        "test/retained_editor_test.dart",
        "test/retained_editor_animation_test.dart",
        "test/editor_run_test.dart",
        "test/project_history_concurrency_test.dart",
        "test/main_workspace_sessions_test.dart",
        "test/main_output_no_analyzer_test.dart",
        "test/main_workspace_explorer_test.dart",
        "test/main_editor_short_height_test.dart",
    ),
    "final": (),
    "final-remaining": (),
    "format-candidate": (),
}
SHARED_SOURCE_PATHS = (
    "lib/workspace/workspace_dialogs.dart",
    "lib/editor/editor_page.dart",
    "lib/editor/editor_controller.dart",
    "lib/editor/file_explorer.dart",
    "lib/editor/retained_editor_host.dart",
    "lib/content/local_content_adapter.dart",
    "lib/pages/local_content_pages.dart",
    "lib/pages/home_page.dart",
)


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="microseconds")


def write_json(path: Path, value: dict) -> None:
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    os.replace(temporary, path)


def read_head() -> str:
    """Resolve ordinary/worktree Git HEAD without starting another process."""
    git = CORE / ".git"
    if git.is_file():
        text = git.read_text(encoding="utf-8").strip()
        if not text.startswith("gitdir: "):
            raise ValueError("Unrecognized core .git file")
        git = (CORE / text[8:]).resolve()
    common = git
    if (git / "commondir").is_file():
        common = (git / (git / "commondir").read_text(encoding="utf-8").strip()).resolve()
    value = (git / "HEAD").read_text(encoding="utf-8").strip()
    for _ in range(8):
        if not value.startswith("ref: "):
            if not re.fullmatch(r"[0-9a-fA-F]{40,64}", value):
                raise ValueError("Unrecognized core HEAD object id")
            return value.lower()
        reference = value[5:]
        if not reference.startswith("refs/") or ".." in Path(reference).parts:
            raise ValueError("Unsafe core HEAD reference")
        for base in (git, common):
            loose = base / reference
            if loose.is_file():
                value = loose.read_text(encoding="utf-8").strip()
                break
        else:
            packed = common / "packed-refs"
            if packed.is_file():
                for line in packed.read_text(encoding="utf-8").splitlines():
                    fields = line.split()
                    if len(fields) == 2 and fields[1] == reference:
                        value = fields[0]
                        break
                else:
                    raise ValueError(f"Cannot resolve {reference}")
            else:
                raise ValueError(f"Cannot resolve {reference}")
    raise ValueError("Core HEAD symbolic reference loop")


def source_snapshot(source_paths: tuple[str, ...]) -> dict:
    result = {"observed_utc": utc_now(), "files": {}}
    try:
        result["core_head"] = read_head()
    except (OSError, ValueError) as exc:
        result["core_head_error"] = str(exc)
    for relative in source_paths:
        try:
            path = CORE / relative
            content = path.read_bytes()
            stat = path.stat()
            result["files"][relative] = {
                "sha256": hashlib.sha256(content).hexdigest(),
                "bytes": len(content),
                "mtime_ns": str(stat.st_mtime_ns),
            }
        except OSError as exc:
            result["files"][relative] = {"error": str(exc)}
    return result


def changed_sources(before: dict, after: dict) -> list[str]:
    changed = []
    if before.get("core_head") != after.get("core_head"):
        changed.append("core HEAD")
    for name in before["files"]:
        first = before["files"][name]
        last = after["files"][name]
        if first.get("sha256") != last.get("sha256") or "error" in first or "error" in last:
            changed.append(name)
    return changed


class ProcessEntry(ctypes.Structure):
    _fields_ = [
        ("dwSize", wintypes.DWORD), ("cntUsage", wintypes.DWORD),
        ("th32ProcessID", wintypes.DWORD), ("th32DefaultHeapID", ctypes.c_size_t),
        ("th32ModuleID", wintypes.DWORD), ("cntThreads", wintypes.DWORD),
        ("th32ParentProcessID", wintypes.DWORD), ("pcPriClassBase", wintypes.LONG),
        ("dwFlags", wintypes.DWORD), ("szExeFile", wintypes.WCHAR * 260),
    ]


class Windows:
    def __init__(self) -> None:
        self.api = ctypes.WinDLL("kernel32", use_last_error=True)
        declarations = {
            "GetProcessTimes": ([wintypes.HANDLE] + [ctypes.POINTER(wintypes.FILETIME)] * 4, wintypes.BOOL),
            "GetProcessId": ([wintypes.HANDLE], wintypes.DWORD),
            "GetExitCodeProcess": ([wintypes.HANDLE, ctypes.POINTER(wintypes.DWORD)], wintypes.BOOL),
            "WaitForSingleObject": ([wintypes.HANDLE, wintypes.DWORD], wintypes.DWORD),
            "OpenProcess": ([wintypes.DWORD, wintypes.BOOL, wintypes.DWORD], wintypes.HANDLE),
            "CloseHandle": ([wintypes.HANDLE], wintypes.BOOL),
            "CreateToolhelp32Snapshot": ([wintypes.DWORD, wintypes.DWORD], wintypes.HANDLE),
            "Process32FirstW": ([wintypes.HANDLE, ctypes.POINTER(ProcessEntry)], wintypes.BOOL),
            "Process32NextW": ([wintypes.HANDLE, ctypes.POINTER(ProcessEntry)], wintypes.BOOL),
        }
        for name, (arguments, result) in declarations.items():
            function = getattr(self.api, name)
            function.argtypes = arguments
            function.restype = result

    def creation(self, handle: int) -> int:
        values = [wintypes.FILETIME() for _ in range(4)]
        if not self.api.GetProcessTimes(handle, *(ctypes.byref(item) for item in values)):
            raise ctypes.WinError(ctypes.get_last_error())
        return (values[0].dwHighDateTime << 32) | values[0].dwLowDateTime

    def table(self) -> dict[int, int]:
        snapshot = self.api.CreateToolhelp32Snapshot(2, 0)
        if snapshot == wintypes.HANDLE(-1).value:
            raise ctypes.WinError(ctypes.get_last_error())
        entries = {}
        try:
            item = ProcessEntry()
            item.dwSize = ctypes.sizeof(item)
            success = self.api.Process32FirstW(snapshot, ctypes.byref(item))
            if not success:
                raise ctypes.WinError(ctypes.get_last_error())
            while success:
                entries[int(item.th32ProcessID)] = int(item.th32ParentProcessID)
                success = self.api.Process32NextW(snapshot, ctypes.byref(item))
            error = ctypes.get_last_error()
            if error != 18:  # ERROR_NO_MORE_FILES
                raise ctypes.WinError(error)
        finally:
            self.api.CloseHandle(snapshot)
        return entries


class TrackedProcess:
    def __init__(self, win: Windows, pid: int, handle: int, role: str,
                 parent_pid: int | None = None, owns_handle: bool = True) -> None:
        self.win, self.pid, self.handle = win, pid, handle
        self.owns_handle = owns_handle
        self.creation = win.creation(handle)
        created = datetime(1601, 1, 1, tzinfo=timezone.utc) + timedelta(microseconds=self.creation // 10)
        self.record = {
            "role": role, "pid": pid, "parent_pid": parent_pid,
            "creation_filetime_100ns": str(self.creation),
            "creation_utc": created.strftime("%Y-%m-%dT%H:%M:%S") + f".{self.creation % 10_000_000:07d}Z",
            "handle_value": str(handle), "first_observed_utc": utc_now(),
            "terminal_observed": False,
        }
        if win.api.GetProcessId(handle) != pid:
            raise RuntimeError("Process handle PID does not match the owned process")

    def live(self) -> bool:
        result = self.win.api.WaitForSingleObject(self.handle, 0)
        if result == 0x102:  # WAIT_TIMEOUT
            return True
        if result != 0:
            raise ctypes.WinError(ctypes.get_last_error())
        if not self.record["terminal_observed"]:
            code = wintypes.DWORD()
            if not self.win.api.GetExitCodeProcess(self.handle, ctypes.byref(code)):
                raise ctypes.WinError(ctypes.get_last_error())
            self.record.update(terminal_observed=True, exit_code=int(code.value), terminal_utc=utc_now())
        return False

    def validate_live_identity(self) -> bool:
        if self.win.api.GetProcessId(self.handle) != self.pid or self.win.creation(self.handle) != self.creation:
            raise RuntimeError("Retained process identity changed; refusing taskkill")
        return self.live()

    def close(self) -> None:
        if self.owns_handle:
            self.win.api.CloseHandle(self.handle)


def track_child(win: Windows, proc: subprocess.Popen, role: str) -> TrackedProcess:
    # Popen retains this Windows process handle until its object is destroyed.
    # Keep Popen alive; do not close its handle through our reporting wrapper.
    return TrackedProcess(win, proc.pid, int(proc._handle), role, os.getpid(), False)


def discover_descendants(win: Windows, tracked: dict[int, TrackedProcess],
                         role: str = "flutter-descendant") -> None:
    table = win.table()
    pending = True
    while pending:
        pending = False
        for pid, parent in table.items():
            if pid in tracked or parent not in tracked:
                continue
            handle = win.api.OpenProcess(0x100000 | 0x1000, False, pid)
            if not handle:
                # A short-lived child can disappear between snapshot and open.
                # A still-live inaccessible child prevents a truthful release.
                if ctypes.get_last_error() != 87:  # ERROR_INVALID_PARAMETER
                    raise ctypes.WinError(ctypes.get_last_error())
                continue
            child = TrackedProcess(win, pid, handle, role, parent)
            if child.creation < tracked[parent].creation:
                child.close()  # stale/reused parent PID, not our descendant
                continue
            tracked[pid] = child
            pending = True


def taskkill_owned(win: Windows, targets: list[TrackedProcess], artifacts: Path,
                   records: list[dict], deadline: float) -> list[tuple[subprocess.Popen, TrackedProcess]]:
    live = [item for item in targets if item.validate_live_identity()]
    if not live:
        return []
    executable = Path(os.environ.get("SystemRoot", r"C:\Windows")) / "System32/taskkill.exe"
    command = [str(executable)]
    for item in live:
        command.extend(("/PID", str(item.pid)))
    command.extend(("/T", "/F"))
    log_path = artifacts / f"taskkill-{len(records) + 1}.log"
    with log_path.open("ab", buffering=0) as log:
        proc = subprocess.Popen(command, stdin=subprocess.DEVNULL, stdout=log, stderr=log,
                                shell=False, creationflags=subprocess.CREATE_NO_WINDOW)
        process = track_child(win, proc, "taskkill")
        entry = {"command": command, "targets": [item.record.copy() for item in live],
                 "log": str(log_path), "process": process.record}
        records.append(entry)
        try:
            proc.wait(timeout=max(0.01, min(2.0, deadline - time.monotonic())))
        except subprocess.TimeoutExpired:
            entry["wait_timeout"] = True
        process.live()
    # Retain the helper's Popen handle if the OS has not finished it yet.
    return [(proc, process)]


def trellis_command(message: Path, next_owner: str) -> list[str]:
    # Invoke the installed npm CLI entry directly: no shell or batch quoting.
    shim = shutil.which("trellis.cmd") or shutil.which("trellis.ps1")
    if not shim:
        raise FileNotFoundError("Installed trellis CLI shim not found on PATH")
    base = Path(shim).parent
    entry = base / "node_modules/@mindfoldhq/trellis/bin/trellis.js"
    node = base / "node.exe"
    if not node.is_file():
        found = shutil.which("node.exe")
        if not found:
            raise FileNotFoundError("Installed Trellis node.exe not found")
        node = Path(found)
    if not entry.is_file():
        raise FileNotFoundError(f"Installed Trellis CLI entry missing: {entry}")
    return [str(node), str(entry), "channel", "send", CHANNEL, "--scope", "global",
            "--as", "studio-main", "--to", next_owner, "--text-file", str(message)]


def run(args: argparse.Namespace) -> int:
    if os.name != "nt":
        raise RuntimeError("This bounded host runner requires Windows")
    if not args.grant.strip():
        raise ValueError("--grant must contain the explicit named slot authorization")
    if not re.fullmatch(r"[A-Za-z0-9_.:-]+", args.next_owner):
        raise ValueError("--next-owner must be one channel owner name")
    for path in (DART, FLUTTER_TOOLS):
        if not path.is_file():
            raise FileNotFoundError(f"Required cached executable/tool missing: {path}")
    if not CORE.is_dir():
        raise FileNotFoundError(f"Required core cwd missing: {CORE}")
    tests = TEST_SUITES[args.suite]
    final_suite = args.suite in ("final", "final-remaining", "format-candidate")
    format_candidate = args.suite == "format-candidate"
    prior_report = None
    if args.suite in ("final-remaining", "format-candidate"):
        if args.prior_report is None:
            raise ValueError(f"--suite {args.suite} requires an explicit --prior-report")
        prior_report = args.prior_report.resolve()
        if not prior_report.is_file():
            raise FileNotFoundError(f"Required prior final-gate report missing: {prior_report}")
    elif args.prior_report is not None:
        raise ValueError("--prior-report is only valid with final-remaining or format-candidate")
    gate_cwd = PROJECT if final_suite else CORE
    root_role = "final-driver-root" if final_suite else "flutter-root"
    descendant_role = "final-gate-descendant" if final_suite else "flutter-descendant"
    final_driver = TASK / "research/run-main-final-gates.py"
    if format_candidate:
        final_driver = TASK / "research/prepare-main-format-candidates.py"
        root_role, descendant_role = "format-candidate-root", "format-candidate-descendant"
    if final_suite:
        for path in (Path(sys.executable), final_driver, TASK / "research/inspect-main-content-bundle.py"):
            if not path.is_file():
                raise FileNotFoundError(f"Required final driver/inspector/Python missing: {path}")
    source_paths = tests + SHARED_SOURCE_PATHS
    before = source_snapshot(source_paths)
    if "core_head_error" in before or any("error" in value for value in before["files"].values()):
        raise RuntimeError("Required source/HEAD snapshot incomplete; refusing Flutter launch")

    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    artifacts = TASK / ".artifacts" / f"main-{args.suite}-gate-{stamp}-{uuid.uuid4().hex[:8]}"
    artifacts.mkdir(parents=True, exist_ok=False)
    report_path = artifacts / "process-handle-report.json"
    fallback = artifacts / "release-message.md"
    command = [str(DART), str(FLUTTER_TOOLS), "test", *tests, "--no-pub",
               "--concurrency=1", "--timeout", "60s", "--reporter=expanded"]
    if args.suite in ("workspace-dialog-analysis", "project-switch-analysis"):
        command = [str(DART), str(FLUTTER_TOOLS), "analyze", "--no-pub", *tests]
    if final_suite:
        command = [sys.executable, "-B", str(final_driver)]
    win = Windows()
    runner_handle = win.api.OpenProcess(0x100000 | 0x1000, False, os.getpid())
    if not runner_handle:
        raise ctypes.WinError(ctypes.get_last_error())
    runner = TrackedProcess(win, os.getpid(), runner_handle, "runner")
    report = {
        "schema": 1, "status": "prepared", "grant": args.grant,
        "suite": args.suite, "tests": list(tests),
        "next_owner": args.next_owner, "channel": CHANNEL, "speaker": "studio-main",
        "command": command, "cwd": str(gate_cwd), "artifacts": str(artifacts),
        "budgets_seconds": {"total_plan": TOTAL_SECONDS, "tests": TEST_SECONDS,
                            "terminal_cleanup": CLEANUP_SECONDS, "publication": PUBLISH_SECONDS},
        "runner": runner.record, "source_before": before,
        "stdout": str(artifacts / "flutter.stdout.log"),
        "stderr": str(artifacts / "flutter.stderr.log"),
        "processes": [], "taskkill": [], "errors": [],
        "descendant_tracking": "Toolhelp snapshots; retained exact-identity handles; short-lived children may escape observation",
    }
    if prior_report is not None:
        report.update(prior_report=str(prior_report),
                      result_scope="unapplied-formatting-proposal" if format_candidate else "remaining-six-gates-only",
                      full_final_pass=False, unresolved_prior_gate="format-core")
        if format_candidate:
            report["intent"] = "unapplied proposal, exact17 authorization unchanged"
    write_json(report_path, report)
    tracked: dict[int, TrackedProcess] = {}
    helpers: list[tuple[subprocess.Popen, TrackedProcess]] = []
    proc = None
    started = time.monotonic()
    test_deadline = started + TEST_SECONDS
    terminal_deadline = test_deadline + CLEANUP_SECONDS
    total_deadline = started + TOTAL_SECONDS
    gate_env = None
    if final_suite:
        gate_env = os.environ.copy()
        gate_env.update(MAIN_GATE_ARTIFACTS=str(artifacts), MAIN_GATE_GRANT=args.grant,
                        MAIN_GATE_DEADLINE_MONOTONIC=repr(test_deadline), MAIN_GATE_START_AT="format-main")
        gate_env.pop("MAIN_GATE_PRIOR_REPORT", None)
        if prior_report is not None:
            gate_env.update(MAIN_GATE_START_AT="format-candidates" if format_candidate else "analyze-main",
                            MAIN_GATE_PRIOR_REPORT=str(prior_report))
    try:
        with Path(report["stdout"]).open("ab", buffering=0) as stdout, Path(report["stderr"]).open("ab", buffering=0) as stderr:
            proc = subprocess.Popen(command, cwd=gate_cwd, env=gate_env, stdin=subprocess.DEVNULL,
                                    stdout=stdout, stderr=stderr, shell=False,
                                    creationflags=subprocess.CREATE_NO_WINDOW)
            root = track_child(win, proc, root_role)
            tracked[root.pid] = root
            report.update(status="running", launch_utc=utc_now(), root_pid=root.pid)
            report["processes"] = [item.record for item in tracked.values()]
            write_json(report_path, report)
            while time.monotonic() < test_deadline:
                discover_descendants(win, tracked, descendant_role)
                active = [item for item in tracked.values() if item.live()]
                report["processes"] = [item.record for item in tracked.values()]
                if not active:
                    break
                time.sleep(min(0.20, max(0.0, test_deadline - time.monotonic())))
            active = [item for item in tracked.values() if item.live()]
            if active:
                report["deadline_reached"] = True
                # The retained root is preferred; if it exited, only validated
                # retained descendants from this invocation may be targeted.
                targets = [root] if root.live() else active
                helpers.extend(taskkill_owned(win, targets, artifacts, report["taskkill"], terminal_deadline))
            while time.monotonic() < terminal_deadline:
                discover_descendants(win, tracked, descendant_role)
                active = [item for item in tracked.values() if item.live()]
                if not active and all(helper.poll() is not None for helper, _ in helpers):
                    break
                time.sleep(0.10)
            # Always await Popen explicitly, even after native-handle signalling.
            try:
                proc.wait(timeout=max(0.01, terminal_deadline - time.monotonic()))
            except subprocess.TimeoutExpired:
                report["errors"].append("Flutter root terminal exit could not be confirmed within cleanup budget")
    except (OSError, RuntimeError, ValueError, KeyboardInterrupt) as exc:
        report["errors"].append(f"{type(exc).__name__}: {exc}")
        if proc is not None and not tracked:
            # Popen may have succeeded before identity instrumentation failed.
            # Retry identity from its retained handle; never substitute an
            # unvalidated PID kill or a terminate-by-name operation.
            try:
                root = track_child(win, proc, root_role)
                tracked[root.pid] = root
                report["root_pid"] = root.pid
            except (OSError, RuntimeError, ValueError) as identity_error:
                report["errors"].append(f"Retained-handle identity retry: {identity_error}")
                report["untracked_created_process"] = {
                    "pid": proc.pid, "handle_value": str(int(proc._handle)),
                    "terminal_observed": False, "identity_unconfirmed": True,
                }
        if tracked:
            try:
                active = [item for item in tracked.values() if item.live()]
                helpers.extend(taskkill_owned(win, active, artifacts, report["taskkill"], terminal_deadline))
                if proc is not None:
                    proc.wait(timeout=max(0.01, terminal_deadline - time.monotonic()))
            except (OSError, RuntimeError, ValueError, subprocess.TimeoutExpired) as cleanup_error:
                report["errors"].append(f"Cleanup: {cleanup_error}")
        elif proc is not None:
            try:
                proc.wait(timeout=max(0.01, min(CLEANUP_SECONDS, terminal_deadline - time.monotonic())))
                report["untracked_created_process"].update(
                    terminal_observed=True, exit_code=proc.returncode, terminal_utc=utc_now())
            except subprocess.TimeoutExpired:
                report["errors"].append("Created process identity/terminal unresolved; manual HOLD required")
    finally:
        # No successfully created child means the host slot is already idle.
        # A created child with failed identity instrumentation stays on HOLD.
        terminal_confirmed = proc is None or bool(tracked)
        for item in tracked.values():
            try:
                terminal_confirmed = not item.live() and terminal_confirmed
            except OSError as exc:
                terminal_confirmed = False
                report["errors"].append(f"Terminal observation: {exc}")
        helper_terminal = True
        for helper, identity in helpers:
            helper.poll()
            helper_terminal = not identity.live() and helper_terminal
            if helper.returncode is not None:
                helper.wait()
        report["source_after"] = source_snapshot(source_paths)
        report["source_drift"] = changed_sources(before, report["source_after"])
        report["processes"] = [item.record for item in tracked.values()]
        report["flutter_exit_code"] = proc.returncode if proc is not None else None
        if final_suite:
            report["gate_exit_code"] = report["flutter_exit_code"]
            report["all_observed_gate_processes_terminal"] = terminal_confirmed
            report["format_candidates_report" if format_candidate else "final_gates_report"] = str(
                artifacts / ("format-candidates-report.json" if format_candidate else "final-gates-report.json"))
        report["all_observed_flutter_processes_terminal"] = terminal_confirmed
        report["taskkill_helpers_terminal"] = helper_terminal
        report["terminal_observation_utc"] = utc_now()
        report["elapsed_before_publication_seconds"] = round(time.monotonic() - started, 6)
        # Observation errors may hide an inaccessible descendant. A failed
        # launch is idle; any instrumentation error after launch fails closed.
        report["release_allowed"] = terminal_confirmed and helper_terminal and (
            proc is None or not report["errors"])
        report["status"] = "RELEASE" if report["release_allowed"] else "HOLD/UNRELEASED"
        report["test_result"] = (
            "PASS" if report["flutter_exit_code"] == 0 and not report["source_drift"]
            and not report.get("deadline_reached") and not report["errors"] else "FAIL_OR_INCONCLUSIVE"
        )
        write_json(report_path, report)
        continuation_note = (
            (f"Unapplied formatting proposal; exact17 authorization unchanged; prior failure: {prior_report}\n"
             if format_candidate else
             f"Remaining six gates only; prior format-core failure remains unresolved: {prior_report}\n")
            if prior_report is not None else "")
        message = (
            f"studio-main {report['status']} -> {args.next_owner}\n"
            f"Suite: {args.suite}\n"
            f"{continuation_note}"
            f"Grant: {args.grant}\n"
            f"{'Gate' if final_suite else 'Flutter'} terminal exit: {report['flutter_exit_code']}; result: {report['test_result']}\n"
            f"All observed {'gate' if final_suite else 'Flutter'} handles terminal: {terminal_confirmed}; taskkill helpers terminal: {helper_terminal}\n"
            f"Deadline cleanup: {bool(report.get('deadline_reached'))}; source drift: {report['source_drift']}\n"
            f"Exact PID/creation FILETIME/terminal report: {report_path}\n"
            f"Logs: {artifacts}\n"
            f"core HEAD before: {before.get('core_head')}; after: {report['source_after'].get('core_head')}\n"
            "This is a terminal observation of the exact invocation, not inferred from channel tags.\n"
        )
        fallback.write_text(message, encoding="utf-8")
        report["durable_message_file"] = str(fallback)
        try:
            send_command = trellis_command(fallback, args.next_owner)
            with (artifacts / "channel-send.log").open("ab", buffering=0) as log:
                sender = subprocess.Popen(send_command, cwd=PROJECT, stdin=subprocess.DEVNULL,
                                          stdout=log, stderr=log, shell=False,
                                          creationflags=subprocess.CREATE_NO_WINDOW)
                sender_identity = track_child(win, sender, "channel-publisher")
                report["publication"] = {"command": send_command, "process": sender_identity.record}
                try:
                    sender.wait(timeout=max(0.01, min(PUBLISH_SECONDS, total_deadline - time.monotonic() - 1.0)))
                except subprocess.TimeoutExpired:
                    report["publication"]["timeout"] = True
                    helpers.extend(taskkill_owned(win, [sender_identity], artifacts, report["taskkill"], total_deadline))
                    try:
                        sender.wait(timeout=max(0.01, total_deadline - time.monotonic()))
                    except subprocess.TimeoutExpired:
                        report["publication"]["terminal_unconfirmed"] = True
                sender_identity.live()
                report["publication"]["delivered"] = sender.returncode == 0
        except (OSError, RuntimeError, ValueError) as exc:
            report["publication"] = {"delivered": False, "error": str(exc)}
        for helper, identity in helpers:
            helper.poll()
            identity.live()
            if helper.returncode is not None:
                helper.wait()
        report["completed_utc"] = utc_now()
        report["elapsed_seconds"] = round(time.monotonic() - started, 6)
        report["within_110_second_plan"] = report["elapsed_seconds"] <= TOTAL_SECONDS
        write_json(report_path, report)
        for item in tracked.values():
            item.close()
        runner.close()
    print(str(report_path), flush=True)
    print(f"{report['status']}: {report['test_result']}", flush=True)
    return 0 if report["test_result"] == "PASS" and report["release_allowed"] else 1


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--suite", choices=tuple(TEST_SUITES), default="first", help="Focused test suite (default: first)")
    parser.add_argument("--grant", required=True, help="Exact explicit named scheduling grant; never inferred")
    parser.add_argument("--next-owner", default="Web338", help="Named host-slot recipient (default: Web338)")
    parser.add_argument("--prior-report", type=Path, help="Required original failed final-gate report for final-remaining/format-candidate")
    args = parser.parse_args()
    try:
        return run(args)
    except (OSError, RuntimeError, ValueError) as exc:
        print(f"REFUSED: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
