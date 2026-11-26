# Final integration review

The four Pi workers implement the feature in Herdr workspace `w37`.
This checklist records confirmed findings while their files are still changing.
A finding closes only after a stable source review and permitted static checks.
No local tests, services, probes, builds or device tools may run.

## Desktop worker

- [x] D1: Route missing-companion resolution to the visible installation state.
      `desktop_companion_entry.dart` — `location == null` 走 `_MissingCompanionPage`（问题文案、已查路径、重新检测）。
- [x] D2: Mount the real AuthStore and sign-in callback through RemoteAccountScope.
      Root 接管 `studio/lib/main.dart` 与 `studio/lib/studio_tools_tab.dart`；桌面页不自行读取账号。
- [x] D3: Export and return ToolStreams.bindView; preserve the discovered source.
      `ToolStreams.bindView` 已导出并在返回对象里；sidecar 不再用 `tool_bind` 打开发现结果。
- [x] D4: Open Codex history through the Codex provider and decode turn.items.
      `openCodexThread` 按 `canAcceptInput` 选 `resume`/`read`，文本来自 `turn.items[]`。
- [x] D5: Send broadcasts only to authenticated sidecar clients.
      `broadcast()` 跳过 `!client.authed`。
- [x] D6: Use fileURLToPath for the Windows bundle-verifier CLI guard.
      `verify_companion_bundle.mjs` 使用 `fileURLToPath(import.meta.url)`。
- [x] D7: Fix process-supervisor imports and clean up failed socket startup.
      `../../services/process_supervisor.dart`；socket 连接失败取消子进程并删临时目录。
- [x] D8: Reuse or stop owned processes before reconnecting; fence stop/dispose.
      `_connect()` 先停旧句柄（失败保留所有权），spawn 前复查 generation，`stop()` 收集迟到子进程。
- [x] D9: Await owned-process cleanup on supported app-exit paths.
      `didRequestAppExit()` 等待 `stopAll()`；`detached` 兜底；`stopAll()` 逐个停止不互相阻断。
- [x] D10: Use the target Node runtime for npm lifecycle subprocesses.
      目标 Node 执行随包 npm CLI，并把其 bin 目录前置 `PATH`，`finally` 还原（Root 修复保留）。
- [x] D11: Keep desktop history read-only where provider control is unavailable.
      Codex `canOpen: true`，只读用 `read()`；Herdr/Claude 一律只读，前端隐藏输入。

## Mobile worker

Reviewed in `reports/pi-mobile.md`; static checks recorded in
`reports/pi-mobile-progress.md` (2026-11 session, core worktree
`remote/remote-account-binding-core`).

- [x] M1: Bind directly from a short code without consuming legacy pairing.
  `RelayAccountApi.bind` defaults to `POST /api/v1/devices/bindings` with only
  `{pair_code}` and reads the id back from the response. The known-id route is
  opt-in. The devices page never calls `pairWithCode` first. The bind response
  carries no presence, so `bindDevice` answers with the row from the refresh it
  performs afterwards — an online computer therefore connects on first bind.
- [x] M2: Return refreshed credentials with matching expiry metadata.
  `credentialsFor` returns the stored `RelayCredentials` after the refresh, so
  token and `accessExpiresAt` come from the same response. An expired leftover is
  never handed out.
- [x] M3: Fence restore, save, reset, refresh, bind and revoke by identity
  generation. `_AccountFence` carries identity + epoch + relay key + relay input.
  Every await, and every side effect around it, re-checks it. `bindDevice`
  re-checks after its trailing `refreshDevices`, and `revokeDevice` returns
  `false` instead of editing the new list.
- [x] M4: Serialize secure-backend operations and reject stale writes/clears.
  `RelayCredentialStore` versions every mutation, discards a stale `load`, and
  re-asserts the current value after a write that lost the race. `clearIf` drops
  only the value the caller still owns. `close()` leaves the backend untouched.
- [x] M5: Disconnect the previous account immediately on identity change.
  `_onAuthChanged` is fully synchronous up to `onIdentityLost`, and the page only
  unpairs when `controller.isAccountBound`. Leaving the page now tears down its own
  account link even when the controller was injected, while a manual pairing is
  left to the caller.
- [x] M6: Cover slow storage, A-to-B-to-A, relay changes and shared refresh.
  35 cases in `test/remote_control/account_test.dart`. Written for cloud CI and
  **not executed** in this session (static analysis only).
- [x] M7: Keep manual pairing and existing session/approval paths reachable.
  The account entry is additive on both screens, the devices page always offers
  the manual route, account links refuse to fall back to a device secret, and a
  manual pairing is no longer dropped on sign-out.

## Relay worker

- [ ] R1: Require a fresh grant for every QFLI-origin refresh.
- [ ] R2: Serialize first binding, historical owner and account-managed transition.
- [ ] R3: Fence legacy authorization, token caches and pending WebSocket joins.
- [ ] R4: Implement the code-only binding route with one consent consumption.
- [ ] R5: Fix fake-database query coverage and seed race tests before waiting.
- [ ] R6: Remove the legacy OAuth device-flow binding bypass.
- [ ] R7: Backfill account-managed markers from active and revoked bindings.
- [ ] R8: Make binding/token revocation atomic and close connections after commit.
- [ ] R9: Populate device name, platform and last-seen from authenticated agents.

## Coordinator

- [ ] C1: Review final reports and re-review the stable source.
- [ ] C2: Synchronize the five Relay files with truthful draft provenance.
- [ ] C3: Verify installer staging paths and the shared Core dependency.
- [ ] C4: Run permitted static, syntax, format and document checks.
- [ ] C5: Map acceptance criteria to code, CI tests and device checks.
- [ ] C6: Record cloud CI and real-device validation as unexecuted.
- [ ] C7: Prepare the exact commit plan without committing or publishing.
