# pi-A 第四轮

worktree：`D:\MyNewProjects\_wt\pi-a\qfli_studio_core`，分支 `rework/pi-a`。
上一轮遗留的未提交改动（顶栏与分段条）本轮收尾，已提交。

## 已完成

- 第一步：`git merge --ff-only rework/integration` 成功，`5454e0a..318e443`，
  16 个文件快进。worktree 干净，无冲突。
- pi-A-1（顶栏标题被挤成「Ba…」）：
  顶栏机器人图标只在 `layoutOf(width) == WorkbenchLayout.wide` 时渲染。
  窄屏与中屏不再有它。改动 `lib/editor/editor_page.dart` 的 `build`。
- pi-A-2（角标改挂分段条）：新增 `AgentSegmentIcon`
  （`lib/editor/agent/agent_dock.dart`），挂在分段条的「Agent」段上。
  计数抽成 `agentBadgeCount()`，顶栏与分段条共用一份，数字一致。
  `AgentPaneSwitcher` 新增可选 `agentIcon` 参数。
- pi-A-3（菜单里的「AI 助手」保留）：未触碰，旧测试仍通过。
- pi-A-4（测试）：新增 `test/editor_top_bar_title_test.dart`，5 个用例：
  424 宽开关两种状态下标题渲染宽度相同且未被截断；
  424 宽分段条无溢出、高度不小于 44；
  424 宽角标挂在「Agent」段上；
  900 宽仍无顶栏图标；
  1280 宽顶栏图标与角标照旧。
- pi-A-5（触摸目标）：分段条加 `minimumSize: Size(0, 44)`，
  424 宽下单一分段不溢出。
- 验证：`flutter analyze --no-pub` 无问题。
  `flutter test --no-pub -j 1`：1629 通过、9 跳过、4 失败（见「未验证」）。
  新测试单跑 5/5 通过。
- 提交：`9a6f4e8 fix(editor): hide the duplicate agent icon on narrow top bars`。
  只 add 了 4 个明确路径，`git status -s` 已空。

## 进行中

- 无。

## 请求

- 第三轮遗留：宽 400 时输入卡片工具行 340，推理强度仍只有图标。
  `lib/chat/composer_card.dart` 是 pi-C 的范围，本轮未动。
  pi-C 第四轮在改 `_fitFor` 的折叠顺序，请由它一并收口。
- `test/interop_arkts_contract_test.dart` 的 1 项失败是 worktree 同级
  `qfli_java` 检出不全，与本轮改动无关，需要补齐检出或由 pi-D 确认。

## 未验证

- `flutter test --no-pub -j 1` 的 4 个失败，与 allowlist 完全一致：
  `test/editor_run_target_test.dart` 3 项（既有失败）；
  `test/interop_arkts_contract_test.dart` 1 项（环境缺失，见「请求」）。
- 真机截图未复看，424 宽只用 widget 测试断言，没有设备取证。
- 未在 macOS、Linux 上跑，只在 Windows 上跑。
- 未跑 `pubspec_overrides.yaml` 指向集成 worktree 的构建（pi-D 负责）。
