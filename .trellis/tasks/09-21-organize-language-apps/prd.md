# Organize Language Apps and Offline Pages

## Goal

把当前 Flutter workspace 整理成清晰的联网全能版与独立语言 App 结构。联网版保持社区、登录、云端项目和在线终端；离线语言版只依赖本地项目、内置教程 JSON 和本地示例代码。

## Confirmed Facts

- 根工程是联网全能版，共享内核位于 `packages/qfli_studio_core`。
- `apps/` 已有 `qfli_c`、`qfli_python`、`qfli_java`、`qfli_web`、`qfli_dart`，缺少 `qfli_cpp` 和 `qfli_lua`。
- 共享内核已有教程模型、解析器和 `c`、`dart`、`java`、`python`、`web` 教程 JSON，但现有导航仍把教程和讨论接到社区接口。
- 工作区含有之前迁移留下的未提交源代码改动；本任务不得覆盖或恢复这些既有改动。

## Requirements

1. 保留根工程联网行为，不改变联网版已有的社区、登录、云端和在线终端入口。
2. 保留现有 Dart 独立 App；补齐可运行结构一致的 C++ 与 Lua 独立 App，并登记到 pub workspace。
3. 为离线档位提供明确的本地模式配置：主页保留本地项目操作，第二页显示内置 JSON 教程，第三页显示本地示例代码；不得初始化或调用社区/登录/云端 API。
4. 教程和示例数据必须通过共享内核的类型化服务读取，后续可以把服务实现替换成 API，而不修改页面数据模型。
5. 为新增语言提供对应教程 JSON、默认项目模板、应用入口和测试；不能把“解释器未实现”伪装成运行成功。
6. 整理工作区：补充生成物和临时诊断文件的忽略规则，删除明确属于本次工作区的临时导出文件；保留 `.agents`、`.trellis` 等工程配置和既有源代码改动。

## Acceptance Criteria

- [ ] `apps/` 至少包含 C、C++、Python、Java、Lua、Web 六个目标 App，并且 Dart 现有 App 未被删除。
- [ ] 根联网版仍显示原有教程/讨论社区入口；离线版导航第三个入口显示“示例代码”，不出现社区讨论入口。
- [ ] 离线版第二页从本地 JSON 加载当前语言教程；离线版第三页显示当前语言示例代码，并可打开/复制代码。
- [ ] 离线版不触发 `ApiClient` 的社区、认证、云端或在线终端请求。
- [ ] 所有教程 JSON 可解析，C++/Lua 资产存在，新增 App 的接线测试和共享内核测试通过。
- [ ] `flutter analyze --no-pub` 及目标 App 测试通过，工作区不再把临时导出文件列为未跟踪文件。
- [ ] 每个实施阶段使用标准化 Git commit，且只提交该阶段新增或修改的文件。

## Out of Scope

- 不删除或重写现有根工程的联网功能。
- 不在本任务内实现完整的 C++、Lua、Python、Java 或 Dart 编译器；运行能力必须如实标记，不能伪造输出。
- 不删除 `.agents`、`.trellis`、`.claude` 等可能被项目工具使用的工程配置。
