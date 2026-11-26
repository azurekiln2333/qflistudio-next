Active task: D:/MyNewProjects/qflistudio/.trellis/tasks/11-20-studio-git-integration

You are already trellis-implement, Pi B. Implement directly without subagents.
Read common.md, task artifacts, implement.jsonl and core specs first.
Your cwd is D:/MyNewProjects/_wt/studio-git-integration/qfli_studio_core.

Own ONLY lib/git/, lib/services/git_service.dart, backend tests named
test/git_backend*_test.dart, and new .trellis/spec/frontend/git-backend.md.
May create ignored pubspec_overrides.yaml pointing qfli_git at ../qfli_git for
analysis. Pi D owns tracked pubspec/lock changes. Do not edit UI, editor, Home or
Git clone coordinator (Pi C owns those).

Create the exact frozen models/interface/factory from design.md FIRST. Publish
availability in reports/pi-b-backend.md early. Pi C can then implement against
them. Implement real CLI/native adapters, canonical per-root mutation ordering,
typed error/status mapping, branch/merge/conflicts, author validation, index-only
commit, diff/history, remote config, network cancellation and clone factory.
Pi A is adding the exact plugin methods/types documented in design.md. Read its
early reports/pi-a-api.md as it appears. Do not substitute fake native methods.

Read core backend process-supervision and offline-network-policy specs. Preserve
desktop pull --rebase and credential helper/SSH. Do not load native FFI on desktop.
Cloud UI remains server-backed and outside this local backend interface. Keep
legacy GitService safe/compatible where still needed. Never let an add failure
fall through into commit. Reject unsafe path/argument forms and redact secrets.

Ensure default public constructors match design.md and expose testing injection
without forcing UI to know transport details. Write meaningful cloud-only tests
for selection, combined status, unborn/detached, failure/cancel/dispose, offline
network rejection and mutation ordering. NO LOCAL TESTS OR BUILDS.

Finish reports/pi-b-backend.md with exact files, interface changes if any, static
checks and cloud commands. Do not wait idle for plugin binaries: write the adapter
against the frozen API and document native cloud validation as pending.
