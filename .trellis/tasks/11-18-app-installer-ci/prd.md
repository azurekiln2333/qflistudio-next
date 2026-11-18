# 产品安装包云构建工作流（GitHub Actions）

## Goal

为 qflistudio 新建 GitHub Actions 安装包工作流。
推送后，GitHub 云端产出 11 个目标平台的安装包。
工作流运行时不出现 "Node.js 20 is deprecated" 警告。

## Background

- 本仓库没有 `.github/workflows`。本地、全部远端分支、git 历史都没有。
- GitHub 远端 `azurekiln2333/qflistudio-next` 公开，默认分支 `main`。
- 现有 CI 只有 CNB 的 `.cnb.yml`。其镜像 `node:24.15.0-bookworm` 已是 Node 24。本任务不改它。
- 主项目没有 native 层构建。本任务只做产品安装包。
- 内核依赖：`pubspec.yaml:17-18` 用 `path: ../qfli_studio_core` 引用内核。`pubspec.yaml:27-30` 把 `re_editor` 指向内核的 `vendor/re_editor`，该目录已入库。内核仓库 `azurekiln2333/qflistudio-core` 公开，默认分支 `main`。
- `pubspec_overrides.yaml` 未跟踪，只供本地集成。CI 不依赖它。
- 本地工具链：Flutter OHOS 分支 `3.27.5-ohos-1.0.1`，Dart `3.11.5`。`pubspec.yaml` 要求 `sdk: ^3.11.5`。
- OHOS 分支出不了 Windows arm64 与 Linux arm64。upstream stable `3.50.0`（Dart 3.14.0）具备两者的全部产物。证据见 `research/arm64-toolchain-probe.md`。
- `android/app/build.gradle.kts:88-99`：release 构建缺签名变量时故意失败，没有 debug 回退开关。
- `ohos/build-profile.json5:3-31`：两套签名配置指向本机绝对路径，CI 上不存在。
- 本地 DevEco 自带 Node `v24.14.1`，本地 hvigor 用它运行。
- 相邻仓库 `qfli_python` 有一套 app-*.yml，全部 action 已是 node24，作为参考模板。
- 调研记录：`research/app-build-facts.md`、`research/ci-patterns-and-node24.md`、`research/arm64-toolchain-probe.md`。

## Requirements

### R1 目标平台与产物

| 平台 | 架构 | 产物 | 工具链 |
|---|---|---|---|
| Windows | x86_64、arm64 | 每个架构一个 Inno Setup 安装包，另附便携 zip | 官方最新 stable |
| Linux | x86_64、arm64 | 每个架构一个 `.deb`，另附 `.tar.gz` | 官方最新 stable |
| macOS | x86_64、arm64 | 每个架构一个单架构 DMG | 官方最新 stable |
| iOS | arm64 | 未签名 IPA | 官方最新 stable |
| Android | x86_64、armeabi-v7a、arm64-v8a | 每个 ABI 一个 APK | 官方最新 stable |
| OHOS | arm64 | 未签名 HAP | OHOS 分支 `3.27.5-ohos-1.0.1` |

### R2 工具链

- OHOS 只用 OHOS 分支 Flutter 构建。
- 其余 10 个包用官方 Flutter 最新 stable。每次运行时解析一次版本，全部非 OHOS job 共用该版本。
- 手动触发时可输入 Flutter 版本，覆盖“最新 stable”。
- 每个产物的 `BUILD_INFO.txt` 记录 Flutter 版本、框架提交、应用提交、内核提交。

### R3 内核检出

- 默认检出 `qflistudio-core` 的 `main`。
- 手动触发时可输入内核 ref。
- 内核放在应用的同级目录 `qfli_studio_core`，使 `../qfli_studio_core` 可解析。

### R4 签名

- Android 使用 CI 现场新建的 debug key 签名，经现有 `ANDROID_*` 变量传入。不改 `build.gradle.kts`。
- iOS、macOS、OHOS 产物不签名。macOS 保留 ad-hoc 签名，使 Apple Silicon 可启动。
- 工作流不读取任何签名 Secret。

### R5 Node 运行时

- 工作流引用的每个 JavaScript action 都声明 `runs.using: node24`。composite action 内部同样满足。
- 每个外部 action 按提交 SHA 固定。
- 不使用 `FORCE_JAVASCRIPT_ACTIONS_TO_NODE24` 等变量压警告。
- 运行 hvigor 的 Node.js 为 24.14.1，与本地 DevEco 一致。

### R6 触发

- 推送到 `main`，且改动命中构建输入路径：`lib/`、`assets/`、六个平台目录、`pubspec.*`、`tool/ci/`、`.github/`。
- 推送到 `ci/**` 分支。用于验证工作流本身。
- 推送 `v*` tag。
- 指向 `main` 的 pull request，且改动命中构建输入路径：`lib/`、`assets/`、六个平台目录、`pubspec.*`、`tool/ci/`、`.github/`。
- 手动触发。

## Acceptance Criteria

- [ ] AC1：`.github/workflows/app-installers.yml` 存在，可手动触发。手动触发提供 Flutter 版本与内核 ref 两个输入。
- [ ] AC2：一次运行产出 R1 表中的 11 个安装包。每个平台、每个架构各上传一个 artifact，内含安装包、`BUILD_INFO.txt`、`SHA256SUMS`、`LICENSE`。
- [ ] AC3：一次完整运行的 Annotations 中没有 "Node.js 20 is deprecated" 警告。
- [ ] AC4：每个 `uses:` 都按 SHA 固定，且已核对为 node24 或 composite。核对表写入 research。
- [ ] AC5：工作流核对产物架构，不符即失败：
  - Windows：`dumpbin /headers` 的 machine 字段与架构一致。
  - Linux：`file` 输出与架构一致，`.deb` 的 `Architecture` 字段一致。
  - macOS：`.app` 内每个 Mach-O 只含目标架构。
  - Android：每个 APK 只含一个 `lib/<abi>/`，签名者为 `CN=Android Debug`。
  - OHOS：HAP 内的 `.so` 为 AArch64，且不存在 `*-signed.hap`。
- [ ] AC6：非 OHOS job 的 `flutter --version` 日志为本次解析出的官方版本。OHOS job 为 `3.27.5-ohos-1.0.1`。
- [ ] AC7：OHOS job 日志中 hvigor 所用 `node --version` 为 `v24.14.1`。

## Out of Scope

- Windows x86（32 位）与 Linux x86（32 位）。Flutter 不支持。
- native 层构建。
- 正式签名、公证、商店上架、GitHub Release 发布。
- 修改 `.cnb.yml`、`build.gradle.kts`、`build-profile.json5` 及其他仓库的工作流。签名剥离只发生在 runner 上。
- 应用代码适配官方新版 Flutter。若出现编译错误，另开任务处理。
