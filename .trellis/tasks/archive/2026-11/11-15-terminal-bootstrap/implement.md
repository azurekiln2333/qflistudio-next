# Implementation

1. Research existing script, Compose, tests and release pipelines (done).
2. Delegate to four user-selected existing pi panes in qflistudio:
   - pi A owns deployment/bootstrap.sh: CLI, source staging, defaults, port, delegation and updater lifecycle.
   - pi B owns docker-compose.yaml, .env.example, scripts/check-deployment.mjs and deployment-config tests: port and optional updater contracts.
   - pi C owns new bootstrap behavioral regression tests and test/bootstrap-upgrade.sh; coordinate expectations with A.
   - pi D owns README/docs changes and release pipeline audit; do not publish or modify CI without a concrete defect.
3. Main agent integrates, checks security/rollback, tests Linux shell behavior and runs node scripts/ci-common.mjs verify.
4. Perform full-scope review, record evidence and limitations, conventional commit, push main and annotated patch tag to github/cnb.
5. Inspect CI runs and image publishing for the pushed revision; fix regressions within scope.

No worker commits or pushes. Workers edit disjoint files in the standalone checkout. Coordinate via explicit Herdr pane identifiers.

## Completion evidence

- Four existing pi workers delivered their assigned files. Main integration caught and fixed a callback argument mismatch, default invocation rejecting an omitted port, Linux stub executable permissions, and test safety under root.
- `node scripts/ci-common.mjs verify` with the official Compose CLI: 74 tests, 69 passed, 5 Linux flock cases skipped on Windows. Lint, deployment contracts, shell syntax and Python compilation passed.
- ShellCheck warning-level checks passed for bootstrap and installed-host regression script.
- Chinese mechanical lint ran on both edited documents. The CI guide has zero findings. Existing README findings remain; one added-line synonym warning treats the verb for reporting an error as equivalent to the noun for a fault. It is a contextual false positive, not a change in the technical concept.
- Functional commit f883070fa7ee2477d6ec567ad328fb019dc75eaf: `fix(deploy): simplify bootstrap defaults and repair rootless setup`.
- Annotated tag v1.0.1 and main pushed to github and cnb, verified by ls-remote.
- GitHub functional main run 43700255402 and release run 43700255257 both completed successfully, including executor/sandbox publishing.
- CNB registry returned HTTP 200 for both v1.0.1 images. Executor :latest and sandbox :3 config labels both contained revision f883070fa7ee2477d6ec567ad328fb019dc75eaf.
- Documentation follow-up 8d78afe8c7585c8ce2cb44e5ab6c4bd8628e4af8: `docs(deploy): clarify runtime limit verification`, pushed to both main branches.
- Final GitHub main run 43700966305 also completed successfully (verify and image jobs). Standalone terminal worktree is clean.
- CNB build-history API is unavailable with the stored Git credential (403). Windows browser access stopped due unsupported URL policy enforcement. Registry evidence verifies published artifacts independently; do not claim direct CNB build-log inspection.
- Live Ubuntu/AL3/ECS installation was not run. WSL cannot boot on this host (HCS_E_HYPERV_NOT_INSTALLED). test/bootstrap-upgrade.sh contains the explicit disposable-host acceptance path.
