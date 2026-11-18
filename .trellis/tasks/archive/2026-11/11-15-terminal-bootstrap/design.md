# Design

The implementation repository is D:/MyNewProjects/azurekiln-qfli-terminal (clean main at 9964c6a). The qflistudio nested directory is an untracked copy, not the release repository.

Behavior ownership is deployment/bootstrap.sh: argument parsing, source resolution, privileged staging of allowlisted release files, configuration, delegation and safe install lifecycle. The existing fixed private runtime project remains under the runner home; the user checkout can be anywhere. Do not recursively relax checkout permissions.

The Compose host mapping uses QFLI_TERMINAL_HOST_PORT with container port fixed to 3101. Bootstrap --port is highest priority, installed environment next, default last. Keep loopback binding. No runtime API changes are necessary.

The dedicated user@UID.service receives persistent Delegate=cpu io memory pids, with cpuset only for systemd >=244. Check real cgroup controllers after reload/restart and before pulling or starting containers. Repair only the dedicated account. Restart only when required.

Image overrides remain explicit. Implicit defaults never reuse a bare legacy build name. Updater fetching must be preflighted and isolated from executor success; retain explicit configuration and report disabled updates if unavailable.

Preserve pinned-image rollback and secret handling. Parent task records stay local to qflistudio. Publish only the standalone terminal repository.
