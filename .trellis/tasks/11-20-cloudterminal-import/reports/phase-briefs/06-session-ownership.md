Active task: D:/MyNewProjects/qflistudio/.trellis/tasks/11-20-cloudterminal-import

You are the authorized Pi implementer for R5, the same-session subscription lifecycle race found during independent review. Implement directly in a fresh default-model Pi session. Do not spawn other agents. Run only after phase 05 stops editing. Read the final phase-05-review-fixes.md report and inspect its resulting code before changing it. The coordinator explicitly authorized this follow-up as part of the migration lifecycle work.

WRITE ALLOWLIST ONLY:
- D:/MyNewProjects/_wt/cloudterminal-import/work/qfli_studio_core/lib/remote_control/**
- D:/MyNewProjects/_wt/cloudterminal-import/work/qfli_studio_core/test/remote_control/**
- D:/MyNewProjects/_wt/cloudterminal-import/work/qfli_studio_core/test/support/**
- D:/MyNewProjects/qflistudio/.trellis/tasks/11-20-cloudterminal-import/reports/**

Do not edit workflows, pubspec, vendor, companion, app worktree, fixtures, source copy, original source, main checkouts, or other workers. No stage/commit/push/tag/reset/restore/clean/stash/branch switching. The coordinator owns commits and cloud validation. Read-only Git uses git --no-optional-locks. Do not control Herdr, start runtime agents, or pair a device.

No local tests, test probes, builds, installs, emulators, VMs, WSL, Docker VMs, adb, hdc, or device commands. Allowed: formatting, targeted analysis with existing dependencies, Chinese prose lint, and git diff --check. Regression tests must be written for cloud CI, not executed locally.

Read PRD/design, reports/remote-review.md, phase 05 report, applicable specs from implement.jsonl, and trellis-before-dev/trellis-check skills before editing. Explicit scope and validation constraints override generic skill workflows. Write reports/phase-06-session-ownership.md early with the behavior gap and intended files.

R5 evidence before phase 05:
- RemoteController held `_subscribed` as Set<String> at state/remote_controller.dart:133.
- SessionScreen.initState called subscribe(view.id); dispose called unsubscribe(view.id).
- HomeScreen._open popped the previous inner session route and immediately pushed a new route.
- Opening the same PTY or Claude session again can mount new route B before old route A finishes its transition. B subscribes id S, then A disposes and unconditionally removes S and sends unsubscribe(S). B's output stops and reconnect no longer restores it.

Required behavior:
- Track session subscription ownership or reference counts at the controller boundary. Old route disposal cannot cancel a live owner of the same session ID.
- Acquire ownership synchronously before any subscription await, and release the exact owner idempotently. Retain owned sessions through reconnect. Only final owner release removes reconnect state and sends unsubscribe. Explicit closeSession/unpair/dispose must clear ownership consistently.
- Preserve backlog afterSeq behavior, sequence deduplication, agent-restart handling, and explicit session-close semantics.
- Do not use a global delay or suppress all unsubscribe traffic. Do not merely prevent clicks on the currently selected session; the underlying ownership contract must be safe.
- Keep the Herdr lease behavior from phase 05 intact. Its single selected pane and per-session subscriptions have distinct ownership semantics; use a clear model for each.

Required regressions:
- Animated overlapping routes for the SAME terminal session: B subscribes before A disposes; after A disposal output still reaches B and no final unsubscribe has been sent.
- Same case for Claude structured events.
- A-to-B-to-A where A is the same session ID but a new route instance.
- Final owner release sends one unsubscribe and removes reconnect ownership; double release is harmless.
- Reconnect during overlap restores the remaining owned session from lastSeq without duplicate events.
- Failure/disposal while subscribe is pending cannot resurrect a released session or cancel a newer owner.
- Client/module exit does not close remote desktop sessions.

Write the focused regressions in test/remote_control/session_ownership_test.dart. Use actual widgets/Navigator transitions and fake wire assertions for the route regression. Controller-only tests may complement it. Update existing tests coherently; do not weaken assertions or skip suites.

Read reports/phase-06-review-followup.md if it exists: it may contain final independent phase-05 review findings to fix in the same allowed module scope.

Finish with reports/phase-06-session-ownership.md plus reports/phase-06-session-ownership.done. Map every fix to tests and exact static check results. State that cloud execution is required. A done file means ready for independent review, not accepted/released.
