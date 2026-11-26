# Java foreground interop release review

Worktree: `D:/MyNewProjects/_wt/release-v5.0.5/qfli_java`

Branch: `release/studio-v5.0.5-interop`; base: `18b8c661c3681756a85bce8666fbcc280d033117`.

## Change boundary

Studio's current foreground transport sends a read-granted ZIP URI and a session
token. The previous Java revision expected an unshared payload directory and
sent multiple result callbacks. Transplant the existing foreground receiver and
its JDK preparation/idle-page dependencies into the isolated release worktree.
Retain explicit foreground requests only. Do not register or copy the unfinished
background runner, local credentials, generated native binaries, or root work.

## Files for review

- `ohos/entry/src/main/ets/interop/InteropReceiver.ets`: ZIP preparation, token
  validation and callback, actual extracted JDK layout, one aggregated result.
  Retained earlier reviewer corrections for integral timeout, byte-counted stdin,
  NUL/control-character checks and callback action validation.
- `ohos/entry/src/main/ets/interop/InteropAbility.ets`: delay cold-start work until
  window-stage creation, handle a reused singleton, keep pending requests busy,
  use the plain idle page, release the owned transient allowance, use sequence 1
  for refusal and preserve the active request during busy refusal. Removed source
  URI diagnostic logging. No background receiver was copied.
- `ohos/entry/src/main/ets/entryability/JavaBridge.ets`: export shared `prepareJdk`
  and `JdkLayout`; retry preparation after failure.
- `ohos/entry/src/main/ets/pages/InteropIdle.ets`: plain ArkUI status page without
  a Flutter engine dependency.
- `ohos/entry/src/main/module.json5`: foreground request action registration only.
- `ohos/entry/src/main/resources/base/profile/main_pages.json`: idle page registry.
- `test/native_entry_ability_test.cjs`: preserve the local-only entry channel tests
  and update the exact page registry for the plain interop page.
- `.trellis/spec/frontend/native-startup.md`: document separate local entry and
  foreground interop page ownership, ZIP/token contract and terminal aggregation.

## Validation performed

- Static comparison with the pinned release Studio `StudioInterop.ets` and core
  `interop_arkts_contract_test.dart`: protocol, bundles, action, ability, URI,
  session token, sequence 1, limits and one terminal event are consistent.
- `git diff --check` passed.
- `node --check test/native_entry_ability_test.cjs` passed; this parses syntax only.
- No local test, build, app launch, device connection or service execution.
- Rechecked root Java against `java-interop-source-baseline.json`: HEAD, index
  hash, recorded source-file hashes and full Git status are unchanged.
- Cloud tests and actual ArkTS/HAP validation remain required. Core's source
  contract tests do not compile or execute this receiver.

## Foreground runtime fixes completed in the release worktree

1. `OutputTail.read` drains the file size observed at the start of each call,
   honors actual short-read byte counts, and retains a streaming UTF-8 decoder.
   Finalization drains the remaining bytes and flushes only after native exit.
2. Compilation and execution now share a deadline established before JDK
   preparation. Expired preparation never starts a child. Compilation timeout
   cancels/reaps the compiler and cannot start the program afterward.
3. Timeout requests cancellation once, then polls until the child is reaped or
   a five-second grace expires. Callback and deletion follow actual reaping.
   An unreaped child raises a truthful internal error and retains scratch.

Two additional files are ready for the same Java commit:

- `test/interop_receiver_test.cjs`: eight behavioral host regressions execute the
  actual receiver against system API doubles. Coverage includes tails larger
  than 64 KiB, split UTF-8, short reads, final decoder flush, compiler timeout,
  shared compile/run budget, delayed and failed reaping, and compile-only/failure.
- `.github/workflows/interop-check.yml`: GitHub push checks on main/release
  branches plus manual dispatch. Uses pinned Node 24 actions and TypeScript 4.9.5.

Cloud commands from the Java checkout:

```bash
npm install --prefix "$RUNNER_TEMP/java-interop-tools" --no-save --ignore-scripts --package-lock=false typescript@4.9.5
export QFLI_TYPESCRIPT="$RUNNER_TEMP/java-interop-tools/node_modules/typescript"
node --test test/native_entry_ability_test.cjs test/interop_receiver_test.cjs
```

Static checks passed: `git diff --check`, `node --check` for both host tests and
TypeScript parse diagnostics for the receiver (zero). No test suite, test probe,
build or production runtime was executed locally. No commit or push was made.
Cloud execution and actual ArkTS/HAP validation remain pending. System doubles
do not establish native process, file-URI, foreground handoff or device behavior.
