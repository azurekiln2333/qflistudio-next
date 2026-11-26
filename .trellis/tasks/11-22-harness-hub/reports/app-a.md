# App installers 修复记录（Pi-A）

## 失败：`test/release_version_test.dart` :: release manifests and the HarmonyOS HTTP version agree

第 1 轮 CI 抓到的断言：`Expected: '5.0.8'`，`Actual: '5.0.6'`，位置是测试文件第 32 行。

### 根因

- 用例从 `pubspec.yaml` 读出版本名，再与应用清单和 Profile 版本逐项比对。
- `pubspec.yaml` 已是 5.0.8，`ohos/AppScope/app.json5` 已是 5.0.8。
- `lib/main.dart` 的 `qfliStudioProfile.clientVersion` 仍写在 5.0.6。
- 第 32 行断言的正是 Profile 版本与 pubspec 版本一致。
- 5.0.7 与 5.0.8 两次升版提交只改了清单与工作流。
- 它们漏改了 `lib/main.dart` 里的这个版本常量。
- 早期 5.0.1、5.0.5、5.0.6 升版都会同步改这处，说明这是漏改。

### 影响

- `ClientPlatform.header` 取 `StudioProfile.current.clientVersion`。
- 这个头会随请求发到云端，升版后仍宣告旧版本。

### 修复

位置：`lib/main.dart`。

- 把 `clientVersion: '5.0.6'` 改为 `clientVersion: '5.0.8'`。
- 只改这一处常量，不动测试，也不改清单。
- 测试断言的是产品契约，代码错了，所以改代码。

### 提交

`f342363 fix(release): align the studio profile version with 5.0.8`

只提交 `lib/main.dart`。

### 静态检查

- `dart format --set-exit-if-changed lib/main.dart`：0 处改动。
- `flutter analyze --no-pub lib/main.dart`：只剩既有的 `unnecessary_import` 提示。
- 该提示在改动前就存在，与本次版本号改动无关。
- 未跑 `flutter test`，未推送，未改生成的插件注册文件。
