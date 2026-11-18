# AI relay and terminal node placement

## 1. Scope / Trigger

Apply this contract to the business backend's `src/ai-client.js`,
`src/routes/ai.js`, `src/terminal-client.js`, `src/terminal-pool.js`,
`src/routes/terminal.js`, and the coordination schema in `src/db.js`.
The shared-core client contract lives in
`../qfli_studio_core/.trellis/spec/frontend/vibe-coding.md`.
Keep execution isolation in [Terminal Isolation](terminal-isolation.md).

## 2. Signatures

- `POST /api/ai/chat`, bearer authenticated, body `{messages, tools?}`.
- Response `{model, message, usage?}`. Preserve assistant `tool_calls` and IDs.
- `POST /api/terminal/exec`, body `{command, files?}`.
- `POST /api/terminal/exec/stream`, same body, validated NDJSON events.
- `DELETE /api/terminal/session`, reset only the authenticated user's placement.
- `db.transaction(work)`, `db.prepare(sql)`, `db.now()`, and `db.NOW_SQL`.
- `terminal_slots(node_id, user_id, reclaim_user_id, phase, operation_token,
  operation_deadline, idle_deadline, session_deadline, updated_at)`.
- `terminal_coord(key, version, updated_at)` has the singleton key `pool`.

## 3. Contracts

### Relay boundary

Only server environment selects `QFLI_AI_BASE_URL`, `QFLI_AI_API_KEY` and
`QFLI_AI_MODEL`. The default model is `deepseek-v4.1-flash`. Never put upstream
credentials in Flutter, examples, tracked fixtures, audit detail or errors.
Client bodies cannot override connection parameters or the model.

Require HTTPS except loopback development origins. Normalize the configured
prefix to `/v1/chat/completions`. Validate roles, tool definitions, tool-call
IDs and the complete message/tool protocol before forwarding. Bound input,
upstream output, elapsed time, per-user rate and concurrent requests.
Cancellation must reach the upstream fetch. Audit the model name and call
count, not prompts, file text or credentials.

### Upstream message normalization

Canonicalize `choices[0].message` before returning it. Never forward unknown
upstream metadata.

- Assistant `tool_calls` may carry `index` from upstream stream assembly. Accept
  it on the response path only when `Number.isSafeInteger(index) && index >= 0`,
  then strip it from the canonical message.
- Keep the client request whitelist strict: request `tool_calls` allow only
  `id`, `type` and `function`. A client-sent `index` or unknown key is 400 and
  never reaches upstream.
- `tool_calls: null` and `tool_calls: []` mean no calls for this turn. With a
  nonempty string `content`, return a plain assistant message without
  `tool_calls`, so a final text turn after tool use succeeds.
- Reject a non-list `tool_calls` as 502. With absent, null or empty calls,
  reject null or empty-string content as 502. Empty-string content remains
  valid with a nonempty validated call list.
  Every kept call still requires a valid `id`, `type: "function"` and a string
  `arguments`.

### Node configuration

`QFLI_TERMINAL_NODES` is a JSON array of at most 16 entries:
`{id, url, secret, draining?}`. Each ID and endpoint must be unique. A node's
secret has 32–256 printable ASCII characters. Non-loopback origins require
certificate-validated HTTPS. Preserve legacy `QFLI_TERMINAL_URL` and
`QFLI_TERMINAL_SECRET`; do not duplicate the same configured endpoint.

Each 2C2G executor retains one session and one operation slot. Capacity grows
by adding nodes. Admission requires authenticated health with validated
`capacity` metadata. Missing capacity is unavailable. Do not estimate spare
capacity from a generic HTTP 200. `draining: true` rejects new assignments and
retains current user affinity. Public `/pwd` must not create sessions.

### Placement and fencing

Run each placement decision in one database transaction. Update the singleton
coordination row before reading/writing slot ownership. Use database time for
deadlines. Never hold a transaction across HTTP, Docker, health or cleanup.

The phases are `free`, `reserved`, `idle`, `quarantine` and `reclaiming`.
Persist the operation token before dispatch. Finalization must match that token;
a late response cannot overwrite a newer reset or assignment.

One user may own at most one non-free node. Check both `user_id` and
`reclaim_user_id`. During reclamation, `user_id` retains the old session owner
and `reclaim_user_id` reserves the requester while DELETE is in flight. Recheck
uniqueness in the completion transaction. If another binding exists, release
only the node whose cleanup has been confirmed and refuse a second placement.

An expired deadline triggers cleanup; it never proves that an old command
stopped. Quarantined, reclaiming, expired or removed-node ownership cannot be
bypassed by choosing a free node. Require confirmed DELETE on the original node
before moving the user. Do not automatically replay an ambiguous command.

Reset must also find pending `reclaim_user_id` reservations. Cancel/fence that
requester so an earlier DELETE completion cannot admit a command after reset
has succeeded. Keep any old owner's unconfirmed cleanup debt charged.
Every completion branch must check token ownership, including failed DELETE.
A failed quarantine update means the operation lost its token. Abort with 409
instead of retrying another node for the cancelled request.

Release only when the executor explicitly proves non-admission: validated
queue/capacity/expiry/request-rejection codes or internal authentication failure.
Unknown transport outcomes, malformed responses, output/timeout/cleanup failures
retain ownership in quarantine. Health alone cannot clear an unknown outcome.

SQLite serializes its local connection through the existing transaction lane.
Separate business hosts require shared MySQL/InnoDB, not a network SQLite file.
The pool's shared ownership does not make all business services stateless:
login challenges, refresh coordination, rate limits, cloud files and SQL
environments still require the work documented in `docs/deployment/scaling.md`.

## 4. Validation & Error Matrix

| Condition | Required behavior |
| --- | --- |
| Missing App authentication | 401 before pool or relay work |
| Client model/origin override or invalid tool protocol | Reject before upstream |
| Client request tool-call carries `index` or unknown key | 400 before upstream |
| Upstream tool-call carries non-negative safe integer `index` | Strip it from the response |
| Upstream `tool_calls` is `null`/`[]` with text content | Return text-only assistant message |
| Upstream `tool_calls` is non-list, or no text and no calls | 502 |
| Missing AI configuration | 503 with no secret in response |
| Pool full | 429 without dispatch or success audit |
| Same user reserved or reclaiming | 409 across gateway instances |
| Assigned node unhealthy/removed | Fail without dispatch to another node |
| Unknown execution outcome | Retain node ownership in quarantine |
| Stale operation token | Refuse finalization/assignment |
| Reset during pending requester reclamation | Fence the pending command |
| All terminal nodes fail | Business health remains independent |

## 5. Good / Base / Bad Cases

Good: two users use two healthy nodes concurrently; each user's next command
reuses its original node. Base: the legacy single-node environment still works.
Bad: a timeout is treated as free capacity and the same user's command is sent
to a second node. Bad: two gateways reclaim different expired sessions for one
new requester because only the old owners were persisted.

## 6. Tests Required

Run `node --test test/*.test.js` in `azurekiln-qfli-server`.
`ai-relay.test.js` covers auth, fixed configuration, protocol, tool-call
preservation, limits and cancellation. It also pins upstream `index` stripping,
malformed index metadata, and `null`/empty `tool_calls` final-text turns.
`terminal-pool.test.js` covers node
configuration, affinity, capacity, draining, two module instances sharing the
database, stale tokens, unknown outcomes, delayed reclamation and reset.
Cover both successful and failed cleanup after requester cancellation. Leave a
second expired node available so the test detects unintended re-placement.

`terminal-routes.test.js` mounts the real Express router with loopback executor
stubs. Assert audit/response order, streamed progress/output/result order,
capacity rejection without dispatch, reset routing and abort quarantine.
Pool-only stubs do not establish route-level cancellation behavior.

MySQL evidence requires the opt-in `test/terminal-pool.mysql.test.js` against a
disposable database containing `test` in its name. Follow its companion README.
SQLite success is not proof of MySQL DDL, ALTER or row-lock behavior. Record
actual observed results separately from a skipped test.

## 7. Wrong vs Correct

Wrong: keep the new requester's identity only in an in-memory return value
while awaiting deletion of an old user's session.

Correct: persist `reclaim_user_id` under the shared coordination lock, check it
for every admission/reset, and match the operation token on completion.

Wrong: retry a failed command on another healthy node.

Correct: report the actual failure, preserve unknown ownership, and confirm
cleanup on the original node before accepting a new command.
