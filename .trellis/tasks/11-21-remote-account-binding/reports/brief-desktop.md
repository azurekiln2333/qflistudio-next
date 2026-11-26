Active task: D:/MyNewProjects/qflistudio/.trellis/tasks/11-21-remote-account-binding

You are pi-desktop, the already-dispatched implement worker. Implement now; do not stop at research or spawn workers. The user explicitly authorized this task and these four existing Pi sessions in Herdr workspace w37. Read prd.md, design.md, implement.md, implement.jsonl, research/implementation-contract.md, and your desktop/platform research. Apply trellis-before-dev from the main project. The original CloudTerminal workspace is read-only.

WRITE ALLOWLIST:
- D:/MyNewProjects/_wt/remote-account-binding/studio/lib/studio_tools_tab.dart and its focused tests.
- D:/MyNewProjects/_wt/remote-account-binding/studio/companion/**, relevant scripts and CI for companion bundling.
- D:/MyNewProjects/_wt/remote-account-binding/core/lib/remote_control/desktop/** and desktop_remote_page.dart (new files), plus matching tests.
- This report: reports/pi-desktop.md; progress: reports/pi-desktop-progress.md.

pi-mobile owns core app.dart, remote_control/account/**, remote_computer_page.dart, state/remote_controller.dart, and phone pages. Do not edit those files, core pubspec, core exports, or core auth/services. Import your new desktop page directly from the Studio tools tab. pi-mobile will supply a global account scope around core app.dart. Your desktop page can stay independent of account services. If a common file needs editing, report it to the coordinator. Do not overwrite existing work.

Deliver the PC requirements, not just CLI improvements: Windows/macOS/Linux Studio must have a 本机配对 page, display address + one-time code + countdown + copyable URI + QR, refresh code, offline state, and show actual Herdr/Claude/Codex sessions. Reuse the companion sidecar and the migrated session widgets/protocol. Inspect its existing IPC client/controller; avoid a second MaterialApp or fake sessions/counts. Do not show secrets. Keep original remote client entry for connecting other computers. Runtime/process lifetime must follow ProcessSupervisor; closing a view must not silently kill persistent desktop sessions.

Keep macOS sandbox. If sandbox prevents starting Node, provide a real supported external companion launch plus a safe loopback attachment path. Do not claim three-platform GUI completion if only Windows can attach. Agent may be bundled outside app; document and implement actual discovery from installed bundle, not a source-checkout-only absolute path. Preserve platform parity and existing approvals.

Fix CLI link printing as fallback and Windows helper copy-link/dead pairing navigation/false paired count where scoped. Five relay-core synchronized files belong to pi-relay; do not independently edit relay.ts/shared protocol mirrors. If new statistics need a core change, write an explicit coordinator request with required getter rather than weakening hash gate.

Validation: write meaningful regression tests and CI hooks. Preserve the prior no-local-tests/builds restriction: local formatting, focused static analysis, syntax and diff checks only. No local test suites, probes, services, emulators, Docker, WSL, adb or hdc. No credentials, no production service calls. No commit/push/merge/reset/restore/clean/stash. No installs into original workspaces or global settings. No secrets in output.

Record short progress as code lands. At completion report changed paths, exact static commands/results, unrun cloud/device checks, acceptance coverage and open integration needs. Continue until code is ready, not just a plan.
