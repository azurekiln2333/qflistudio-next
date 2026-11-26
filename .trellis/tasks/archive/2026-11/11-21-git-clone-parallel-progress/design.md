# Design

Pi C owns the Home task list. Pi H owns the Core clone pipeline. Pi G owns the plugin and C bridge. Pi J audits cloud release and wiring. Root integrates and publishes.

Add lib/git/git_clone_progress.dart and export it from git_backend.dart. Define enum GitCloneStage { preparing, connecting, receiving, resolving, checkout, registering }. Define immutable GitCloneProgress with required named stage and integer completed, total, receivedBytes defaulting to zero. Expose a nullable clamped double fraction. Use optional void Function(GitCloneProgress progress) onProgress through service and backends. Emit lifecycle phases in the service and use stage percentages in the UI.

The plugin exposes its own GitCloneStage { receiving, resolving, checkout } and GitCloneProgress with the same fields, and optional onProgress for GitRepository.clone. Core maps types in its native adapter. Extend C with a separate progress-capable entry point. Keep legacy qg_clone. Use per-call isolate progress transport with bounded reports and a completion barrier. Build updated platform payloads and update hashes before app release.

The Home task collection uses independent tokens and progress updates. Archive has its own state. Cancel every live task on disposal. Preserve dialog keyboard geometry and credential behavior.

## Native contract refinement
The frozen export contract requires API 3 when adding the progress symbol. Keep legacy qg_clone exported. The native payload build enables MBEDTLS_THREADING_C and MBEDTLS_THREADING_PTHREAD because libgit2 shares its TLS RNG. A CMake check rejects headers without locking. Core workers initialize libgit2 without replacing process-global CA once the foreground initializer has installed certificates.

## Version 5.0.6 closeout boundary

The remaining gap is release integration: GitHub main still points at 5.0.4 while verified feature work lives on the release branch. Runtime behavior stays at the already reviewed Core/plugin revisions. App version metadata and the installer publication condition must accept v5.0.6. Preserve previews and their immutable tags.

Pi C owns App and platform version metadata, excluding workflow files. Pi H owns installer workflow version metadata and stable-tag publication. Pi G audits GitHub branch ancestry and independent changes without mutation. Pi J tracks the existing tag run and audits downloaded artifact provenance without runtime execution. Root reviews their changes, integrates into main with normal Git history, commits, pushes main and a fresh tag, monitors cloud checks, and deletes only fully merged remote topic refs.

Expected code boundaries are pubspec.yaml and any independently maintained native version metadata, plus .github/workflows/app-installers.yml. Search current version values before deciding which generated or fixture values actually need changes. No feature refactor or dependency upgrade is part of this closeout.
