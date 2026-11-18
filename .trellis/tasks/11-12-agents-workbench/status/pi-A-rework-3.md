# pi-A 第三轮

worktree：`D:\MyNewProjects\_wt\pi-a\qfli_studio_core`，分支 `rework/pi-a`。

## 已完成

- 第一步：`git merge --ff-only rework/integration` 成功。
  `de067bf..a43b7df`，24 个文件，快进。worktree 干净，无冲突。
- pi-A-1：`Breakpoints.agentPaneWidth` 从 360 改为 400。
  改动位置 `lib/layout/breakpoints.dart`，注释写明原因。
  提交 `9965263 fix(editor): widen the wide-screen agent pane to 400`。
- pi-A-2：核查 1100 宽。侧边栏展开与收起两种状态都无溢出。
  1100 宽：侧边栏 280 + 卡片边距 24 + 右栏 400，编辑器列剩 396。
  收起侧边栏时编辑器列 700。两者都可用。
- pi-A-3：常量引用只有 `lib/layout/breakpoints.dart` 一处。
  `editor_page.dart` 两处读 `Breakpoints.agentPaneWidth`，不用改。
  测试与文档都没有硬编码 360（已 grep `test`、`tool`、`spec`）。
  旧测试未改。
- pi-A-4：新增 `test/editor_wide_agent_pane_test.dart`，三个用例：
  1280 宽右栏等于 400 且权限文案可见；1100 宽侧边栏展开无溢出；
  1100 宽侧边栏收起无溢出。全部取 `Breakpoints.agentPaneWidth`，不写死。
  提交 `5454e0a test(editor): cover the 400 agent pane and the 1100 wide layout`。
- 验证：`flutter analyze --no-pub` 无问题。
  `flutter test --no-pub` 1607 通过、9 跳过、4 失败（明细见「未验证」）。
  新测试文件单跑 3/3 通过。

## 进行中

- 无。

## 请求

- pi-A-1 只解决了一半。实测 400 宽时工具行 340，
  权限文案「每次询问」回来，推理强度仍是图标。
  工具行要 380 才能带全文案：加号 48 + 权限 84 + 模型 106 + 推理 65 + 发送 48，
  再加间隔 29。卡片与面板内边距共 60，所以右栏需 440。
  两个方向二选一：右栏 440，或把 `_toolRowComfortWidth` 从 380 降到 340。
  `lib/chat/composer_card.dart` 是 pi-C 的范围，我没有改。
  已看 `pi-C-rework-3.md`，本轮只做了 D1/D2 的会话种子，没接到这条。请定方向。
- `test/interop_arkts_contract_test.dart` 的
  「the module exports the ability the Studio target names」失败：
  `Bad state: missing ...\_wt\pi-a\qfli_java\ohos\entry\src\main\module.json5`。
  `_wt\pi-a\qfli_java` 只检出 `.trellis` 与 `ohos`，内容不全。
  主仓 `D:\MyNewProjects\qfli_java` 里该文件存在，所以是 worktree 检出不全。
  与本轮改动无关。请补齐该 worktree，或由 pi-D 确认。

## 未验证

- `flutter test --no-pub` 的 4 个失败：
  `test/editor_run_target_test.dart` 3 个（允许的既有失败）；
  `test/interop_arkts_contract_test.dart` 1 个（环境缺失，见「请求」）。
- 真机 / 设备外观未看，未截图。本轮 brief 未要求。
- 未在 macOS、Linux 上跑，只在 Windows 上跑。
- 未跑 `pubspec_overrides.yaml` 指向集成 worktree 的构建（pi-D 负责）。
