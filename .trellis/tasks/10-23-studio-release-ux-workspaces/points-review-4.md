Active task: .trellis/tasks/10-23-studio-release-ux-workspaces

Native read-only review found remaining concrete gaps. Please fix scoped points/task files, author focused regressions, BUT DO NOT START Flutter tests until root releases C's global serialized slot.

1. TaskActivityService.checkin checks token after server response, then awaits task-cache _persist(), then calls auth.updatePoints without checking again. If B signs in during cache persistence, A's points/streak/growth update B. Recheck captured token AND userId immediately before updating auth. TasksPage should also check captured session after checkin/exception before showing success/error feedback for another account.
2. PointsPage._redeem directly awaits auth.updatePoints and catches only ApiException. A FileSystemException after successful redemption POST skips success/stock/orders refresh and escapes. Treat remote redemption as successful, show local persistence warning if needed, and continue refresh with existing captured account/token guards.
3. Forced-tail coalescing currently joins an already-running tail for all force callers. If redemption/reward edit/fulfill completes after that tail GET started, its post-mutation refresh can join older data, leaving stock/orders stale. Preserve deduplication for repeated manual refreshes, but mutation invalidation must guarantee at least one request started after the mutation. Add a distinct invalidation/generation API or equivalent, use it after mutation, and test with blocked pre-mutation tail and mutation response. Check delayed ledger cannot overwrite newer mutation balance even if totals happen to match (revision if necessary).

No backend/live-account mutation, commits, or broad tests. Report exact paths and targeted evidence after test window.
