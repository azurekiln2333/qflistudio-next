# Points and Daily Tasks

## 1. Scope / Trigger

Use this contract when changing the account task, check-in, points or reward APIs. Local project and file operations occur on the device; the server receives an authenticated report after a successful operation. The server cannot independently inspect the device filesystem.

## 2. Signatures

- `GET /api/users/me/tasks` returns `day`, `checkedToday`, effective `streak`, `points`, `growth` and enabled `tasks[]` (`key`, `eventKey`, `label`, `done`, `progress`, `target`, `reward`).
- `POST /api/users/me/checkin` credits one check-in per server-local calendar day. `GET /api/users/me/checkins?month=YYYY-MM` returns `days[]` with `date` and `points` for the client calendar.
- `POST /api/users/me/task-events` accepts `{ "key": "create_project" | "open_project" | "save_file", "eventId": "event_<32 lowercase hex>", "day": "YYYY-MM-DD" }` and returns `awarded`, `duplicate`, `reward`, `count` for a new event, plus the full task snapshot. A missing `eventId` remains compatible with old clients but counts only once per key and day.
- `GET /api/users/me/points` returns `points` and the latest 100 ledger `entries[]` (`amount`, `balance_after`, `kind`, `reference_id`, `created_at`).
- `GET /api/users/me/rewards`, `POST /api/users/me/rewards/:id/redeem`, `GET /api/users/me/redemptions` own the user exchange flow. Admin task/reward/redemption routes are under `/api/users/admin/`.
- Database tables: `task_config` (`event_key`, `target_count`), `task_events` (unique user and event ID), `task_claims`, `point_ledger`, `reward_items`, `redemptions`. `db.transaction(work)` supplies transaction-bound `prepare(sql)` calls on both SQLite and MySQL.

## 3. Contracts

- `task_config` is seeded idempotently with check-in and 1/5/10 event milestones for project creation, project open and file modification. Admins may change `reward` (integer 0-1000), `enabled` and `targetCount` (integer 1-100; check-in stays 1). Targets for the same event key must be unique.
- `task_events` records each accepted operation by `(user_id, event_id)` and client local day. Reject nonexistent dates and days outside the past 30 days to next day window. `task_claims` has primary key `(user_id, date, task_key)` and awards each reached enabled milestone once. Existing claims are migrated to one event per user, day and legacy task key.
- A check-in reward is the configured base plus `min(streak - 1, 6) * 2`. `growth.experience` is the sum of check-in and task claim rewards. Redemption never reduces experience.
- Every new credit/debit writes `point_ledger` in the same transaction as the `user_state.points` update. A redemption also inserts a `pending` order and decrements finite stock in that transaction. Admin fulfillment marks it `fulfilled`; delivery is external/manual.
- SQLite uses `QFLI_DATA_DIR` if set, otherwise `data/`. Non-transaction SQLite queries wait for the current queued transaction; transaction work uses its private direct statement adapter. MySQL uses one acquired connection with `BEGIN`/`COMMIT`/`ROLLBACK`.
- Client event owners: local or cloud project creation after success, project open on editor navigation, and file edit after a successful save. The editor groups continuous auto-saves per file with a two-second quiet period; dirty manual saves count immediately. `TaskActivityService` persists local daily/all-time counts and a queue of immutable event IDs before sending. Offline failures retain the queue; successful responses update account points and the cached task snapshot. Task and calendar snapshots use cache first and fetch once per local day unless refreshed manually. The points exchange page has an account-scoped daily cache and refreshes immediately after redemption or admin actions.

## 4. Validation & Error Matrix

| Condition | Response |
| --- | --- |
| Unknown task event, invalid calendar day/month or config fields | 400 |
| Repeated event ID | 200 with `duplicate=true`, no new count or credit |
| Non-admin uses `/admin/*` | 403 |
| Reward disabled, sold out or missing | 404 |
| Insufficient balance or already fulfilled redemption | 409 |
| Duplicate check-in or task claim | 200 with no second credit |

## 5. Good / Base / Bad Cases

- Good: the first, fifth and tenth `create_project` events today award their respective milestones, each with a ledger row and experience increase.
- Base: retrying the same event ID returns `duplicate=true` and leaves count and balance unchanged; a new ID advances the count.
- Bad: a failed network report remains queued on the device and resumes with its original ID after restart.
- Bad: two concurrent attempts to redeem the last stocked item produce one pending order/debit and one unavailable response.

## 6. Tests Required

- Run `node --test test/points-rewards.test.js test/points-upgrade.test.js` after changing these contracts.
- Assert milestone progress/rewards, duplicate event ID idempotency, independent experience, disabled task behavior, admin target validation, ledger agreement, finite stock under concurrent redemption, and preservation/backfill of existing balances, check-ins and claims during schema upgrade.
- Run `flutter test --no-pub packages/qfli_studio_core/test/task_activity_service_test.dart` to verify persisted offline events and ID-stable retry.
- Run Dart analysis on `api_client.dart`, `task_activity_service.dart`, `tasks_page.dart`, `points_page.dart`, and their callers after changing payloads.

## 7. Wrong vs Correct

Wrong: credit `user_state.points` in one statement, then insert a redemption or ledger row in a later request; report only the first operation of each type each day; or use `db.prepare` from inside an SQLite transaction.

Correct: call `db.transaction(async tx => { ... tx.prepare(...); ... })` and write the event, claims, balance and ledger or the balance, stock and order before commit. SQLite direct statements stay on that transaction while ordinary queries wait for its completion. Persist each client event ID before attempting network delivery.
