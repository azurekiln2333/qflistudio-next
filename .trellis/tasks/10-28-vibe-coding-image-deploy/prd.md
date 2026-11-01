# Vibe coding and independent image deployment

## Goal

Let users describe programming tasks inside QFLI and have the AI inspect, create, edit and debug real project files. Simplify deployment with prebuilt images and independent updates.

## Requirements

- R1: Authenticated backend relay to the supplied NewAPI origin, using `deepseek-v4.1-flash`. Credentials remain server-side, absent from Flutter, examples, logs and tracked files.
- R2: Structured tools list/read/create/write/edit real project files. Paths remain inside the selected project. Preserve unsaved work and reject link escapes and concurrent overwrites.
- R3: Run commands using the existing isolated terminal, receive real errors, fix code and rerun. Generated prose never counts as execution.
- R4: Editor Vibe Coding conversation shows progress, actions, results, errors and cancellation. Preserve file ownership and offline network policy.
- R5: Assign the four existing Pi agents in the Herdr qflistudio workspace. The user explicitly requests external CLI control.
- R6: Business and terminal executor use separate service containers, resource limits and updates. Terminal failure must not stop or restart business. Preserve rootless Docker and gVisor isolation.
- R7: Follow the local cnb2api-panel image deployment pattern. CI builds all images. Production only pulls and starts images. Provide independent Compose/watch configuration, persistence, health checks and simple commands.
- R8: Multiple 2C2G terminal nodes form a capacity-aware pool. Automatically assign new sessions, retain user affinity, reject duplicate concurrent user operations and exclude unhealthy/draining nodes. A failed or ambiguous command must never be replayed automatically.
- R9: Document horizontal expansion for other QFLI business services, including shared database/storage, identity temporary state, rate limits, migrations and rolling updates. Clearly distinguish supported behavior from remaining implementation requirements.

## Acceptance Criteria

- [x] Live upstream model request produces a structured tool call.
- [x] Integration creates/edits files, runs a failing program, reads its actual error, fixes code and reruns successfully.
- [x] Focused API/tool/path/conflict/offline/UI checks pass.
- [x] Production manifests use images without build directives. Business has no terminal startup/health dependency. Update scopes are separate.
- [x] Image CI and deployment configuration are validated. Linux runtime claims have observed Linux evidence.
- [x] Pool tests exercise multiple nodes, affinity, capacity, concurrent gateway instances, unavailable nodes, reset and unknown execution outcomes.
- [x] Business scaling design identifies process-local state and concrete migration/deployment boundaries.

Observed checks and remaining release requirements are recorded in
[verification.md](verification.md). Local acceptance does not establish remote
CNB publication, production deployment, packaged-device acceptance or general
business high availability.

## Notes

- Scope includes the shared-core sibling and both backend codebases. Preserve unrelated dirty files. Development does not imply production deployment, publishing or Git push.
