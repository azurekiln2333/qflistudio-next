# Parallel Git Clone and Progress

## 1. Scope / Trigger

Apply when changing Home clone tasks, `GitCloneService`, clone backends, the
`qfli_git` FFI bridge, or native release payloads. The product sources live in
the isolated Core and plugin repositories.

## 2. Signatures

- Core: `GitCloneProgress(stage, completed = 0, total = 0, receivedBytes = 0)`.
- Core stages: `preparing`, `connecting`, `receiving`, `resolving`, `checkout`,
  `registering`. The plugin exposes only the three measured native stages.
- `GitCloneService.clone(request, {cancellation, onProgress})` forwards an
  optional `void Function(GitCloneProgress)` observer to the selected backend.
- Native API 3 adds `qg_clone_with_progress(url, path, username, token,
  cancel_flag, progress, payload, out, err)`. Retain the legacy `qg_clone` export.
- Native callback: `void(int stage, uint32_t completed, uint32_t total,
  uint64_t received_bytes, void *payload)`. Stages 1, 2 and 3 mean receiving,
  resolving and checkout.

## 3. Contracts

- Home stores tasks by a stable increasing ID. Keep the clone action enabled
  while other clones run. Each task owns its cancellation token and name.
- Bound the scrollable task list by the available Home height. Keep every task
  reachable, including duplicate display names. Cancel all live tasks on disposal.
- Reserve destinations exclusively with `Directory.createTemp`. Each operation
  may clean up only its own destination. Preserve downloaded data when project
  registration fails. Registration writes `.qfli/project.json`.
- Use measured counts for percentages. `fraction` is null for nonpositive
  totals and otherwise clamps `completed / total` to `[0, 1]`. Do not invent
  network percentages. Send no URLs, credentials, stderr text or file paths.
- Limit routine progress to one report per 100 ms. Emit stage transitions,
  terminal counts and the final pending report immediately. The CLI uses
  `git clone --progress` and a single supervised stderr subscription.
- Every native clone owns its worker, callback and SendPort. The worker sends
  numeric lists followed by a null completion barrier on the same port. A
  successful Future waits for this barrier. Observer exceptions cannot change
  the clone outcome. Worker-start failures must not wait for a missing barrier.
- `NativeCallable.isolateLocal` is valid only while libgit2 callbacks run
  synchronously on the FFI calling thread. Keep it alive until clone returns.
  Use Stopwatch throttling because timers cannot run during synchronous FFI.
- Share the foreground `QfliGit.ensureInitialized` Future. Install the CA once
  before workers run. Workers call `qg_init(NULL)` so concurrent operations do
  not replace or free the process-wide TLS CA.
- Build mbedTLS with `MBEDTLS_THREADING_C` and `MBEDTLS_THREADING_PTHREAD`.
  Require those macros at the native CMake boundary and enable libgit2 threads.
- Disable cancellation during registration. Recheck cancellation after clone
  and immediately before metadata writes. Checkout cancellation may wait for
  libgit2 file writes, but the final result must still report cancellation.
- Freeze API 3 consistently in C, Dart, contract, payload lock and App staging.
  Preserve the exact source SHA and cloud run in native provenance. Pin the
  plugin artifact commit in both Core manifest and lock, then pin Core in App.

## 4. Validation & Error Matrix

| Condition | Required behavior |
| --- | --- |
| Two clones overlap | Distinct destinations, progress streams and tokens |
| One clone is canceled or fails | Siblings continue; only its owned path is cleaned |
| Observer throws | Clone outcome and cleanup remain unchanged |
| Native clone succeeds | Final progress arrives before the returned Future completes |
| No total exists | Indeterminate progress, without a fabricated percentage |
| Registration fails | Keep files and report the preserved path |
| Binding, contract or payload API differs | Reject the release |
| Runtime checks are cloud-only | Run local formatting and static analysis only |

## 5. Good / Base / Bad Cases

- Good: clone A is canceled while clone B completes and registers its project.
- Base: a connecting task uses an indeterminate bar until counts arrive.
- Bad: one `_cloneBusy` flag disables all other clone requests.
- Bad: every worker passes a CA filename and replaces shared TLS configuration.

## 6. Tests Required

- Native host smoke starts two HTTPS clones together and requires receiving
  progress from each. Native Dart tests use two local file clones and assert
  terminal checkout progress before success. Cover observer failure and
  cancellation isolation.
- Core cloud tests cover lifecycle phases, independent overlapping runners,
  cleanup ownership, registration failure, parser CR/LF chunks and throttling,
  duplicate task names, all-task scrolling and constrained height.
- Offscreen rows may already exist in ListView cache. Use `.hitTestable()` on
  the keyed cancel button when asserting visibility. A Row's center can be
  empty space without a hit target. A widget's existence alone proves no visibility.
- Before App publication, require plugin native-lock, host smoke, Dart checks,
  example iOS integration, Core checks and the App tag workflow. The App iOS
  gate must test the committed native payload, not a substituted local build.

## 7. Wrong vs Correct

Wrong: await `Isolate.run` and immediately close the progress ReceivePort.

Correct: after a successful worker result, await its same-port null barrier,
then close the ReceivePort and release the cancellation operation reference.
