# Terminal bootstrap repair

The user authorized immediate implementation, four existing Herdr pi workers, conventional commits, push, release tag and CI verification.

## Requirements
- Install from a checkout with `bash deployment/bootstrap.sh`; image and source flags are optional.
- Prefer the current complete checkout, then the script checkout, then the installed project. Explicit source wins.
- Default to the published CNB executor and sandbox images. Ignore stale legacy local image names unless explicitly requested.
- Accept checkouts under arbitrary root-readable directories, including /root and /www/wwwroot, without chmod or copying the repository by hand.
- Support a validated custom loopback host port using --port. Persist it for repeat installs; default 3101.
- Repair dedicated runner cgroup CPU delegation on supported Ubuntu 24.04 and Alibaba Linux 3 hosts. Keep rootless Docker, gVisor and resource limits.
- Handle optional updater download failure explicitly without discarding a healthy executor.
- Preserve secrets, immutable rollback and unchanged-install behavior.
- Run regression checks, commit only terminal changes, push both configured remotes and a new patch tag; inspect CI status.

## Acceptance
Executable regression tests cover argument/default behavior, source selection, root-only source staging, port persistence and validation, delegation compatibility, updater handling and upgrade rollback. Full repository verification passes. CI runs are reported accurately.

## Exclusions
No arbitrary OS support, rootful fallback, disabled resource checks, unrelated app edits or production host changes. Production ECS runtime evidence is distinct from local tests.

Open questions: none.
