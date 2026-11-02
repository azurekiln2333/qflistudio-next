# W3 release design

The release baseline reported 5.0.0/5000000 in OHOS and 1.0.0 in pubspec
and the HTTP client profile. Release 5.0.1/5000001 aligns them.

Change only `pubspec.yaml`, `ohos/AppScope/app.json5`, the main app's
`StudioProfile.clientVersion`, one release consistency test, and this task.
The shared core already reads the version from the app profile.
Keep the existing local signing configuration and signing files unchanged.
Exclude `ohos/build-profile.json5` and all build outputs from commits.

Run a trial `assembleHap` in release mode first. Produce the final package
only after the coordinator explicitly confirms that tests are green.
Prefer the existing release signing identity. Record the actual profile type.
Verify the signed HAP and record its path and SHA256.

The coordinator has confirmed test-green approval for the final build.
Device smoke is deferred until an explicit `设备已解锁` notice.
Do not operate the locked device during this packaging turn.
Record device smoke as pending and close the packaging task as requested.
The later smoke run must use `install -r` and text evidence.
AGC submission remains the user's action.
