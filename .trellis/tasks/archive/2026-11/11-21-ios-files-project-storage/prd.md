# iOS project storage in Files

New managed projects on iOS use Documents/projects. Files shows this directory under On My iPhone → QFLIStudioN.

- Use this default for new projects, imports, examples, and clones.
- Recover existing iOS projects after the container path changes. Keep their files, IDs, and list metadata in place.
- Store the registry, credentials, and app settings in private iOS storage.
- Keep the existing private project root on Android and HarmonyOS.
- Run regression tests and package verification on GitHub Actions.

## Acceptance

- [x] Verify both Files sharing flags in the packaged iOS app.
- [x] Verify path resolution after the iOS container UUID changes.
- [x] Verify legacy paths, external paths, and backup recovery.
- [x] Build and publish the tagged preview with GitHub Actions.
