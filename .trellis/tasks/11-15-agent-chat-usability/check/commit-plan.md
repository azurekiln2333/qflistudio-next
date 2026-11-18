# Proposed work commit

Repository: `D:/MyNewProjects/_wt/integration/qfli_studio_core`
Branch: `rework/integration`
Baseline: `e718653`

## 1. fix(workbench): unify sidebar and stabilize agent conversations

Use one sidebar card and header for Files and Sessions with contextual actions.
Keep ordinary directory selection scoped to browsing. Add selected projects to
saved workspaces without replacing membership or editor identity.

Deduplicate session opens and read history without repeated full-file work.
Preserve scroll position, independent drafts, source text and attachments across
message actions, successive sends, retries and reopen. Balance composer controls.

### Exact paths

- `.trellis/spec/frontend/embedded-agent.md`
- `.trellis/spec/frontend/index.md`
- `.trellis/spec/frontend/saved-workspaces.md`
- `lib/chat/chat_transcript.dart`
- `lib/chat/composer_card.dart`
- `lib/editor/agent/editor_sidebar_tabs.dart`
- `lib/editor/agent/session_list_view.dart`
- `lib/editor/editor_page.dart`
- `lib/editor/file_explorer.dart`
- `lib/session/agent_session.dart`
- `lib/shell/workbench_agent_pane.dart`
- `lib/vibe_coding/vibe_agent_facade.dart`
- `lib/workspace/workspace_store.dart`
- `test/agent_hub_test.dart`
- `test/agent_message_view_metadata_test.dart`
- `test/agent_session_test.dart`
- `test/chat_composer_card_test.dart`
- `test/chat_message_actions_test.dart`
- `test/chat_transcript_position_test.dart`
- `test/editor_agent_embed_test.dart`
- `test/editor_project_browse_semantics_test.dart`
- `test/vibe_agent_facade_test.dart`
- `test/workbench_agent_pane_test.dart`
- `test/workspace_add_members_test.dart`
- `test/workspace_project_switch_test.dart`
- `tool/preview_composer_card_test.dart`

`embedded-agent.md` is intentionally included. The repository ignores new spec
files globally, so this one path requires explicit `git add -f`; the other paths
use explicit `git add`. Do not stage all files and do not change ignore rules.
The preview helper is retained as the reproducible source of the reviewed images.

## Unrecognized / excluded changes

No unrecognized dirty paths in the active core worktree.

The main app repository is outside this work commit. Its existing dirty paths
are recorded below for review. Task-local reports remain available there for the
later Trellis archive/journal step; they are not mixed into the core commit.
No edits in the inactive sibling core are included.

```text
 M .cnb.yml
 M .trellis/spec/frontend/index.md
 M .trellis/spec/frontend/interop.md
 M .trellis/tasks/11-01-ohos-app-interop/check.jsonl
 M .trellis/tasks/11-01-ohos-app-interop/design.md
 M .trellis/tasks/11-01-ohos-app-interop/implement.jsonl
 M .trellis/tasks/11-01-ohos-app-interop/implement.md
 M .trellis/tasks/11-01-ohos-app-interop/prd.md
 M .trellis/tasks/11-01-ohos-app-interop/task.json
 M .trellis/tasks/11-02-compliance-2026-11/task.json
 M .trellis/tasks/11-02-fix-test-suites/task.json
 M android/.gitignore
 M android/app/build.gradle.kts
 M docs/previews/profile-dark.png
 M docs/previews/profile-light.png
 M docs/previews/settings-light.png
 M lib/main.dart
 M ohos/build-profile.json5
 M ohos/entry/src/main/ets/components/HuaweiQuickLoginPlatformView.ets
 M ohos/entry/src/main/ets/entryability/EntryAbility.ets
 M ohos/entry/src/main/ets/interop/InteropBridgeAbility.ets
 M ohos/entry/src/main/ets/interop/StudioInterop.ets
 M pubspec.lock
?? .trellis/tasks/11-01-ohos-app-interop/research/background-9900002-official-20261109.md
?? .trellis/tasks/11-01-ohos-app-interop/research/background-baseline-20261105.json
?? .trellis/tasks/11-01-ohos-app-interop/research/background-design-20261105.md
?? .trellis/tasks/11-01-ohos-app-interop/research/background-receiver-fix-20261109.md
?? .trellis/tasks/11-01-ohos-app-interop/research/device-debug-20261105.md
?? .trellis/tasks/11-01-ohos-app-interop/research/device-debug-20261109.md
?? .trellis/tasks/11-01-ohos-app-interop/research/harmony-cross-app-survey-20261110.md
?? .trellis/tasks/11-01-ohos-app-interop/research/pad-interop-validation-20261109.md
?? .trellis/tasks/11-01-ohos-app-interop/research/pi-C-20261109.md
?? .trellis/tasks/11-01-ohos-app-interop/research/pi-D-20261109.md
?? .trellis/tasks/11-01-ohos-app-interop/research/pi-a-20261109.md
?? .trellis/tasks/11-01-ohos-app-interop/research/pi-a-20261110.md
?? .trellis/tasks/11-01-ohos-app-interop/research/pi-b-20261109.md
?? .trellis/tasks/11-01-ohos-app-interop/research/pi-brief-20261109.md
?? .trellis/tasks/11-01-ohos-app-interop/research/qfli_snap.jpeg
?? .trellis/tasks/11-01-ohos-app-interop/research/studio-sender-20261109.md
?? .trellis/tasks/11-12-agents-workbench/
?? .trellis/tasks/11-15-agent-chat-usability/
?? .trellis/tasks/archive/2026-11/11-15-editor-topbar-navigation/check.jsonl
?? .trellis/tasks/archive/2026-11/11-15-editor-topbar-navigation/implement.jsonl
?? .trellis/tasks/archive/2026-11/11-15-editor-topbar-navigation/screens/
?? .trellis/tasks/archive/2026-11/11-15-terminal-bootstrap/
?? Roboto_Mono.zip
?? android/gradle/wrapper/gradle-wrapper.jar
?? android/gradlew
?? android/gradlew.bat
?? azurekiln-qfli-server/bike.html
?? azurekiln-qfli-terminal/
?? docs/compliance/2026-11-整改任务书.md
?? ohos/entry/src/main/ets/interop/StudioBackgroundInterop.ets
?? output/
?? screenshots/
?? scripts/test-ohos-background-bridge.cjs
?? scripts/test-ohos-huawei-login.cjs
?? tool/agent_workbench_device.md
?? 新UI.png
?? "新增APP - 全国互联网安全管理服务平台.html"
?? "新增APP - 全国互联网安全管理服务平台_files/"
?? 旧UI.png
?? 旧icon.png
```

## Validation

- 39 sidebar/workspace tests passed after fixing fixture async waiting.
- 200 storage/runtime/message/composer/transcript tests passed on the final code.
- Full core `flutter analyze --no-pub`: no issues.
- `git diff --check`: passed.
- OHOS debug HAP rebuilt and replacement installation succeeded.
- Device launch remains unverified: screen locked, error 10106102.

## Execution gate

Approved by the user and executed as `fd1f5f4479cd60083cec871e3553ba9f3449dd56`. The exact 26 paths were
verified before committing. All three explicit spec paths required `git add -f`
because their parent is ignored. No ignore rules were changed. The active core
worktree is clean. No remote push or tag was executed. Use the existing
finish-work workflow for archive/journal bookkeeping.
