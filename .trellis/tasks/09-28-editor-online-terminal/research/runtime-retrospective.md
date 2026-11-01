# Runtime Debug Retrospective (2026-09-30)

## 1. Root Cause Category

- Change propagation: the Docker exec PATH replaced the image SDK PATH, so
  installed Node/Dart were not available to user commands.
- Implicit assumptions: Docker tmpfs defaults to noexec; same-UID nondumpable
  PID 1 can still receive SIGSTOP under the tested gVisor release.
- Integration coverage: Ubuntu's protected user unit maps host root to UID
  65534, unlike the installer shell. Literal UID 0 cgroup checks rejected it.
- Host compatibility: AL3 lacks required basic utilities in its minimal rootfs,
  resolves Docker's CentOS release variable to 3, and has a libslirp/glib2 mismatch.

## 2. Why Static Checks Were Insufficient

Image package presence did not exercise exec environment, mount execution or
supervisor signal permissions. Installer-shell validation did not reproduce
the protected unit's namespace. Dependency metadata did not prove slirp4netns
could run, and a one-invocation Docker repo override did not fix later dnf calls.

## 3. Prevention Mechanisms

| Priority | Mechanism | Implemented assertion |
| --- | --- | --- |
| P0 | Shared sandbox contract | create and exec use src/sandbox.js; command environment regression |
| P0 | Distinct supervisor identity | real user SIGSTOP/ptrace/proc-mem/process_vm probes |
| P0 | Actual bootstrap verification | all ten language programs compile/run in normal Sessions |
| P0 | Protected-service verification | authenticated health after enabling the actual unit |
| P0 | Resource accounting | failed deletion retains capacity; lifecycle failure injection |
| P1 | Host prerequisites | AL3 signed persistent repo, targeted glib2 upgrade, utility checks |
| P1 | Download limits | checked official archives, bounded gVisor/SDK transfers and backups |

## 4. Systematic Expansion

Check both sandbox creation and later exec whenever compiler defaults change.
Test the deployed service namespace, rerun behavior and real reboot, rather
than assuming an installer-shell probe covers them. WSL test accounts use
distinct host UIDs because imported distributions share the kernel/cgroup tree.

MemoryHigh pressure can throttle Docker management before MemoryMax causes a
host OOM. The AL3 probe increased high to 10090 while oom_kill remained zero;
cleanup timed out and health returned 503. Retaining the failed reservation is
required, but automatic memory-pressure recovery remains unresolved. The
outer-shell-ignore OOM case was not reached. Do not lower or remove limits to
turn this test green.

## 5. Knowledge Capture

The executable contracts and observed limitation are recorded in
`.trellis/spec/backend/terminal-isolation.md`; committed release evidence lives
in `azurekiln-qfli-terminal/docs/runtime-validation.md`. Parent specs are ignored
by this checkout and are not force-added to unrelated parent work.
