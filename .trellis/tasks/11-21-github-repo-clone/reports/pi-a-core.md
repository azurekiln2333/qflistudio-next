# Pi A — Core R1 handoff and freeze

**Status: CORE FROZEN.** Root may stage/commit the Core R1 files below. No Core R1 source edits remain planned from A.

## Exact Core R1 path list

| Path | Purpose / requirement mapping |
| --- | --- |
| `lib/github/github_models.dart` | Immutable const account/repository/device/credential models; token-redacted credential diagnostics. |
| `lib/github/github_api.dart` | OAuth Device Flow, `/user`, all `/user/repos` pages, origin-checked pagination, clean HTTPS clone URLs, sanitized errors, request/body timeout and redirect refusal. |
| `lib/github/github_auth_controller.dart` | Observable OAuth/PAT auth, cancellation/expiry, pagination, multi-select, clone-request handoff, process-wide identity fence, serialized vault lifecycle. |
| `lib/github/github_credential_store.dart` | `flutter_secure_storage` adapter, platform options, fail-closed unsupported handling, process-wide secure-vault queue/generation, injectable memory store for regression sources. |
| `lib/github/github_platform_io.dart` | IO-only OS capability probe (OHOS excluded). |
| `lib/github/github_platform_stub.dart` | Web-safe unsupported-platform fallback. |
| `pubspec.yaml` | Core dependency `flutter_secure_storage: ^11.2.0`. |
| `pubspec.lock` | Resolved direct/transitive secure-storage packages. |
| `test/github_auth_controller_test.dart` | Cloud regression source for stale delayed vault reads/writes, disconnect/cancel/dispose cleanup, cross-controller credential fence, redaction and inert construction. Source is added but not executed locally. |

B's picker contract remains in `reports/contracts-a.md`; it uses `const` constructors and the fields/methods listed there. D's cross-platform configuration notes are in `reports/native-a.md`.

## Static checks completed

Commands run in `D:/MyNewProjects/_wt/studio-git-integration/qfli_studio_core`:

```text
dart format --output=none --set-exit-if-changed lib/github test/github_auth_controller_test.dart
Formatted 7 files (0 changed). exit 0

dart analyze lib/github test/github_auth_controller_test.dart
No issues found. exit 0
```

App dependency resolution was also performed by A before the Core freeze:

```text
cd D:/MyNewProjects/_wt/studio-git-integration/qflistudio
flutter pub get
Resolved flutter_secure_storage 11.2.0 and generated the supported-platform registrants.
No build was run.
```

No tests, build, emulator, device, service, stage, commit, or push was run by A.

## Core findings / capability gaps

- GitHub OAuth device flow needs a release-provided **public** `QFLI_GITHUB_CLIENT_ID` and an OAuth App with Device Flow enabled. No client secret is used or shipped. No production OAuth registration/deployment configuration has been provided or validated; report it as a release dependency.
- `flutter_secure_storage` 11.2.0 does not register OHOS. Core uses an IO-conditional capability probe and rejects OHOS/Web sign-in before sending an OAuth/PAT request. It never falls back to plaintext. OHOS GitHub login therefore remains unavailable until a reviewed vault plugin exists.
- Linux requires `libsecret-1-dev` to build and `libsecret-1-0` plus an active Secret Service at runtime. App CI and the `.deb` dependency were wired by A after the Core static check; those files remain App/root review items and do not block this Core freeze.
- Native Keychain/Keystore/Secret Service runtime behavior and all delayed-vault/API regressions remain unexecuted by policy; cloud CI/device validation is pending.

## Core source freeze

The nine paths in the table above are the complete A-owned Core R1 implementation and regression-source hunk map. No App/Home/cloud/editor/native-share files are included in the Core freeze. Root owns the serialized requirement commit.
