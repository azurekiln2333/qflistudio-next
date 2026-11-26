# Execution plan

The user approved this plan and its scope on 2026-11-26.

1. Complete four herdr Pi audits: refs/worktrees, progress/artifacts, cloud CI, target/cleanup.
2. Save recovery material outside both source trees. Record hashes and exclusions without secrets.
3. Add cloud-only agent rules and portable Trellis tracking.
4. Review and commit local source/progress; reconcile main and valid unique branch work.
5. Run Git name/content and metadata checks locally only. Run all project validation on GitHub.
6. Push main without rewriting history. Verify GitHub refs and required cloud jobs/artifacts.
7. Fast-forward target main. Compare both repository trees and statuses.
8. Commit the audit, update the workflow/spec, and repeat the final fast-forward comparison.
9. Deliver the handover through herdr and record the target acknowledgement.
10. Report exact cleanup paths and deferred machine-wide WSL decisions.

## Local command constraints

Allowed: Git inspection/synchronization, text editing, file metadata/hash inspection and herdr coordination.
Forbidden: Flutter/Dart/npm/native build, tests, analyzers, dependency installs, WSL startup, simulators and artifact downloads.
Any existing spec or old task recommending local checks is superseded by the approved cloud-only rule.

## Review gates

- No bulk `git add -A` before filtering and inspecting generated/secret files.
- No source deletion solely to obtain clean status.
- No blanket ours/theirs merge resolution.
- No unrelated-root merge for split repositories.
- No handover completion claim without matching GitHub/source/target evidence.
