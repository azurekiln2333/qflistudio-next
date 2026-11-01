# Design

## Deployment (`azurekiln-qfli-server/deployment/sqlbox/`)

- `bootstrap.sh` (root): official `mysql:8.4` image pinned by image ID, run by
  the root Docker daemon as a systemd unit `qfli-sqlbox.service`.
- Container: `--network none`, read-only rootfs, `--cap-drop ALL`,
  `no-new-privileges`, image mysql uid, memory 384 MiB (no swap), 0.5 CPU,
  256 PIDs. Data lives on a 2 GiB loop-mounted ext4 image
  (`nodev,nosuid,noexec`) under `/var/lib/qfli-sqlbox`; the unit requires the
  mount so an absent disk never initializes an empty datadir.
- `skip-networking`, socket `/run/qfli-sqlbox/mysqld.sock` bind-mounted from
  the host. mysqlx disabled, performance_schema off, 64 MiB buffer pool,
  `max_execution_time=5000`, `local_infile=OFF`, `secure_file_priv=NULL`,
  event scheduler off, MyISAM/MEMORY/FEDERATED/ARCHIVE/BLACKHOLE disabled,
  binlog off, `information_schema_stats_expiry=0`.
- Accounts: root@localhost (password in `/etc/qfli-sqlbox/root.password`);
  `qfli_sqlbox@localhost` provisioner with `CREATE USER, CONNECTION_ADMIN,
  PROCESS` globally and `ALL ... WITH GRANT OPTION` on `qs\_%`. It cannot read
  `mysql.*`, cannot modify SYSTEM_USER accounts, and has no FILE/SUPER.
- `--business-env` appends `QFLI_SQLBOX_SOCKET`, `QFLI_SQLBOX_ADMIN_PASSWORD`,
  `QFLI_SQLBOX_USER_SECRET` to the business `.env` when absent.

## Business API (`src/sqlbox.js`, `src/routes/sql.js`)

- Naming: `tag = sha256("qfli-sqlbox/" + userId)[0:20]`; account `qs_<tag>`,
  default schema `qs_<tag>_main`, grant pattern `qs\_<tag>\_%`;
  password = HMAC-SHA256(USER_SECRET, userId).
- Startup-free lazy check (cached, retried after 30 s): socket connection,
  `skip_networking=ON`, `local_infile=OFF`, `secure_file_priv IS NULL`,
  version 8.4, and `server_uuid` differs from the business MySQL.
- Provision per process per user: `CREATE USER IF NOT EXISTS`, `ALTER USER`
  password and limits, grant on its pattern, create default schema.
- Each request opens one connection as the user (no pooling, so no session
  state leaks), `typeCast:false`, `rowsAsArray`, no LOCAL_FILES flag. Binary
  columns (charset 63 string/blob/bit/geometry) are uppercase hex, like the
  native client. 1000 rows / 1 MiB / 128 results; 8 s wall clock, then
  `KILL QUERY` from the provisioner and destroy.
- Concurrency: 2 running, 16 waiting for 10 s; one running + 3 waiting per
  user; 30 requests/minute per user.
- Quota: 32 MiB data+index, 8 schemas, 64 tables. Over quota the grant drops
  to `SELECT, DELETE, DROP` until usage returns below the limit.
- Routes (`authRequired`): `GET /api/sql/info`, `POST /api/sql/query`
  `{database, source, params}`, `POST /api/sql/script` `{database, source}`,
  `DELETE /api/sql/databases`. Responses use the native result JSON shape.

## Clients

- `qfli_studio_core`: `ApiClient.sqlInfo/sqlQuery/sqlScript/sqlReset`;
  `CloudSql.format` renders script results; `TerminalPane.runCloudSql` runs a
  `.sql` entry when no language runner handles it.
- `qfli_sql`: `CloudMySqlDatabase` implements the SQL database interfaces over
  HTTP; `MySqlWorkspaceRepository.openCloud` prefixes new database names.
  `SqlEnginePreference` (sqlite | cloud) is stored in app storage; the
  workbench switches engines, requires login for cloud, and offers reset. The
  project runner follows the preference; default is SQLite.
