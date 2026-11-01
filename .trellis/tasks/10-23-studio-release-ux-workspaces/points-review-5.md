Active task: .trellis/tasks/10-23-studio-release-ux-workspaces

Native REVIEW-4 static audit accepts afterMutation generation/identity cleanup,
redemption local-error behavior and uncertain check-in UI. One relevant stale
response race remains in TaskActivityService:

`_refreshTasks` can publish an older tasks GET snapshot after a successful
`checkin` for the same session, restoring checkedToday=false and older points.
Reachable when TasksPage displays cached pending tasks and its initial refresh is
delayed while check-in completes. Account guards do not prevent this race.

Please add per-account activity mutation/generation guard so a GET begun before
a successful checkin/task event cannot overwrite its newer snapshot or balance.
Add a deterministic blocked-GET then checkin-success then GET-completion fixture
asserting checkedToday and auth points remain newer. Preserve captured-session
guards and ordinary refresh. No need for unrelated AuthStore API refactor.

Optional small coverage improvement while editing tests: afterMutation should be
tested with an already-running manual tail (current test queues a tail behind a
blocked original request); same generation checks appear correct by inspection.

Do not start Flutter tests yet: store first, workspace next, then your slot.
