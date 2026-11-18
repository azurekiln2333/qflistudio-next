# Design：产品安装包云构建工作流

## 1. 文件边界

新增文件，全部位于本仓库：

| 路径 | 作用 |
|---|---|
| `.github/workflows/app-installers.yml` | 唯一的安装包工作流 |
| `.github/actions/app-setup/action.yml` | composite：检出内核、缓存并安装 Flutter、`flutter pub get` |
| `.github/actions/setup-ohos/{action.yml,setup.sh,LICENSE}` | 从 `qfli_python` 复制的 HarmonyOS 命令行工具安装器（MIT，ErBWs/setup-ohos v2.0.0，已去掉缓存步骤） |
| `tool/ci/setup_flutter.sh` | 安装 Flutter。`upstream` 模式按版本 clone 官方仓库，`ohos` 模式 clone 分支并校验提交 |
| `tool/ci/resolve_flutter.sh` | 从官方 releases json 解析最新 stable 的版本与提交 |
| `tool/ci/app_version.sh`、`tool/ci/run_logged.sh` | 从模板原样复制 |
| `tool/ci/stage_artifact.sh` | 改编自模板：去掉 MicroPython 许可证，写 `BUILD_INFO.txt` 与 `SHA256SUMS` |
| `tool/ci/package_linux.sh` | 重写：按架构生成 `.deb` 与 `.tar.gz`，含 `.desktop` 与图标 |
| `tool/ci/thin_macos_app.sh` | 校验 `.app` 内每个 Mach-O。残留多架构文件时 `lipo -thin`，再 ad-hoc 重签 |
| `tool/ci/strip_ohos_signing.py` | 改编自模板：只在 runner 上删除 `build-profile.json5` 的签名配置 |
| `windows/installer/qflistudio.iss` | Inno Setup 脚本，按 `/D` 参数切换 x64 与 arm64 |

不修改任何已跟踪文件。工作区已有大量未提交改动，实现时只新增上述路径。

## 2. 工作区布局

每个 job 都把两个仓库检出为同级目录：

```
$GITHUB_WORKSPACE/
  qflistudio/          # actions/checkout，path: qflistudio
  qfli_studio_core/    # actions/checkout，repository: azurekiln2333/qflistudio-core
```

`defaults.run.working-directory: qflistudio`，`shell: bash`。Windows 上 `bash` 为 Git Bash。

## 3. Job 拓扑

```
resolve-flutter (ubuntu-24.04)
   │ outputs: version, commit
   ├── windows  matrix {x64: windows-2022, arm64: windows-11-arm}
   ├── linux    matrix {x64: ubuntu-22.04, arm64: ubuntu-22.04-arm}
   ├── macos    matrix {x86_64, arm64} 都在 macos-15
   ├── ios      macos-15
   └── android  ubuntu-24.04
ohos (ubuntu-22.04)  不依赖 resolve-flutter
```

- `resolve-flutter` 读 `https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json` 的 `current_release.stable`，输出版本号与框架提交。手动触发输入 `flutter_version` 非空时，直接用输入值，并经 `git ls-remote` 解析提交。同一次运行内全部官方 job 共用这组输出。
- Linux 选 22.04 镜像，使 glibc 为 2.35，产物可在更多发行版运行。
- macOS 两个架构都在 arm64 runner 上构建。macOS 交叉编译 x86_64 是 Xcode 原生能力，不依赖即将退役的 Intel runner。
- `concurrency: app-installers-${{ github.ref }}`，`cancel-in-progress: true`。`permissions: contents: read`。

## 4. Flutter 安装

| 模式 | 来源 | 校验 | 缓存键 |
|---|---|---|---|
| upstream | `git clone --depth 1 --branch <version> https://github.com/flutter/flutter.git` | `git rev-parse HEAD` 等于解析出的提交 | `flutter-upstream-<version>-<os>-<arch>` |
| ohos | `https://gitcode.com/openharmony-tpc/flutter_flutter.git`，tag `3.27.5-ohos-1.0.1` | 提交等于 `12587c79e88aacf3172a84e536f226457d037594` | `flutter-ohos-12587c79e88a-<os>-<arch>` |

- 统一用 git clone。官方只发 x64 SDK 压缩包，arm64 宿主只能 clone。
- clone 失败重试 3 次。shallow clone 丢 tag 时补抓 tag，使 `flutter --version` 正确。
- `flutter config --no-analytics`。官方模式按 job 打开对应桌面平台。
- `flutter pub get` 在应用目录运行。官方 Flutter 会按自身 SDK 重写 `pubspec.lock`，CI 不回写。

## 5. 各平台构建与打包

### Windows（x64、arm64）

- `flutter build windows --release`。目标架构跟随宿主：`windows-11-arm` 产出 arm64。
- 用 `vswhere` 定位 MSVC，复制对应架构的 `msvcp140.dll`、`vcruntime140.dll`、`vcruntime140_1.dll`（arm64 无 `_1` 时跳过）到 Release 目录。
- `dumpbin /headers` 校验主程序 machine：x64 为 `8664`，arm64 为 `AA64`。
- Inno Setup：ISCC 缺失时用 Chocolatey 安装。`qflistudio.iss` 接收 `/DAppVersion /DSourceDir /DOutputDir /DArch`。arm64 时 `ArchitecturesAllowed=arm64`，x64 时 `x64compatible`。
- 静默安装一次验证安装包可用，步骤超时 10 分钟。
- 另出便携 zip。

### Linux（x64、arm64）

- apt：`clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libstdc++-12-dev`。
- `flutter build linux --release`，产物在 `build/linux/<x64|arm64>/release/bundle`。
- `package_linux.sh <arch>`：安装到 `/opt/qflistudio`，`/usr/bin/qflistudio` 为启动链接，附 `com.azurekiln.qfli.qflistudio.desktop` 与图标。`.deb` 的 `Architecture` 为 `amd64` 或 `arm64`。
- 校验：`file` 校验主程序架构，`dpkg-deb --info` 校验字段，`desktop-file-validate`，`sudo dpkg -i` 安装一次。

### macOS（x86_64、arm64）

- `FLUTTER_XCODE_ARCHS=<arch> flutter build macos --release`。Flutter 把 `FLUTTER_XCODE_*` 环境变量转为 Xcode 构建配置。
- 不开启 `enable-macos-arm64-only`。开启后无法产出 x86_64。
- `thin_macos_app.sh <arch>`：遍历 `.app` 内的 Mach-O。全部单架构时不改动。存在多架构文件时 `lipo -thin`，再用 `codesign --force --deep --sign - --entitlements macos/Runner/Release.entitlements` 做 ad-hoc 重签。
- 校验：每个 Mach-O 的 `lipo -archs` 恰为目标架构，`codesign --verify --deep --strict` 通过。
- `ditto` 暂存，`hdiutil create -format UDZO` 生成 DMG。资源忙时重试 3 次。`hdiutil verify` 并挂载校验内容。

### iOS

- `flutter build ios --release --no-codesign`。
- `Payload/Runner.app` 打成 zip，扩展名 `.ipa`。校验 `Payload/Runner.app/Info.plist` 存在，主程序为 arm64。

### Android

- JDK 17 取镜像的 `JAVA_HOME_17_X64`。`sdkmanager` 安装 NDK `27.0.12077973`（`build.gradle.kts` 固定）。
- `keytool -genkeypair` 现场生成 debug keystore：别名 `androiddebugkey`，口令 `android`，`CN=Android Debug,O=Android,C=US`。导出 `ANDROID_KEYSTORE_PATH`、`ANDROID_KEYSTORE_PASSWORD`、`ANDROID_KEY_ALIAS`、`ANDROID_KEY_PASSWORD`。
- `flutter build apk --release --split-per-abi --target-platform android-arm,android-arm64,android-x64`。
- 校验：每个 APK 只含对应的 `lib/<abi>/`，`apksigner verify --print-certs` 含 `CN=Android Debug`。

### OHOS（arm64）

- 安装 `libgl1-mesa-dev`，再调用 `./qflistudio/.github/actions/setup-ohos`（HarmonyOS 命令行工具，版本与模板一致）。
- 校验 SDK `apiVersion` 为 `26`，与 `targetSdkVersion "26.0.0"` 对应。
- 之后运行 `actions/setup-node`，Node `24.14.1`。它追加的 PATH 晚于命令行工具自带 Node，因此优先。同时导出 `NODE_HOME`。
- 记录 `node --version`、`ohpm --version`、`hvigorw --version`。`node --version` 不是 `v24.14.1` 时失败。
- `strip_ohos_signing.py` 删除 runner 上 `ohos/build-profile.json5` 的签名配置。
- `flutter build hap --release --target-platform ohos-arm64 --no-codesign`。
- 校验：存在 `*-unsigned.hap`，不存在 `*-signed.hap`，HAP 内 `.so` 为 AArch64。

## 6. Action 白名单

全部按 SHA 固定，均已校验为 node24（`research/ci-patterns-and-node24.md` §B.2）：

| action | tag | SHA | 用途 |
|---|---|---|---|
| `actions/checkout` | v7.0.1 | `3d3c42e5aac5ba805825da76410c181273ba90b1` | 检出应用与内核 |
| `actions/cache` | v6.1.0 | `55cc8345863c7cc4c66a329aec7e433d2d1c52a9` | Flutter SDK 缓存 |
| `actions/upload-artifact` | v7.0.2 | `cf430e030ddbb5b0abf93d22962f4752f3646cd9` | 上传产物 |
| `actions/setup-node` | v7.1.0 | `949feb2413d6458794dcd2491c4babbbce0c15c1` | OHOS 的 hvigor 用 Node 24 |

禁止：`subosito/flutter-action`（内部用 node20 的 `actions/cache@v5`），`openharmony-rs/setup-ohos-sdk`（同样问题，且装的是 OpenHarmony SDK）。

## 7. 产物命名

artifact 名：`qflistudio-<version>-<platform>-<arch>`。

| 平台 | 文件 |
|---|---|
| Windows | `QFLIStudio-<version>-windows-<x64|arm64>-setup.exe`、`...-portable.zip` |
| Linux | `qflistudio_<version>_<amd64|arm64>.deb`、`qflistudio-<version>-linux-<x64|arm64>.tar.gz` |
| macOS | `QFLIStudio-<version>-macos-<x86_64|arm64>.dmg` |
| iOS | `QFLIStudio-<version>-ios-unsigned.ipa` |
| Android | `QFLIStudio-<version>-android-<x86_64|armeabi-v7a|arm64-v8a>.apk` |
| OHOS | `QFLIStudio-<version>-ohos-arm64-unsigned.hap` |

`<version>` 取 `pubspec.yaml` 的 `version:`，去掉 `+build`。

## 8. 风险与取舍

| 风险 | 处理 |
|---|---|
| 应用代码按分支的 3.27 框架编写，在官方最新版上可能编译失败 | 实施第一步先在本机用官方最新版跑 `flutter analyze` 与 `flutter build windows`。失败则停下报告，代码适配另开任务 |
| “跟随最新”使构建不可复现，新 stable 可能突然破坏构建 | `BUILD_INFO.txt` 记录版本与提交。手动触发可输入旧版本临时回退 |
| macOS 的 `FlutterMacOS.framework` 可能仍是通用二进制 | `thin_macos_app.sh` 兜底瘦身并重签，最终逐文件校验 |
| HarmonyOS 命令行工具来自第三方转发 `ErBWs/ohos-sdk` | 沿用模板，`setup.sh` 校验 sha256 |
| gitcode 拉分支在 GitHub runner 上可能慢或失败 | 重试 3 次，并缓存 SDK |
| `windows-11-arm`、`ubuntu-22.04-arm` 只对公开仓库免费 | 仓库已公开 |

## 9. 回滚

工作流只新增文件。回滚即删除第 1 节列出的路径。不影响 `.cnb.yml` 与本地构建脚本。
