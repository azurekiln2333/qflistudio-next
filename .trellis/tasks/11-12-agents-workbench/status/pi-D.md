# pi-D 状态（W-D）
## 已完成
**1 core 历史同步**
- worktree `_scratch\core-sync-wt`；分叉 106/49，merge-base `96e23df`。
- 前提已验证：远端 532 个文件在 `main` 中全在（缺 0），`main` 共 613 个。
- `merge -X ours` 结果树只差 `settings_page.dart` +6 行，是重复 `dispose()`（`main:236-240` 已有）。
- 改 `merge --no-ff -s ours github/main`，结果树 `99110c6` 与 `main` 完全一致。
- 提交 `573d1b6`，父 `4b05bc0`+`5b3c48c`；`main` 用 `--ff-only` 快进，工作树文件未变。

**2 推送（已执行，四个 remote 全部成功）**
- core：`github`/`gitee`/`cnb`/`gitcode` 均 `5b3c48c..573d1b6`；`gitlab` 不可达，跳过。
- studio：同四家均 `907f45c..c0ebf62`。
- 复核：两仓库四个 remote 的 `main` SHA 均等于本地 HEAD；全程无 force push。

**3 签名配置（已执行）**
- `android/app/build.gradle.kts` 先读 `android/key.properties`，再读四个 `ANDROID_*` 环境变量；都没有时 release 抛 `GradleException`，不回退 debug 证书（原第 38 行 `getByName("debug")` 已删）。
- keytool 验证：PKCS12，别名 `suanxiwanjie` 为 PrivateKeyEntry，限期至 2076-09-01；store 密码与 key 密码均通过（key 密码用 `-certreq` 验证）。密码只写进 `android/key.properties`，`git check-ignore` 证实被 `android/.gitignore:12` 忽略且未跟踪。

**4 wrapper（已执行）** 选入库：`android/.gitignore` 删 `gradle-wrapper.jar`、`/gradlew`、`/gradlew.bat` 三行。理由：Gradle 固定 8.14，CI 镜像不必预装 Gradle。

**5 干净检出构建（已执行）**
- 并列 worktree `_scratch\ci-sim\{qflistudio,qfli_studio_core}`，均 `main` 干净检出；确认其中确缺 wrapper 与 `key.properties`。
- 失败路径：不配密钥 → 24 秒 `BUILD FAILED`，提示 debug 证书永不用于 release，退出码 1。
- 成功路径：仅四个 `ANDROID_*` → 110.5 秒成功。APK 在 `_scratch\ci-sim\qflistudio\build\app\outputs\flutter-apk\app-release.apk`（72.3 MB）。
- `apksigner verify --print-certs`：`CN=suanxiwanjie`，SHA-256 `995456d7…80b2`，与 keytool 指纹一致；v2=true；无 `Android Debug`。
- `aapt2 dump badging`：`versionCode=5000001`、`versionName=5.0.1`，与 `pubspec.yaml:5` 一致。

**6 CI 配置（已执行）**
- 字段名按官方文档核对：任务级 `allowFailure`（grammar `#job-allowfailure`）、`imports`（密钥仓库）、`type: git:release`、附件插件 `cnbcool/attachments:latest` + `settings.attachments`。
- PR 流水线新增 `verify-flutter-workbench`，带 `allowFailure: true`：并列检出 core → 两端 `pub get`/`analyze`/`test`。
- tag 流水线新增 `release-apk`，同样 `allowFailure: true`：检出 → `ANDROID_KEYSTORE_BASE64` 落盘 → `flutter build apk --release` → `apksigner` 拒绝 debug 证书 → `git:release` → 上传 APK。
- 校验：`yaml.safe_load` 通过；`node scripts/check-root-ci.mjs` 退出 0；`.cnb.yml` 转 LF 后 `node --test scripts/check-root-ci.test.mjs` 12/12 通过。

## 进行中
无。

## 请求
- `scripts/check-root-ci.test.mjs` 本机 5 项失败：`core.autocrlf=true` 使变异字符串不匹配，LF 副本 12/12 通过，非本任务引入，未改。

## 未验证
- Flutter 镜像：`FLUTTER_BUILD_IMAGE` 默认 `cnbcool/default-dev-env:latest`，不含 OHOS Flutter 与 Android SDK。
- CNB runner 能否用 `imports` 注入密钥文件、用 `CNB_TOKEN` 克隆私有 core。
- `git:release` 与 `cnbcool/attachments` 在 tag_push 的实际结果。
- 真实流水线结果（本阶段不提交、不打 tag）。

## 用户操作
1. 在 CNB 密钥仓库建文件，写入 `ANDROID_KEYSTORE_BASE64`（`base64 -w0 suanxiwanjie.jks`）、`ANDROID_KEYSTORE_PASSWORD`、`ANDROID_KEY_ALIAS`、`ANDROID_KEY_PASSWORD`，再把该文件 URL 填进两个 Flutter 任务的 `imports:`。
2. 造 Flutter 镜像：装 `3.27.5-ohos-1.0.1`（`gitcode.com/openharmony-tpc/flutter_flutter`，分支 `oh-3.27.4-dev`）、Android SDK、JDK 17。跑通后改两个任务的 `image:`，并删掉两处 `allowFailure: true`。
3. 确认 `CNB_TOKEN` 能克隆 `azurekiln/qflistudio-core`；不能就改 `CORE_REPO_URL` 或改用只读令牌。
4. 推广：先改 `pubspec.yaml:5` 版本号再 `git tag v5.0.2 && git push cnb v5.0.2`，触发 `release-apk`。
5. 验收：Release 页出现 `app-release.apk`；下载后 `apksigner verify --print-certs` 的 CN 必须是 `suanxiwanjie`。
6. CI 不可用时：直接上传第 5 步本机构建的 `app-release.apk`。
