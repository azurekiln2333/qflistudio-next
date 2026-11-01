# Execution

1. Root probes live NewAPI model/tool behavior and coordinates four existing Herdr Pi workers.
2. Pi A implements backend relay and tests.
3. Pi B implements client agent, file tools and isolated debug loop; publishes API contract promptly.
4. Pi C implements editor conversation and buffer integration against B's contract.
5. Pi D implements independent prebuilt-image deployment/watch, preserving isolation.
6. Root reviews contracts, integrates fixes, runs affected checks and live create/edit/fail/fix/rerun scenario.
7. Record evidence and remaining Linux limitations. Do not claim publication or deployment without evidence.

## File ownership
- A: server AI module/router, server.js, AI environment entries and AI tests.
- B: shared-core `lib/vibe_coding/` services/models/tools, `lib/services/api_client.dart`, focused service/tool tests.
- C: shared-core editor integration and vibe UI files/tests.
- D: Dockerfiles/Compose/watch/CI/installers/deployment docs, deployment-specific executor adaptations. Coordinate env-example edits with A.
- Root: coordination, live probe and cross-layer review. Avoid overlapping worker edits.

## Checks
Node syntax and server tests; executor npm test; Dart format/analyze and focused agent/API/UI tests; main-app analysis; Compose/CI YAML and shell syntax; image-only config and failure independence; live upstream plus project/debug integration. Run Chinese STE lint on changed Chinese technical docs.
