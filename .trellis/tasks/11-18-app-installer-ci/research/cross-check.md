# Installer workflow cross-check

Date: 2026-11-18

## Static checks

| Check | Result | Evidence |
| --- | --- | --- |
| Workflow syntax | PASS | `actionlint` exited 0 |
| Bash run blocks | PASS | `check_run_blocks.py` parsed 49 blocks; 0 failed |
| Non-Bash block | REVIEWED | 1 Windows `cmd` block is intentionally skipped |
| Shell scripts | PASS | Git Bash `bash -n` passed for CI scripts and OHOS setup |
| Python scripts | PASS | `python -m py_compile` passed for both CI helpers |
| Action allowlist | PASS | Only SHA-pinned checkout, cache, setup-node and upload-artifact, plus local composites |
| Local Flutter build | NOT RUN | All compile and dependency checks go to GitHub Actions |

## AC1 to AC7 review

AC1 workflow dispatch exposes `flutter_version` and `core_ref`.

AC2 each target stages its package with `BUILD_INFO.txt`, `SHA256SUMS` and `LICENSE`.

AC3 and AC4 use only the pinned Node 24 action allowlist. Cloud annotations remain pending.

AC5 each job contains a platform-specific architecture or ABI assertion. These assertions remain pending until the cloud build.

AC6 official jobs log the resolved Flutter version. OHOS logs its pinned fork version. Cloud execution remains pending.

AC7 OHOS sets `NODE_HOME` from setup-node and requires `v24.14.1`. Cloud execution remains pending.

## Fix applied

The shared setup action originally called `flutter config --no-enable-ohos` for upstream jobs. Upstream Flutter has no such option. Commit `075fe05` removed that call.

## Remaining gate

Push and the GitHub Actions run are required. Verify every job conclusion, the eleven artifact names, artifact contents, and the absence of the Node.js 20 deprecation annotation before merging into `main`.
