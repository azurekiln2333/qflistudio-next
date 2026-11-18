# pi-D 返工状态（后端配置、真机工具、预览工具、隔离调研）

## 已完成

**1 后端 API 与 KEY 配置（任务 1）**
- README「AI 与联网工具」扩写：8 个变量的表、`.env` 示例（全占位符）、重启命令、验证 curl、200/401/403/503/502/429/504 各自含义、并行会话为何要调大并发与限流。
- 核对 `docker-compose.yaml`：`env_file: - .env`，变量在**创建容器时**注入。所以写 `docker compose up -d --force-recreate server`；`docker compose restart` 不重读 `env_file`，已在文档里点明。
- `.env.example`：新增 `QFLI_AI_REASONING_EFFORTS`，四个 AI 变量各加一行中文注释。
- 证据：`git diff --stat` → `README.md +91`、`.env.example +7`。`src/`、`test/` 未改（那两处改动开工前就在）。

**2 mock 上游验证（任务 1 第 4 步）**
- 脚本 `_scratch\pi-d\mock-upstream.js`、`verify-ai-config.js`，不入库。挂真实 `src/routes/ai.js`，补上 `server.js` 的 promise 包装与错误中间件，用替身中间件替代 `authRequired`。
- 结果 **12/12 通过，退出码 0**：未配置 → models 与 chat 都 503；已配置 → models 200 返回 2 个模型；chat 200 且 `aiGenerated=true`、未传 model 用列表第一个；未开启推理强度传 `reasoning_effort` → 400；开启后列表带 `["low","medium","high"]`，上游收到 `reasoning_effort=high` 与 Bearer 头。
- 未使用任何真实密钥。服务端 `.env` 不存在，全部 AI 变量未配置（只报告存在性，未读值）。

**3 真机工具（任务 2）**
- 新增 `tool/build_studio_hap.sh`：复用 `tool/lib/hvigor_env.sh`，自动用 DevEco 自带 JBR，不带 `--parallel`，打包前打印实际内核路径。
- 新增 `tool/device_ui.sh`：`targets/install/launch/stop/shot/tap/swipe/text/input/back/home/wake/screen-on/layout/log/wait`，设备地址读 `HDC_TARGET`。
- 新增 `tool/agent_workbench_device.md`：用法、集成时 `pubspec_overrides.yaml` 的做法、两个坑（MSYS 改写设备路径、锁屏下 `aa start` 失败）。
- `pubspec_overrides.yaml` 已写进 `.git/info/exclude`（本地忽略，未改 `.gitignore`），`git check-ignore -v` 命中第 23 行。**未创建该文件**。
- 证据：两份脚本 `bash -n` 均 0；`targets` → `192.168.68.207:46551`；`install` → `install bundle successfully`；`shot` 出图 2.7 MB；`wake`、`screen-on` 生效。

**4 预览工具（任务 3）**
- 新增 core `tool/agent_preview_test.dart`，已提交 `646a282`。
- 输入：场景名→widget、尺寸列表、主题列表；输出 PNG；加载 MaterialIcons 与中文字体（同一份中文字体也注册到 `monospace`，否则等宽族里的中文是方块）。
- 3 个基线场景（empty / conversation / failed）× 4 尺寸（390/600/900/1280）× 2 主题 = 24 张，落在 `check/screens/pi-d/preview-baseline/`。
- 证据：`flutter test --no-pub tool/agent_preview_test.dart` → 24 张，All tests passed；`flutter analyze --no-pub` 全仓 No issues found。

**5 会话分支调研（任务 4）**
- `research/G-agent-isolation.md`：结论先行（桌面 worktree 能做；手机与鸿蒙只能写时复制叠加层；云端现在不能做，服务端 cloud git 固定 503），后接 9 节。

## 进行中

无。

## 请求

- **真机锁屏**：设备停在人脸/PIN 锁屏（`00e-wake2.png`、`01-home.png` 显示「未识别成功」），`aa start` 报 `10106102`，开发者模式不允许自动解锁。需要人工解锁一次，再跑 `tool/device_ui.sh screen-on 600000` 与 `launch`，才能出「主页 + 打开项目」两张基线截图。
- **基线 UI 问题（不属我的范围）**：390 宽下输入卡片的模型按钮被截断成「1…」，见 `preview-baseline/empty-390x844-light.png`。归 pi-C。
- 服务端 `src/ai-client.js`、`test/ai-relay.test.js` 开工前就有未提交改动，我没动。README 的推理强度说明按当前工作树行为写。

## 未验证

- 真机：启动、主页截图、打开项目截图（被锁屏挡住）。
- `build_studio_hap.sh` 未实跑（会重编 166 MB 包，且当前装的是上一轮产物），只做了 `bash -n` 与依赖路径核对。
- `device_ui.sh` 的 `tap/text/input/back/layout/log` 未逐条实跑（锁屏下无法验证界面交互）。
- README 里的 curl 验证命令未对真实部署执行（无 `.env`、无真实令牌）。
- core 全量 `flutter test --no-pub` 未跑，只跑了 `analyze` 与预览工具本身。
