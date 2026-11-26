# R1 GitHub API contract for B

Status: **published for parallel UI work**. Owner: Pi A (`lib/github/**`). This is the Core boundary; UI must not call GitHub HTTP endpoints or read credentials directly.

## Import

```dart
import 'package:qfli_studio_core/github/github_auth_controller.dart';
import 'package:qfli_studio_core/github/github_models.dart';
```

## Public types

```dart
enum GitHubAuthStatus {
  signedOut,
  loading,
  awaitingDeviceAuthorization,
  authenticated,
  error,
}

enum GitHubAuthMethod { oauthDevice, personalAccessToken }

class GitHubAccount {
  final int id;
  final String login;
  final String? name;
  final String? avatarUrl;
}

class GitHubRepository {
  final int id;
  final String name;
  final String fullName;       // owner/name
  final String ownerLogin;
  final bool isPrivate;
  final String htmlUrl;
  final String cloneUrl;       // clean HTTPS URL; never embeds a token
  final String? description;
  final String? defaultBranch;
  final bool archived;
}

class GitHubDeviceAuthorization {
  final String userCode;
  final Uri verificationUri;
  final DateTime expiresAt;
  final Duration pollingInterval;
  // No device_code or access token is exposed by this view model.
}

class GitHubCloneCredential {
  final String username;
  final String token;
  @override
  String toString() => 'GitHubCloneCredential(redacted)';
}
```

`GitHubRepository` and account/device view models are immutable. None includes a token or device code. Do not log credentials or serialize them into widget state, project data, URLs or diagnostics.

## Controller

```dart
class GitHubAuthController extends ChangeNotifier {
  GitHubAuthController({
    String? clientId, // defaults to compile-time QFLI_GITHUB_CLIENT_ID
    GitHubCredentialStore? credentialStore,
    GitHubApi? api,
  });

  GitHubAuthStatus get status;
  GitHubAuthMethod? get authMethod;
  GitHubAccount? get account;
  GitHubDeviceAuthorization? get deviceAuthorization;
  String? get errorMessage;       // sanitized, never contains token/device_code
  bool get isBusy;
  bool get isLoadingRepositories;
  bool get hasMoreRepositories;
  int get repositoryPage;
  List<GitHubRepository> get repositories; // immutable snapshot
  Set<int> get selectedRepositoryIds;       // immutable snapshot
  List<GitHubRepository> get selectedRepositories; // current page/results only
  GitHubCloneCredential? get cloneCredential; // null unless authenticated

  Future<void> restore();
  Future<void> beginDeviceOAuth();
  Future<void> cancelDeviceOAuth();
  Future<void> signInWithPat(String pat);
  Future<void> disconnect();
  Future<void> refreshRepositories();
  Future<void> loadNextRepositoryPage();
  void setRepositorySelected(int repositoryId, bool selected);
  void selectVisibleRepositories();
  void clearSelection();

  // Preferred clone handoff: builds an existing Core request without making UI
  // assemble or persist a token-bearing URL. Returns null if signed out or if
  // the repository is not a current selection.
  GitCloneRequest? buildCloneRequest(GitHubRepository repository);
}
```

`GitCloneRequest` remains the existing Core type in `services/git_clone_service.dart`:
`url`, `name`, `username`, `token`. B's task may add a convenience wrapper/service method around this contract, but must not duplicate OAuth, API pagination or credential persistence.

`cloneCredential` exists for callers that need the existing Git clone service's credential shape; prefer `buildCloneRequest` at the UI boundary. `toString()` of any credential-bearing model must redact the token. The token is only passed into the operation-scoped `GitCloneRequest`; the clone backend already documents that it will not embed credentials in the repository URL.

## State behavior

- Initial state is `signedOut`; `restore()` reads only the platform credential store. Missing/unavailable secure storage reports a safe error; there is no plaintext `auth.json` fallback.
- OAuth is the default sign-in action. `beginDeviceOAuth()` publishes `awaitingDeviceAuthorization`, `deviceAuthorization`, then polls until authenticated, denied, expired, cancelled or a sanitized error. `cancelDeviceOAuth()` cancels the poll and invalidates its generation so late responses cannot sign the user back in.
- PAT is an alternative via `signInWithPat`. The controller validates it against `/user`; it never logs or returns raw HTTP error bodies.
- `disconnect()` invalidates in-flight OAuth, profile, repository and pagination work, clears the actual secure credential, account, results and selections. A stale response cannot repopulate state.
- After auth succeeds, `/user` provides identity. `/user/repos` uses `visibility=all`, `affiliation=owner,collaborator,organization_member`, `per_page=100`, and follows every same-origin `Link: rel="next"` URL. Pages are accumulated without dropping earlier results and deduplicated by repository ID. A repository-fetch error does not discard the authenticated account.
- Selection is keyed by numeric GitHub repository ID and is cleared on disconnect/account change. `selectedRepositories` is derived only from current loaded repository results.
- `buildCloneRequest(repo)` validates that `repo.id` is selected and loaded, that the authenticated credential still exists, and that the HTTPS clone URL contains no userinfo/query/fragment. It returns `GitCloneRequest(url: repo.cloneUrl, name: repo.fullName, username: credential username, token: token)`; for OAuth the username is the GitHub login, for PAT `x-access-token`. It does not mutate the repo URL to include a token.

## OAuth / deployment configuration

OAuth uses GitHub's **device authorization grant**. `QFLI_GITHUB_CLIENT_ID` is a public OAuth App client ID supplied as a compile-time define. A client secret is neither required nor shipped. Device authorization must be enabled for that GitHub OAuth App. If the release has no registered/configured client ID, OAuth reports an actionable unavailable-configuration state; it does not silently switch to PAT or claim to have authenticated.

Official references checked before implementation:
- GitHub Docs, *Authorizing OAuth apps*: <https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/authorizing-oauth-apps>
- GitHub Docs, *Device flow*: <https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/authorizing-oauth-apps#device-flow>
- GitHub REST, *Get the authenticated user*: <https://docs.github.com/en/rest/users/users#get-the-authenticated-user>
- GitHub REST, *List repositories for the authenticated user*: <https://docs.github.com/en/rest/repos/repos#list-repositories-for-the-authenticated-user>

## Native secure-storage coordination with D

A owns the Core dependency/lock change and uses the vetted `flutter_secure_storage` plugin directly via an injectable `GitHubCredentialStore`. The OS vault plugin owns native crypto and platform registration:

- Android: encrypted preferences backed by Android Keystore.
- iOS/macOS: Apple Keychain.
- Windows: Windows secure credential storage.
- Linux: Secret Service/keyring; the app/runtime must have a working secret service, or storage fails closed.
- OHOS is not listed as a supported plugin platform. Core uses a `dart.library.io` conditional export and checks `Platform.operatingSystem != 'ohos'` before accessing the plugin. Do not write files, preferences or an `auth.json` fallback.

D owns native sharing/browser method implementations. A owns Core/App dependency resolution and plugin registration generated by `flutter pub get`; no custom `githubCredential.*` channel is used. The initial channel proposal is superseded by the direct vetted plugin integration.

A persists only the OAuth/PAT access token; no device code, client secret or refresh token is persisted. An unavailable vault blocks completing sign-in and reports an actionable sanitized error. The in-memory test seam is injectable. Browser authorization uses existing `RunnerService.openUrl(verificationUri.toString())`; no new method-channel method is required. If a host cannot open URLs, the picker keeps the URL and user code selectable; a browser-launch failure does not invalidate an otherwise active device grant. This boundary is separate from QFLI `AuthStore`.

## B's screen integration

```dart
final controller = GitHubAuthController();
await controller.restore();
// OAuth button: await controller.beginDeviceOAuth();
// PAT form: await controller.signInWithPat(text);
// Scroll: await controller.loadNextRepositoryPage();
// Multi-select: controller.setRepositorySelected(repo.id, checked);
final requests = controller.selectedRepositories
    .map(controller.buildCloneRequest)
    .whereType<GitCloneRequest>();
```

Dispose the controller with the page. Observe it via `AnimatedBuilder`/`ListenableBuilder` or the existing state convention; do not cache a separate UI copy of auth/repository state.
