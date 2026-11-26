# GitHub main consolidation and cloud-only workspace migration

## Goal

Preserve source and portable Trellis progress, reconcile branches on GitHub, verify cloud CI, compare the E drive checkout and hand over through herdr.

## Scope and authorization

The user approved this migration scope on 2026-11-26 after the planning summary.
Source: `D:/MyNewProjects/qflistudio`.
Target: `E:/MyNewProjects/QFLIProjects/qflistudio-next`.
GitHub: `azurekiln2333/qflistudio-next`.
The singular `E:/MyNewProjects/QFLIProject` does not exist.
Other product repositories remain owned by their workspace leads.

## Requirements

- Preserve all unique source and portable Trellis tasks, research, specifications, journals and workflow support.
- Exclude credentials, machine configuration, caches, generated staging copies, build and test output.
- Inspect every configured remote branch, local branch and linked worktree before consolidating valid project work into `main`.
- Keep GitHub as the authoritative remote. The target must have only a GitHub remote.
- Verify six platform installer coverage and cloud tests with actual GitHub Actions evidence. Identify native-runtime ownership and artifact provenance.
- Do not run local builds, tests, analyzers, dependency resolution or installs. Persist this rule for future agents.
- Pull the final GitHub commit into the target and compare commit, tree, tracked content and clean status with the source.
- Coordinate four Pi agents through herdr using gpt-6.1-sol. Retry concurrency limits before the authorized fallback.
- Hand over to target Codex only after the comparison. Inventory WSL and old artifacts first; provide a precise cleanup plan after data verification.

## Acceptance Criteria

- [ ] Unique source and all portable Trellis progress are published on GitHub.
- [ ] Every branch/worktree has a recorded disposition; no unique work is lost.
- [ ] The source and target are clean on `main` at the published commit and tree.
- [ ] Generated output and credentials are absent from the publication.
- [ ] Cloud-only rules are committed and available in a fresh clone.
- [ ] Six platform jobs, installer artifacts and required tests have verified cloud evidence, with signing limitations stated.
- [ ] Target Codex acknowledges the final handover through herdr.
- [ ] Cleanup instructions list exact owned paths and preserve unverified WSL data.

## Exclusions

No unrelated repository changes, force-push, history rewrite, global cache deletion or WSL unregister.
Formal signing and store publication require the owning release configuration and are not implied by an unsigned build.
