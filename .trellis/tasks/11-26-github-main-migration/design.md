# Migration design

## Change boundary

The gap is unpublished local progress and divergent worktrees, not a product redesign.
Use GitHub main as the integration baseline and preserve reviewed local deltas.
Expected edits: ignore rules, AGENTS.md, migration records, portable Trellis support, and only necessary CI fixes.
Do not change sibling products or replace their dependency contracts without coordination.

## Preservation and reconciliation

1. Inventory refs, dirty files, ignored progress and worktree ownership.
2. Keep an external local recovery snapshot for original uncommitted content. Never publish machine signing material.
3. Separate source/progress from generated staging trees and caches. Record exclusions.
4. Commit portable local work with explicit paths, then merge GitHub main. Resolve conflicts by inspecting the three versions.
5. Merge valid unique branches after content review. Record equivalent and already-merged branches. An unrelated server split must be verified against its owning repository, not merged at the app root.
6. Review all staged file names, sizes and sensitive configuration before publication.

## Cloud verification

Keep the existing installer topology and pinned dependencies unless an evidenced gap requires a narrow fix.
All builds, tests, analysis and dependency setup run in GitHub Actions.
Inspect jobs and artifact metadata through gh. Do not download installer payloads to the target.
Record the tested app/core commits, required platforms, artifact names and signing status.

## Target and cleanup

Target Codex remains read-only until final handover. Pull with fast-forward semantics after verifying clean status.
Compare commit/tree IDs, tracked file content and status. Record portability differences separately.
The WSL inventory is machine-wide evidence only. No distribution deletion occurs in this task.
Delete no linked worktree until its unique work is accounted for and the published clone is verified.

## Recovery

Retain old refs and recovery snapshots through handover. Never use force-push or destructive reset to fake cleanliness.
On a merge conflict, preserve every original version before resolving.
