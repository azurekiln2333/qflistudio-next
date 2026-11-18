# D：跨仓库 CI/CD 与 APK release

## 结论

**现在不能直接推送并发布 APK。** 四个阻塞项，按严重度排：

1. **core 已分叉。** 对 github/main 落后 49、领先 106。studio 可快进（领先 118、落后 0）。
   两个仓库的 github/gitee/cnb/gitcode 镜像 SHA 全一致。
2. **APK release 用 debug 证书签名。** `android/app/build.gradle.kts:38` 是指向 `debug` 的 `signingConfig`。
   仓库内无 keystore：`key.properties`、`*.jks`、`*.keystore` 被 `android/.gitignore:11-14` 忽略，磁盘上也不存在。
3. **干净检出后没有 gradle wrapper。** `android/.gitignore:1` 忽略 `gradle-wrapper.jar`，`:4` 忽略 `gradlew`/`gradlew.bat`。
4. **没有可用的托管 CLI。** 无 `gh`（`gh auth status` 无法执行），无 `cnb`、`glab`。
   Flutter 是 OHOS 第三方分支 `gitcode.com/openharmony-tpc/flutter_flutter`（`oh-3.27.4-dev`，
   版本串 `3.27.5-ohos-1.0.1`，Dart `3.11.5`）。

**推荐：在 CNB 上并列检出两个仓库。** 该仓库已有可用 CNB 流水线，`tag_push` 触发已在本文件验证过
（`.cnb.yml:191-192`）。且 studio 用相对路径依赖 `../qfli_studio_core`（`pubspec.yaml:17-18`），
并列检出后 `pubspec.yaml` 一行都不用改。

**用户必须提供 secrets：** `ANDROID_KEYSTORE_BASE64`、`ANDROID_KEYSTORE_PASSWORD`、
`ANDROID_KEY_ALIAS`、`ANDROID_KEY_PASSWORD`。

**一次性手工操作：** 造 keystore、把 core 对齐并推送、把 studio 118 个提交推送、
在 CNB 配 secrets、准备装 OHOS Flutter 的 CI 镜像、打第一个 tag。

未验证：CNB release 上传接口、CNB 能否访问 gitcode、`flutter build apk` 能否成功。本轮只读，未构建。

## 1. 仓库与托管平台

| 项 | studio | core |
| --- | --- | --- |
| 本地路径 | `D:\MyNewProjects\qflistudio` | `D:\MyNewProjects\qfli_studio_core` |
| 默认分支 / upstream | `main` / `github/main` | `main` / `github/main` |
| 领先 / 落后 github/main | 118 / 0（可快进） | 106 / 49（已分叉） |

**brief 说「studio 可能没配 remote」，不成立。** 两个仓库都配了 5 个 remote，
分别落在 `cnb.cool/azurekiln`、`gitcode.com/azurekiln`、`gitee.com/azurekiln`、
`github.com/azurekiln2333`、`gitlab.com/azurekiln-team`，仓库名 `qflistudio-next` 与 `qflistudio-core`。
core 无 gitlab 远端（`ls-remote` 不可达）。

所有 remote 的 `main` 与 github 同 SHA，镜像同步正常。
**两个仓库都没有任何 tag**（`git tag` 为空），R10 的 tag 发布从未跑过。

## 2. studio 依赖 core 的方式

**相对路径依赖，不是 git 依赖，也不是 submodule。**

- `pubspec.yaml:17-18`：`qfli_studio_core: path: ../qfli_studio_core`。
- `pubspec.yaml:27` 起 `dependency_overrides`：`re_editor: path: ../qfli_studio_core/vendor/re_editor`。
  core 的 `vendor/re_editor` 已被 git 跟踪（186 个文件）。
- 两个仓库都没有 `.gitmodules`，`git submodule status` 为空。

推论：CI 把两个仓库检出成**同级目录**，两条 path 依赖同时成立，无需改 `pubspec.yaml`。
这是本方案改动面最小的地方。

## 3. 现有 CI 文件

| 仓库 | 文件 | 作用 |
| --- | --- | --- |
| studio | `.cnb.yml`（根） | 构建并推送 3 个 Node 服务镜像 |
| studio | `azurekiln-qfli-server/.cnb.yml` | 嵌套服务仓库自己的流水线 |
| core | 无 | 没有任何 CI 文件 |

**没有任何 GitHub Actions / GitLab CI / CircleCI 配置，没有 `.github/` 目录。**
根流水线的 `verify-services`、`publish-images`、`pull_request` 三段只覆盖服务镜像，与 Flutter/APK 无关。
真正在跑的是 **CNB（cnb.cool）**，且已支持 tag 触发（`.cnb.yml:191-192` 的 `"v*": tag_push:`）。

## 4. Android 构建方式

- Flutter：`3.27.5-ohos-1.0.1`，来自 `D:\ProgramFiles\flutter_ohos`，
  源头 `gitcode.com/openharmony-tpc/flutter_flutter` 的 `oh-3.27.4-dev`。**不是上游 Flutter。**
- Dart `3.11.5`，两个 `pubspec.yaml` 都要求 `sdk: ^3.11.5`。
- 构建命令：`flutter build apk --release`（本轮未执行 → 未验证）。
- 版本号来源：`pubspec.yaml:5` 的 `version: 5.0.1+5000001`，经
  `android/app/build.gradle.kts:30-31` 注入。签名位置 `:36-39`，当前指 `debug`。
- keystore：**不在仓库内**，被 `android/.gitignore:11-14` 忽略，磁盘上也没有。
- Gradle wrapper 8.14、AGP 8.11.1、Kotlin 2.2.20、`ndkVersion` 钉死 `27.0.12077973`。
  `gradle-wrapper.jar`、`gradlew`、`gradlew.bat` **未纳入 git**（只在本地存在）。

## 5. 本机托管平台 CLI

- `gh`：**未安装**，`gh auth status` 无法执行。`cnb`、`glab` 也未安装。
- `git`、`flutter`、`dart` 可用。已有 git 凭据对 github 可用（`git ls-remote` 无需交互即成功）。

结论：**没有可用的托管平台 CLI**，登录状态无法在本机确认。

## 6. 三种跨仓库方案比较

前提：studio 是相对路径依赖，CI 必须让 `../qfli_studio_core` 真实存在。

| 方案 | 可行性 | 改动面 | 风险 |
| --- | --- | --- | --- |
| 并列检出两仓库（推荐） | 可行 | 零改动 | 需 CI 能访问 core 私有仓库 |
| 改 git 依赖 | 可行 | 改 `pubspec.yaml` | core 已分叉，`1.0.0+1` 无 tag 可钉 |
| submodule | 可行 | 加 `.gitmodules` 与 gitlink | 每次 core 变更都要更新 gitlink |

推荐**并列检出**：唯一不用改仓库内容的方案，且天然满足 `../qfli_studio_core/vendor/re_editor` 覆盖。
另两种都要先解决 core 分叉。

## 7. Secrets 与一次性手工操作

Secrets（只给名字，不写值）：`ANDROID_KEYSTORE_BASE64`、`ANDROID_KEYSTORE_PASSWORD`、
`ANDROID_KEY_ALIAS`、`ANDROID_KEY_PASSWORD`；若用令牌拉 core，再加一个只读仓库令牌。

一次性手工操作：造 release keystore 并转 base64 → 把 core 对齐推送 → 推送 studio 的 118 个提交 → 在 CNB 配 secrets → 准备装了 `oh-3.27.4-dev` Flutter 的 CI 镜像 → 给两个仓库打第一个 tag。

## 8. Workflow 草案

本阶段不创建 `.github/` 下任何文件，也不改 `.cnb.yml`。草案如下：

```yaml
# 追加到 .cnb.yml，现有服务镜像段落不变
main:
  pull_request:
    - name: verify-flutter
      docker: { image: <ohos-flutter-image> }
      stages:
        - name: analyze-and-test
          script: |
            set -euo pipefail
            cd .. && git clone --depth 1 "$CORE_REPO_URL" qfli_studio_core && cd qflistudio
            flutter pub get
            (cd ../qfli_studio_core && flutter pub get && flutter analyze && flutter test)
            flutter analyze && flutter test

"v*":
  tag_push:
    - name: release-apk
      docker: { image: <ohos-flutter-image> }
      stages:
        - name: build-and-publish
          script: |
            set -euo pipefail
            cd .. && git clone --depth 1 "$CORE_REPO_URL" qfli_studio_core && cd qflistudio
            printf '%s' "$ANDROID_KEYSTORE_BASE64" | base64 -d > android/app/release.jks
            printf 'storeFile=release.jks\nstorePassword=%s\nkeyAlias=%s\nkeyPassword=%s\n' \
              "$ANDROID_KEYSTORE_PASSWORD" "$ANDROID_KEY_ALIAS" "$ANDROID_KEY_PASSWORD" \
              > android/key.properties
            flutter build apk --release
            # 在 CNB 创建 release 并上传 APK，具体接口未验证
            ls -l build/app/outputs/flutter-apk/app-release.apk
```

签名段要求先改 `android/app/build.gradle.kts:36-39`，让它从 `key.properties` 读配置，否则注入不生效。

## 9. 未验证

- `flutter build apk` 在本机或 CI 能否成功（本轮禁止构建）。
- CNB 的 release 上传接口，以及 CNB runner 能否访问 gitcode.com 拉 OHOS Flutter。
- wrapper 缺失时 `flutter build apk` 是否会自动重建（未在本仓库验证）。
