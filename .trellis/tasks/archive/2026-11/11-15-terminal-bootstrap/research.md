# Investigation and verification evidence

## Confirmed defects
- The script has CNB defaults, but reading legacy runner.env replaces the sandbox with a bare local build name. Docker then attempts Docker Hub.
- Source resolution only checks --source-dir or the installed project; it does not try the invocation cwd or script checkout.
- Root invokes runner-owned install commands directly against source files, so /root or restrictive web roots are unreadable to the runner.
- Compose binds 127.0.0.1:3101:3101 literally.
- Account slice limits exist, but the user manager has no explicit CPU controller delegation. A container CPU quota then fails before executor startup.
- Watchtower is part of default compose up, so its separate Docker Hub failure can fail installation after primary images have succeeded.

## Primary reference
Docker rootless resource-limiting instructions: https://docs.docker.com/engine/security/rootless/tips/ (read 2026-11-15). Only memory/pids are usually delegated by default. Delegate CPU, io, memory and pids explicitly. cpuset delegation requires systemd 244 or newer; Alibaba Linux 3 uses systemd 239. Never remove CPU/memory limits to compensate.

## Local environment
- Standalone terminal checkout and both remote main branches started at 9964c6a88b3630d71c37fbf7fa4f49df1974e736. Latest existing release was v1.0.0.
- Initial node scripts/ci-common.mjs verify passed: 40 tests, 35 passed and 5 Linux flock tests skipped on Windows.
- All four user-selected existing pi agents in Herdr workspace w37 accepted work and entered working state.
- WSL test distributions exist but cannot boot: HCS_E_HYPERV_NOT_INSTALLED. No live Docker engine is available on Windows. Do not claim production ECS or WSL runtime acceptance.
- Official Compose v5.7.1 Windows CLI downloaded to a temporary tools directory. Verified SHA256 e4316597452650ae92fe9719a2a7c2fce8f56c5ceafed88d2aed6e39b2b2b2d0 against its GitHub release asset digest.
- Official ShellCheck v0.11.0 archive verified against SHA256 8a4e35ab0b331c85d73567b12f2a444df187f483e5079ceffa6bda1faa2e740e.

## Prevention
Treat install defaults and legacy migration as a single contract. Validate host capabilities before downloads. Stage allowlisted release files across the root/runner boundary. Exercise Bash behavior and Compose rendering in tests rather than relying on source regex checks alone. Keep Linux runtime and publication evidence separate from local syntax checks.
