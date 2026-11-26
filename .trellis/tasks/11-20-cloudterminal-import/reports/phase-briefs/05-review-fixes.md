Active task: D:/MyNewProjects/qflistudio/.trellis/tasks/11-20-cloudterminal-import

You are the authorized Pi implementer for review fixes R1-R4. Implement directly in this fresh Pi session. Use the default configured Pi model. Do not spawn another implementation or review agent. The coordinator explicitly authorized these fixes and their regression tests. Do not stop at a plan.

This brief narrows the common brief. WRITE ALLOWLIST ONLY:
- D:/MyNewProjects/_wt/cloudterminal-import/work/qfli_studio_core/lib/remote_control/**
- D:/MyNewProjects/_wt/cloudterminal-import/work/qfli_studio_core/test/remote_control/**
- D:/MyNewProjects/_wt/cloudterminal-import/work/qfli_studio_core/test/support/**
- D:/MyNewProjects/qflistudio/.trellis/tasks/11-20-cloudterminal-import/reports/**

Do not edit workflows, pubspec files, vendor, companion, app worktree, fixtures, source copy, original source, main checkouts, or any other location. A separate Pi owns CI workflows now. The coordinator owns Git commits and pushes and may commit the existing snapshot while you work. Do not stage, commit, reset, restore, clean, stash, switch branches, push, or tag. Read-only Git uses git --no-optional-locks. Do not operate Herdr, start a live agent, pair with a computer, or change other workers.

No local tests, temporary test probes, builds, installs, emulators, VMs, WSL, Docker VMs, adb, hdc, or device commands. You may run formatting, targeted Dart analysis with the existing dependencies, Chinese prose lint, and git diff --check. Put regression tests in the tree for cloud CI. Do not claim tests pass unless a real cloud result exists.

Read reports/remote-review.md first. Then read PRD/design and applicable specs from implement.jsonl. Apply D:/MyNewProjects/qflistudio/.agents/skills/trellis-before-dev/SKILL.md and the read/check portions of trellis-check/SKILL.md. The explicit no-local-tests rule overrides generic skill test steps. Inspect the targeted implementation and existing six-suite test port. Create reports/phase-05-review-fixes.md early with the intended boundary, then edit code.

Required fixes:

R1: Separate Claude structured sessions from Herdr terminal behavior. HomeScreen must not pass Herdr into Claude sessions. SessionScreen must independently guard Herdr setup/follow/resume/dispose/input/composer actions by terminal kind so direct construction is safe too. Claude text must always use RemoteController.send for its own session. Preserve PTY raw input and Herdr input semantics.

R2: Implement actual route ownership for live pane watching. Each pane-capable route gets a unique lease/token. Guard set/resume/follow/release against that token. Claim before deferred initialization. Old route disposal, old listeners, and old deferred callbacks cannot clear or reassert a newer route's watch. Protect same-pane route replacement and A-to-B-to-A too. Keep the remembered pane distinct from active ownership. Keep watchdog reference counting distinct. Reconnect only restores a currently owned subscription. Coordinate pane-row selection with ownership. Do not merely compare pane IDs or delay disposal.

R3: Add a visible return-to-Studio action in the module. Capture/inject host navigation outside the inner navigator. Preserve internal back behavior. Support paired and unpaired states and narrow/wide widths. Closing the module must release locally owned resources without sending close_session. The injected-controller caller-ownership contract should remain explicit.

R4: Fix ownership in the two Codex TestRemoteApp widget tests. The source CloudTerminalApp DID call widget.controller.dispose at source lib/main.dart:52-55. The target page intentionally does not dispose an injected controller. The inline test controllers currently leak. Retain them and add cleanup or use an explicitly owning test shell. Correct the false source-ownership comment in test/support/remote_control_app.dart and the phase-04a report without fabricating execution evidence.

Required regression coverage in test/remote_control/remote_module_regression_test.dart (helpers can live in allowed test/support paths):
- Claude session with an active focused and remembered Herdr pane: submit text to the Claude session only, no Herdr text/Enter/prompt action. Cover HomeScreen route opening and direct SessionScreen construction.
- Actual Navigator route transitions with animations retained: new B watch survives old A disposal. Include two routes for the same pane, A-to-B-to-A, stale deferred callbacks, terminal-to-Claude, and final owner disposal. Assert wire requests and selection; do not only test token internals.
- A real host home pushes RemoteComputerPage as a second route. The visible exit returns to host in paired/unpaired and narrow/wide cases. Account for injected versus owned controller cleanup. Assert no close_session during local exit.
- Ensure the corrected Codex tests clean up their controllers and sockets. Add meaningful closure assertions where appropriate.

Do not weaken existing assertions, silence errors, skip tests, or replace existing suites. Use the current fake relay and real widgets where possible. Keep tests deterministic. Existing tests call watchPane/resumeWatching/suspendWatching directly; update them coherently if the public test-facing contract changes. Keep the lifecycle contract understandable rather than adding a second competing state machine.

Finish report requirements:
- Map each R1-R4 to concrete changed paths and behavior.
- Explain the final ownership contract and how late route callbacks are rejected.
- List regression names and what each proves.
- State exact static commands/results and that cloud runtime execution is still required.
- List any remaining defect or limitation honestly.
- Write reports/phase-05-review-fixes.done only after the final report and all required implementation/test edits exist. The done file means ready for independent review, not release acceptance.

Use absolute task/report paths because the process cwd is the core worktree. Keep final response concise. Perform real edits now.
