# Implementation

1. Record source status, package references, and target-path availability.
2. Extract committed histories into staging repositories and overlay current source files; verify source hashes and preserve dirty state.
3. Update all package manifests, C runtime and editor ownership, and Python's third-party gitlink metadata.
4. Resolve dependencies and run focused checks from staging where possible.
5. Move new repositories to sibling directories, back up original in-tree directories, and update the main repository manifest, scripts, and current documentation.
6. Resolve dependencies and verify all 13 Git roots, dependency paths, and representative app builds/tests.
7. Report new repository paths, dirty changes, and remote setup needed for pushes.

Rollback point: until step 5 the original worktree is untouched. Step 5 moves originals into `.artifacts` instead of deleting them.

## Verification Results

- Source files were copied from the current worktree and SHA-256 checked before activation. Original trees remain in `.artifacts/repository-split-backup-20260929-071812`.
- `flutter pub get --offline` passed in all 13 final repositories.
- All 11 language App test suites passed in staging; C and Python passed again after the move.
- `flutter analyze --no-pub lib/main.dart` and the 12-product OHOS identifier check passed.
- Shared core has six existing `widget_test.dart` failures in both original and extracted locations, primarily backup-count assertions.
- Runtime release gate still reports nine profiles with `runtimeStatus: unavailable`; those statuses were present before the repository split.
- Migration-only commits were made in all 13 repositories. Existing user changes remain uncommitted, and new GitHub remotes were not created.
