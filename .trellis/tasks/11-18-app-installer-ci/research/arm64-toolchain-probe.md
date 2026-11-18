# arm64 桌面工具链与 Node 核对（主会话实测，2026-11-18）

## OHOS 分支 Flutter 3.27.5-ohos-1.0.1

本地安装：`D:/ProgramFiles/flutter_ohos`。

| 项 | 值 | 来源 |
|---|---|---|
| 标准平台引擎 | `42d3d75a56efe1a2e9902f52dc8006099c45d937` | `bin/cache/engine.stamp` |
| OHOS 引擎 | `ab1841593ed352873a3d26cb41e942e90b813be0` | `bin/cache/engine.ohos.stamp` |
| 标准平台产物地址 | `storage.googleapis.com/flutter_infra_release/flutter/<engine>/` | `packages/flutter_tools/lib/src/cache.dart:1015` |
| Dart SDK 地址 | `flutter-ohos.obs.cn-south-1.myhuaweicloud.com/flutter_infra_release/flutter/<ohos engine>/` | `bin/internal/update_dart_sdk.sh:129-130` |

HTTP HEAD 结果（标准平台引擎，Google 存储）：

| 产物 | 状态 |
|---|---|
| windows-x64/artifacts.zip、windows-x64-release/windows-x64-flutter.zip | 200 |
| windows-arm64/artifacts.zip、windows-arm64-release/windows-arm64-flutter.zip | **404** |
| linux-x64、linux-arm64 的 artifacts.zip 与 flutter-gtk.zip | 200 |
| darwin-x64、darwin-arm64 artifacts.zip | 200 |

HTTP HEAD 结果（Dart SDK，华为 OBS）：

| 产物 | 状态 |
|---|---|
| dart-sdk-linux-x64.zip、dart-sdk-windows-x64.zip | 200 |
| dart-sdk-darwin-x64.zip、dart-sdk-darwin-arm64.zip | 200 |
| dart-sdk-linux-arm64.zip、dart-sdk-windows-arm64.zip | **404** |

工具限制：

- `packages/flutter_tools/lib/src/commands/build_linux.dart:87-92`：x64 宿主交叉编译 linux-arm64 直接 `throwToolExit`。
- `update_dart_sdk.sh:110-111`：Windows 宿主固定下载 `dart-sdk-windows-x64.zip`。

结论：OHOS 分支无法产出 Windows arm64 与 Linux arm64 安装包。

- Windows arm64：引擎无 windows-arm64 产物。
- Linux arm64：不能交叉编译。arm64 宿主又缺 linux-arm64 Dart SDK。

## upstream Flutter stable

- 当前 stable：`3.50.0`，框架 `ab2912035e160d9cad6306df307576da6128ebdb`，Dart `3.14.0`，发布于 2026-11-11（`releases_linux.json`）。
- 引擎：`371f77202a73e8dff57a8b3bff75bca55c090aee`（`flutter/flutter@stable bin/internal/engine.version`）。

HTTP HEAD 结果（Google 存储）：

| 产物 | 状态 |
|---|---|
| windows-arm64/artifacts.zip、windows-arm64-release/windows-arm64-flutter.zip | 200 |
| dart-sdk-windows-arm64.zip | 200 |
| linux-arm64/artifacts.zip、linux-arm64-release/linux-arm64-flutter-gtk.zip | 200 |
| dart-sdk-linux-arm64.zip | 200 |

结论：upstream 3.50.0 在 arm64 宿主上具备构建 Windows arm64 与 Linux arm64 的全部产物。
官方只发 x64 SDK 压缩包，arm64 宿主需 `git clone --branch 3.50.0`，首次运行时下载 arm64 产物。
Dart 3.14.0 满足 `pubspec.yaml` 的 `sdk: ^3.11.5`。
应用代码能否在 3.50.0 框架上编译尚未验证。代码按分支的 3.27 框架编写。

更正：`ci-patterns-and-node24.md` §C.2 与 §C.3 称 upstream 无法构建 Windows arm64、Linux arm64。上述 HEAD 结果推翻该结论。

## Node

- 本地 DevEco 自带 Node：`D:/ProgramFiles/Huawei/DevEco Studio/tools/node/node.exe` → `v24.14.1`。本地 hvigor 用它运行。
- CI 的 HarmonyOS 命令行工具来自 `ErBWs/ohos-sdk` release（最新 tag `6.1.1.280`）。其自带 Node 版本需在 CI 首跑时记录。
- 本仓库 `.cnb.yml` 镜像为 `node:24.15.0-bookworm`，已是 Node 24。
