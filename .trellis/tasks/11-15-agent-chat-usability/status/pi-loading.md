# Loading worker (w37:pH) — session loading

## 已完成

- `open()` 并发去重：`_opening` 共享同一个 Future，同会话并发打开只读一次盘、只建一个实例。
- 监听器泄漏修复：按会话保存监听器，`_destroy` 精确摘除；`_onFacadeChanged` 只认缓存里那个实例。
- `compactIfNeeded` 移出打开路径：`readTail` 不再触发全文件扫描，只由 `read()` 调度；大于 200 KB 的文件在独立 isolate 扫。
- `_LineTail` 拼接改为按块收集、末尾拼一次（原来每 64 KB 就 `[...tail, ...carry]`，二次方拷贝）。
- `_readPage` 按字节前缀跳过 `hs`/`hdr` 行，不再为跳过多 MB 快照做 UTF-8 与 JSON 解码。
- `readHistory` 原来先在界面 isolate 解一遍再交给 `compute` 解第二遍，现在只解一次。
- `AgentMessageView` 新增 `sourceText` 与 `attachedPaths`，贯通乐观条目、运行视图与 `retryLast`（重发原先会丢附件）。

## 进行中

- 已冻结实现文件（`lib/session/agent_session.dart`、`lib/vibe_coding/vibe_agent_facade.dart`），等待协调方做最终校验。

## 请求

- 协调方确认：全仓 `flutter analyze` 目前在 `lib/shell/workbench_agent_pane.dart` 约 516 行有语法错误，属消息 worker 的文件。
- 已告知协调方：`open()` 在打开途中会话被删时抛的是 `PathAccessException`（读盘失败），不是 `ArgumentError`。结果安全（不建实例、不缓存），界面侧宽泛捕获即可。
- 仓库里还有非我的未跟踪文件：`test/zz_sidebar_review_probe_test.dart`、`test/zz_probe_pi_d_anchor_test.dart`、`tool/preview_composer_card_test.dart`，请确认是否要清理。

## 未验证

- 未在真机上做性能剖析，因此不对真机速度下结论；下列数字来自桌面测试机。
- 4.0 MB 历史快照、60 条尾页：改前 938–990 ms，最坏 1572 ms；改后 85–107 ms，最坏 126 ms（约 9–12 倍）。
- 已完成兼容修：去掉手写的部分 JSON 解析器，改为 canonical 前缀快捷路径 + 真 `jsonDecode` 回退（大会话在独立 isolate）。`readHistory` 改为反向流式边读边解，碰到第一条有效 `hs` 就停，不攒候选、不设上限。
- 反向读取回调改成 `FutureOr<bool>`，只要不返回 Future 就不进事件循环，分页仍是同步快路径。
- 已验证：超过 8 条不规范 `m` / `hdr` 行后的有效快照仍能读到；最新一条有效快照为空时就返回空（不回退到老的非空快照）；6 份 1 MB 快照只解最新那份，共 43 ms；分页 90–105 ms 与改动前一致。
- 已验证与基线一致：最新 `hs` 被截断（含超过 200 KB、走独立 isolate 的情形）时，仍能拿到老的完整快照；多行连续写坏也能回退；`hdr` 行不会被当成空历史；`\u0074` 转义键名仍可读。
- 未改动 `chat_transcript.dart`、`workbench_agent_pane.dart`、`composer_card.dart`。
