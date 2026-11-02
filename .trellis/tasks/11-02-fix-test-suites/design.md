# 测试全绿：设计与失败分类

## 边界

本任务只修测试失败，不新增功能。

- 改：`qfli_studio_core` 的 `lib/editor/editor_controller.dart`、`lib/pages/points_page.dart`、
  `lib/pages/tasks_page.dart`、`tool/vibe_e2e_local_executor.dart`、`lib/pages/home_page.dart`
  （仅在需要时），`qflistudio` 的 `lib/main.dart`。
- 不改：服务端 `azurekiln-qfli-server`、`lib/interop`、`ets/interop`、其他 worker 正在改的文件。

## 失败分类（9 个）

| # | 测试 | 现象 | 分类 |
| --- | --- | --- | --- |
| 1 | `editor_reload_from_disk_test.dart`（3 例） | `reloadFromDisk` 方法不存在 | 丢失实现 |
| 2 | `points_page_test.dart` | `PointsPage` 缺 `client` 命名参数 | 丢失实现 |
| 3 | `tasks_page_checkin_test.dart` | 缺 `activity` 命名参数 | 丢失实现 |
| 4–6 | `vibe_e2e_harness_test` / `vibe_e2e_local_executor_test` / `vibe_e2e_runner_test` | `tool/vibe_e2e_local_executor.dart:479` 传给 `InteropTransport` 的 `available` 参数不存在 | 丢失实现（测试侧工具） |
| 7 | `vibe_live_e2e_test.dart` | 同上，共用 `tool/vibe_e2e_local_executor.dart` | 丢失实现 |
| 8 | `studio_home_release_test.dart`：Tab 数 | 期望 4 个 Tab，实际 5 个 | 测试过时 |
| 9 | `studio_home_release_test.dart` / `studio_content_repository_test.dart`：本地内容 3 例 | 主 App 走进在线 `TutorialsTab`，发出真实请求得到 400 | 丢失实现（档位配置） |

## 关键判断

### 1–3、4–7：测试即规格

这四处都是「测试描述了行为，实现里没有」。测试保留断言，按描述补实现：

- `reloadFromDisk`：干净缓冲区从磁盘重读，脏缓冲区保留并返回提示，内容未变时保持选区。
- `PointsPage(client:)`、`TasksPage(activity:)`：注入边界，测试据此替换真实服务。
- `InteropTransport.available`：`tool/` 下的测试执行器按旧签名构造，需与
  `lib/interop/interop_transport.dart` 的现行构造对齐。

### 8：测试过时，改测试

`home_page.dart` 在 2026-10-24（`af91e9f`）新增了「工作区」Tab，测试是 2026-11-01
（`c671f29`）写的却断言 4 个 Tab，且同一测试已经在断言「工作区」标签存在。
Tab 数与「工作区」断言自相矛盾，说明这是笔误而不是要锁定的行为。
改法：`findsNWidgets(4)` → `findsNWidgets(5)`，并保留全部标签断言。

### 9：丢失实现，改主 App 档位

`StudioProfile` 的文档写明：`isOffline` 才把教程/示例切到本地变体，
`offlineOnly` 只管网络入口。`qflistudio/lib/main.dart` 的 `qfliStudioProfile`
设了 `isOffline: false`，于是主 App 打开在线教程页并发出真实请求。
测试名是「production Home opens bundled local tutorials」，与
`tool/generate_studio_content.dart` 生成 `assets/content/` 的目的（每个产品发布自己的
教程与示例）一致，因此把主 App 档位改为本地内容。

## 风险

- 改主 App 档位会影响主 App 的教程/示例入口。测试同时断言：无「写教程」按钮、
  无发布 FAB、AppBar 无 actions，即主 App 变成只读内容浏览，这与整改后主 App
  不再对外发布内容的方向一致。
- 若 `points_page` / `tasks_page` 的实际实现已经用别的方式注入，则改为让测试的
  注入点与实现对齐，并在 Result 说明；但优先按测试补实现。
