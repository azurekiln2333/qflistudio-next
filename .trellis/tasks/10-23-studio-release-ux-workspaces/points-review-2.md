Additional verified points_review findings to fix alongside review-1 (current lines may shift):
1. Token-only changes: points_feed.dart273-288 compares id/admin only. Same-account signIn(newToken) during load causes old response rejected, no new fetch, value null, perpetual spinner. Track token and start replacement loads.
2. Force dedupe: _load215-221 schedules whenComplete retry for every force caller; ten force taps queue ten sequential requests. Keep one shared trailing forced refresh per section and test counts with a blocked first fetch.
3. Mutation account guard: PointsPage._redeem96-98 applies A response balance after user switches to B. Capture token/user before mutation; verify current identity before updating auth, toasts or refresh. Check save/fulfill similarly.
4. Reward buttons listen only section but read auth availablePoints. If rewards arrives with auth0 before ledger returns100, header updates but button stays disabled. Listen to auth in the localized reward/list subtree; regression fast rewards/delayed ledger.
5. Parent role-dependent AppBar and tab count also must update after account/admin change while mounted.
Native reviewer found these by tracing current implementation; please confirm and fix, then run targeted tests with concurrency1. Avoid full suite. Root handles remaining integration. Preserve existing successful progress/section features.
