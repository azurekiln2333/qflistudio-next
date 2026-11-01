# Isolated cloud MySQL sandbox and SQLite default

## Goal

- A: SQLab runs SQL on the device by default using the bundled SQLite engine
  (phones cannot host the bundled Oracle MySQL server).
- B: Logged-in users get a cloud MySQL practice space. It runs in a separate,
  resource-bounded mysqld that is isolated from the business MySQL.
- Entry points: the SQLab workbench engine switch (SQLite / cloud MySQL) and
  its project runner; `.sql` runs in the main QFLIStudio+ editor.

## Requirements

- The practice mysqld is a different server (different server_uuid, datadir,
  socket) from the business database. The business API refuses to use it when
  the isolation checks fail.
- No TCP listener; the business API reaches it through a host Unix socket.
- Each app user maps to a derived MySQL account restricted to its own schema
  prefix `qs_<tag>_*`. The App never receives MySQL credentials.
- Hard caps: container memory/CPU/PIDs, a fixed-size data disk, per-user data
  quota, statement time limit, result rows/bytes, global and per-user
  concurrency, request rate.
- `LOAD DATA LOCAL`, `SELECT ... INTO OUTFILE`, event scheduler, FEDERATED and
  file privileges are unavailable.
- Users can reset their cloud databases.

## Out of scope

- Remote (separate VM) practice MySQL over TLS.
- Idle-account garbage collection.
