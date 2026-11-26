# 接管报告 D：远程设备信息

范围：`11-23-mobile-files-agents` 下的远程设备元数据。对应计划裁定 R4。

工作树：`D:/MyNewProjects/_wt/mobile/int/qflistudio` 与
`D:/MyNewProjects/_wt/mobile/int/qfli_studio_core`，分支 `mobile/integration`。

## 1. 结论

七条失败在当前代码里已经修好。修复来自集成树里已有的提交 `758a704`。
CI 报告 `reports/ci-failures-2.md` 记录的是旧提交 `606810bd`，那时修复还没进树。

我没有新增提交，也没有重复实现别的 Pi 的代码。Codex 直接提交或打回。

## 2. 根因

`HarnessDeviceHost.device` 是同步读的接口。首页 Agents 标签建行时当场读它。

旧实现只在 `changes` 通知里填 `_device`：

```dart
// 旧
void _onRemoteChanged() {
  ...
  _refreshDevice();   // 只有这里写
}
```

构造函数没有取一次。于是主机建好之后，那份 `info` 帧要等到下一次
`changes` 通知才进 `_device`。首页建行时读到的是初值
`const HarnessDeviceInfo()`：`hostName` 为 null，`os` 为 `unknown`。

这正好对上七条失败的三个表现：

- 两条 `hostName` 失败：读到 null。
- 一条 `harnessDeviceOf` 失败：读到 null。
- 四条 `os` 失败：读到 `unknown`，兜底路径根本没跑过。

映射逻辑本身没有错。R4 的三条规则在旧代码里就已经写对：
`hostName ?? host`、短名优先、`os` 缺失或 `other` 时用 `platform` 兜底。

## 3. 修复

提交 `758a704 fix(harness): report the device as soon as the host is built`

`lib/harness/remote/remote_harness_host.dart`。行为修复只有一条：

1. **构造函数体里加一行 `_refreshDevice()`**，位置在
   `if (_wasOnline) unawaited(_loadRemote())` 之前。主机建好即刻取一次帧。
2. `_onRemoteChanged` 里原有的 `_refreshDevice()` 不动，后续帧照旧推送。

同一提交还挪了 `_device` 的声明位置。这只是把字段与字段归拢，不改变行为。
Dart 的字段初始化器在构造函数体之前全部跑完，与声明在文本上的先后无关。
先前版本的本报告说「Dart 的字段初始化顺序要求如此」，那句写错了，已改正。

没有编造数据。端口没有帧时仍然报空，`isEmpty` 为 true。
这个行为有测试守着：`the host reports nothing before the first info frame`、
`a port without device support reports empty`。

## 4. 逐条核对

CI 报告给出的行号与我核对的一致。文件自那次运行后没有改过，行号一一对应。

| 失败用例 | 报告行号 | 当前行内容 | 修复后结论 |
| --- | --- | --- | --- |
| `reported device fields reach the host unchanged` | 182 | `expect(device.hostName, '工作台')` | 构造时已取帧，通过 |
| `a missing hostName falls back to host` | 193 | `expect(host.device.value.hostName, 'DESKTOP-7')` | `hostName ?? host` 生效 |
| `os maps the three reported short names` | 204 | 循环断言 windows / macos / linux | 短名映射生效 |
| `os other falls back to the platform value` | 219 | 循环断言 win32 / darwin / linux | 兜底路径生效 |
| `a missing os falls back to the platform value` | 229 | `expect(..., HarnessDeviceOs.macos)` | 兜底路径生效 |
| `an old agent that sends no device fields falls back to platform` | 250 | `reason: 'platform 兜底'` | 兜底路径生效 |
| `harnessDeviceOf finds the device host` | 293 | `expect(harnessDeviceOf(host)?.hostName, '工作台')` | 直连读同一个 notifier |

## 5. 端到端链路核对

从 agent 报到界面，四段都在位：

1. **agent 采集**：`companion/remote_agent/src/agent/device-info.ts`
   `collectDeviceInfo` 返回 `hostName`、`os`、`osVersion` 三项。
   `mapPlatform` 把 `win32`/`darwin`/`linux` 映射成 `windows`/`macos`/`linux`，
   其余为 `other`。
2. **报文**：`src/shared/protocol.ts` 的 `info` 帧带三个可选字段。
   注释写明转发主机不得改写它们。
3. **解析**：`lib/remote_control/models/protocol.dart` 的 `AgentInfo.fromJson`
   三个字段只在值是字符串时取，否则为 null。旧 agent 因此自然退到 null。
4. **适配与转换**：`remote_ports.dart` 的 `RemoteDevicePort.agentInfo`
   直读 `controller.agent`。`remote_harness_host.dart` 的 `_deviceInfoFrom`
   与 `_deviceOsFrom` 完成 R4 转换。`_onRemoteChanged` 每次变化再取一次。

刷新传播有测试守着：`a later info frame updates the device value`
断言一次通知、新值全部到位。

## 6. 旧修复仍然在位（只读核对）

`fix-d` 的两项修复在集成树里完好。

**占位项目清理（F1）**

- `lib/sync/placeholder_project.dart`：`discardIfUnused` L142、
  `sweepPlaceholders` L163、`removeProject` L178、`sweep` L195。
- `lib/session/agent_session.dart`：`AgentSessionStore.exists` L122，
  文件实现 L363。
- `lib/editor/agent/session_list_view.dart`：删除会话时调
  `discardSessionPlaceholders`。
- 应用侧 `lib/main.dart` L218：启动后扫一次。

**流式写入（F2）**

- `lib/sync/device_sync.dart`：`_writeVerified` L278、
  `startChunkedConversion` L290、`_DigestSink` L437。
- 全量读入的 `BytesBuilder` 与 `_fetch` 都已不在。
- 先核对后改名：哈希不符在 L321 抛错，改名只在 L326。
- 长度核对边收边做：超出 L304、不符 L313，都以 `.part` 收场，不改名。

没有阻塞项。

## 7. 静态核对工具

| 项目 | 范围 | 结果 |
| --- | --- | --- |
| `dart format` | 四个文件 | 0 changed |
| `flutter analyze --no-pub` | `lib/harness/remote`、`protocol.dart`、`test/harness_remote_device_test.dart` | No issues found! |
| `flutter analyze --no-pub` | `lib/sync`、`test/sync`、`test/harness_remote_device_test.dart` | No issues found! |
| `npx tsc --noEmit` | `companion/remote_agent` | 无输出，即通过 |

应用树只有生成文件在我的路径外有改动。我没有碰它们。

本地没有跑 `flutter test`。

## 8. 改动路径

这一轮我没有改任何文件。集成树里属于我的改动只有已存在的提交 `758a704`，
它动的是 `D:/MyNewProjects/_wt/mobile/int/qfli_studio_core/lib/harness/remote/remote_harness_host.dart`。

## 8.1 补充：本地读取也改成流式（未提交）

父级复核发现同一处流式改造漏了一半。`_listLocal` 在 L409 还是
`sha256.convert(await entity.readAsBytes())`。
写入路径已经流式，读回路径没有。后果是：再同步一个早下载好的大文件时，
为了比对本机文件的哈希，整个文件又进了一次内存。F2 的目标只达成一半。

改动只有一处，文件 `lib/sync/device_sync.dart`：

- 新增 `static Future<String> _hashFile(File file)`：拿 `file.openRead()`
  的每个分块喂给 `sha256.startChunkedConversion`，复用已有的 `_DigestSink`。
- `_listLocal` 的 `hash` 字段改为 `await _hashFile(entity)`。
- `dart format` 顺手补了 L324 一个缺失的换行：原来 `}` 与
  `await File(target).parent...` 挤在同一行。只动空白，不动语义。

保留的语义：

- **摘要相同**。`_DigestSink.value.toString()` 与
  `sha256.convert(...).toString()` 都是同一个 SHA-256 的十六进制串。
  与 `entry.hash` 的比对在 L153 不改。
- **错误相同**。`openRead()` 抛的 `FileSystemException` 照旧往外传，
  与 `readAsBytes()` 一样。调用方在 `plan` 阶段就把失败记成失败，
  没有任何 catch 吞掉它。
- **没有加测试**。按父级要求，不为实现细节镜像写用例。
  已有的同步回归会在云端 CI 跑。

静态核对：`dart format` 1 changed（就是上面那处换行），
`flutter analyze --no-pub lib/sync` 为 No issues found!

## 9. 剩余缺口与风险

1. **CI 需要重跑确认**。我只能静态核对，不能本地跑测试。七条用例的代码路径
   已逐条对上，但绿灯要云端 CI 给。
2. **`os` 只认短名**。agent 若发 `win32` 这类运行时值，会走 `platform` 兜底，
   不会直接命中短名分支。当前 agent 发的是短名，所以不影响。
   若日后有第三方 agent 发运行时值，需要在这里补映射。
3. **`osVersion` 原样透传**。不同系统格式不同，界面只当字符串显示，
   没有做归一化。这是 R4 的既定选择。
4. **`harnessDeviceOf` 依赖 `implements`**。用模式匹配识别
   `HarnessDeviceHost`。若有主机改成组合而非实现，这里会静默返回 null。
   这是 C 的接口面，不在我的范围。
5. **CI 报告另有三条不属于我的失败**：`external_agent_files_test.dart`、
   `editor_harness_session_target_test.dart`、`external_explorer_menu_test.dart`。
   我没有碰它们。`editor_page.dart` 与外部文件夹那些文件已由 C 修过，
   当前树上已有 C 的提交 `cf5927a` 与 `9847ea7`。
6. **`_listLocal` 的流式改动未提交也未跑测**。只过了格式与静态分析。
   行为等云端同步回归验证。改动在
   `lib/sync/device_sync.dart`，等 Codex 复核后提交。
