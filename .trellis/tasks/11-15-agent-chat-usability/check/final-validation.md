# Final verification — 2026-11-16T00:51:28

## Code and behavior

Active core: `D:/MyNewProjects/_wt/integration/qfli_studio_core`, branch `rework/integration`, baseline `e718653`.
The app resolves that checkout through `.dart_tool/package_config.json`.

- Files/Sessions share the original card and header; actions follow the section.
- Ordinary project selection changes browsing only. Workspace selection adds
  multiple projects and preserves identity, member order, missing members and
  editor session state.
- Concurrent opens share one facade and listener chain. Reverse JSONL reading
  joins byte blocks once, avoids decoding canonical history during paging, and
  falls back to the newest valid snapshot after malformed records.
- Message actions copy, prepare an editable draft, or resend through the existing
  send path. Independent drafts and attachment paths are preserved.
- Transcript paging uses a stable sliver center for variable-height prepends.
- Composer spacing and touch targets cover narrow layouts and enlarged text.

## Final review fixes

The new workspace picker fixture could deadlock when `load(force: true)` was
awaited in `runAsync` while an earlier editor write still needed fake-time
microtasks. The fixture now pumps both zones until the queued refresh completes.
All 39 sidebar/workspace cases pass. Two test analyzer warnings were also fixed.

Four new regression assertions failed before the metadata fix:

1. An explicit empty source became null after JSON round trip.
2. Attachment-only edit/resend reconstructed text from its display summary.
3. A later send removed an earlier message's live source and attachment metadata.
4. The facade silently skipped attachment-only sends.

The final implementation retains metadata per controller message index,
distinguishes null from empty source text, and sends attachment-only requests.
The regressions cover live views, retries and reopened persisted history.
See `metadata-regression-before.log` and `final-behavior-tests.log`.

## Checks

- `editor_project_browse_semantics_test.dart`,
  `workspace_project_switch_test.dart`, `editor_agent_embed_test.dart`,
  `workspace_add_members_test.dart`: **39 passed**.
- `agent_session_test.dart`, `agent_hub_test.dart`, `vibe_agent_facade_test.dart`,
  `agent_message_view_metadata_test.dart`, `chat_composer_card_test.dart`,
  `composer_state_test.dart`, `chat_transcript_test.dart`,
  `chat_message_actions_test.dart`, `chat_transcript_position_test.dart`,
  `workbench_agent_pane_test.dart`: **200 passed** on the final code.
- Full core `flutter analyze --no-pub`: **no issues**.
- `git diff --check`: passed.
- Prior worker checks are recorded in their reports; these are not counted again.
- No temporary `zz_*` probes remain in core `test/` or `tool/`.
- Reviewed existing composer previews: 320/360/424/600 widths, light/dark,
  enlarged text and enabled send. These are desktop widget renders.

## Build and deployment

Command: Git Bash `tool/build_studio_hap.sh --debug`.
Result: **BUILD SUCCESSFUL**, FlutterTask executed. Native dependency and app
API warnings remain in `final-ohos-build.log`; they did not prevent the build.

HAP: `D:\MyNewProjects\qflistudio\ohos\entry\build\default\outputs\default\entry-default-signed.hap`
Bytes: 173891797
SHA-256: `2e0daf9443bb866f9010300887f1a5beca828e241c48266cd919e3a40797d7f7`
The HAP's `kernel_blob.bin` contains the final `_userInputs` implementation.

Device: `192.168.68.207:46551`
Package: `com.azurekiln.qflistudio`
Installed version: `5.0.1` / 5000001
UID before and after replacement: 20020380.
Installation: `hdc install -r` reported **install bundle successfully**.
No uninstall or data-clear command was used.

Launch: `aa start -a EntryAbility -b com.azurekiln.qflistudio` failed with
**10106102** because the screen is locked. Do not claim on-device UI acceptance
or measured device performance. The user can open the updated app after unlock.

## Commit state

User-approved work commit: `fd1f5f4479cd60083cec871e3553ba9f3449dd56`.
Message: `fix(workbench): unify sidebar and stabilize agent conversations`.
The active core worktree is clean. No remote push or tag was executed.
The exact 26-path plan is in `commit-plan.md`. Existing main-app changes remain
excluded and are recorded in `app-status-excluded.txt`.
