# W3 release design

The OHOS app currently reports 5.0.0/5000000. Pubspec and the HTTP
client profile still report 1.0.0. Release 5.0.1/5000001 will align them.

Change only `pubspec.yaml`, `ohos/AppScope/app.json5`, the main app's
`StudioProfile.clientVersion`, one release consistency test, and this task.
The shared core already reads the version from the app profile.
Keep the existing local signing configuration and signing files unchanged.
Exclude `ohos/build-profile.json5` and all build outputs from commits.

Run a trial `assembleHap` in release mode first. Produce the final package
only after the coordinator explicitly confirms that tests are green.
Prefer the existing release signing identity. Record the actual profile type.
Verify the signed HAP and record its path and SHA256.

Install with `hdc -t 192.168.68.207:46551 install -r`. Use text evidence
for startup, settings agreements/account deletion, and Huawei-only login.
Do not uninstall any app. Stop device work immediately if the screen is locked.
AGC submission remains the user's action.
