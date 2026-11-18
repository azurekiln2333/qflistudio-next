# 后台接收端缺陷修复 2026-11-09（C 分工）

范围：`qfli_java` 接收端、`native` 调用点、接收端专属测试工具。
未改动：主工程、`lib/editor`、`core/lib/interop`、Studio 发送端。
前台路由 `InteropAbility` 保持独立，后台路由 `InteropBackgroundAbility` 不改前台语义。

## 基线

`git status` 在工作前记录：5 项已修改、4 项未跟踪，全部保留。
本次只编辑 `InteropBackgroundAbility.ets`、`InteropBackgroundRunner.ets`、
`InteropReceiver.ets`（emit 路径）、`InteropAbility.ets`（refuseRaw 的 action）
与 `tool/verify_interop_background.cjs`。

## 修复项

### 1. 前台门槛不打开时请求拿不到任何答复（P0，静默失败）

原代码 `startPending()` 只在 `windowReady && foreground` 时放行。
`foreground` 只由 `onDidForeground` 置位。该回调 `@since 20`，本工程
`compatibleSdkVersion` 为 `5.1.0(18)`。回调不触发时请求既不发事件也不终止。
用户看到 JVMX 弹出一秒后什么也没有。

现在：`onCreate` 起一个 8 秒有界看门狗。门槛在此期间打开则取消看门狗。
门槛不打开则回 `error / internal`，然后终止自身。`onForeground`（`@since 9`）
不用于放行，只看门狗续期。真机实测显示此时申请瞬态额度会得到 9900002。

### 2. 未授权调用方拿不到拒绝事件（P0，静默失败）

原 `handle()` 在调用方不在 allowlist 时直接 `finish()`，不发任何事件。
现在回 `error / caller_not_allowed`，事件一律发往 allowlisted 的 Studio
bundle，不用 Want 自称的 `callerBundle`，未授权方无法重定向消息。

### 3. 取消在 `onCreate` 到 `run()` 之间丢失（P1，B 报告）

Studio 在用户按下停止时立即发布 `...background.CANCEL`，但接收端只有
`run()` 内才 `createSubscriberSync`。启动到 `onDidForeground` 之间的取消
无人接收。

新增 `BackgroundCancelGate`。`onCreate` 就订阅（`publisherBundleName`
限定 Studio），只记录 `sessionId` 与 `sessionToken` 都匹配的取消。
`run()` 开始时先消费该记录。命中则不申请额度、不隐藏窗口、不启动 native，
直接回 `error / cancelled`。`dispose()` 与 `run()` 结束都会释放该订阅。

### 4. 回传事件缺 `action`（P2，可能是 201 ABMS13313 的来源）

Studio 的 `InteropBridgeAbility` 在 `module.json5` 声明了
`skills.actions = ["action.system.qfli.interop.event"]`。接收端 `emit()` 与
`refuseRaw()` 构造的 Want 只有 `bundleName` + `abilityName`，没有 `action`。
声明了 skills 的 exported ability 跨应用拉起必须匹配 action。
现在两处都带 `BRIDGE_ACTION`。

### 5. 取消交接竞态（复查发现，两个）

上一版用 handles 集合记录已建订阅。两个缺陷：

- `close()` 先清空集合再逐个 release，`release()` 又用 `indexOf < 0` 做幂等，
  两者冲突。晚到的 subscribe resolve 可能既不退订也不报警。
- 早到取消交接期间，runner 只做一次 `fired()` 快照，随后 await 自己的订阅。
  该窗口内 gate 收到的取消无人再读。

改成窄方案。gate 只保存自己的订阅句柄与一个 settled 标记。
`close()` 只标记 closed，真正退订等 subscribe promise 落定后做一次。
runner 的订阅 await 完成前，gate 保持真实订阅。完成后先读 `fired()`，
再在 `finally` 关闭 gate。没有 handles 集合，没有提前 handOff。

### 6. 待处理请求被第二请求的拒绝杀掉（复查发现）

`onNewWant` 的忙条件包含 `pendingWant !== null`，但 `refuseLater` 只用
`runner !== null` 判忙。请求 A 在等前台时到达 B，`busy=false`，
拒绝 B 后 `finish()` 会杀掉 A。

`refuseLater` 改为只发拒绝，不再终止。新增 `finishIfIdle()`：
仅当 `runner === null && pendingWant === null` 才终止。
自有请求的失败路径改用 `finishIfIdle()`。
运行结束的 `finally` 仍直接 `finish()`。

### 7. 终结事件丢弃排队中的输出（复查发现）

`send()` 在收到终结事件时同步置 `terminal=true`。`publish()` 内又有
`if (this.terminal && !terminal) return`。已排队的非终结块因此被截断。
移除 `publish()` 内该条件。`send()` 已有的终结后拒绝仍保证顺序。

## 验证

- `node tool/verify_interop_background.cjs`：17 项全过。新增与扩展项如下。
  - `early cancel`：`onCreate` 即订阅。错误 token 与其他会话不触发。
    命中后窗口不隐藏、native 不启动，终端事件只有一个且为 `cancelled`。
    两个订阅都释放。
  - `close during subscribe`：订阅落定前 close 不退订，落定后退订一次，
    不重复退订。取消在 close 前记录，close 后不再翻转。
  - `cancel during handoff`：runner 订阅未落定时 gate 仍真实订阅，
    取消被记录并在 runner 订阅落定后被采纳。窗口不隐藏，native 不启动。
  - `terminal keeps queued output`：先入队的输出块完整发出，终结事件最后，
    序号连续。该用例能检出被移除的截断条件。
  - `pending then busy`：A 待启动时 B 到达，B 收到拒绝，
    进程未被终止（`terminateSelf` 为 0），A 后续两次前台回调只启动一次。
  - `ability lifecycle` 增加外来调用方收到 `caller_not_allowed` 的断言。
- `hvigorw assembleHap --mode module -p product=default -p buildMode=debug`：
  `BUILD SUCCESSFUL`。产出 `entry-default-signed.hap`（228143346 字节，
  2026/11/09 02:22）。
- 早前一轮修 bug 时先暴露一个编译错误。我的编辑误删了
  `export const PROTOCOL`，构建报 3 处 `Cannot find name 'PROTOCOL'`。
  已恢复后重编通过。

不再向共享生产文件临时回写旧 bug。用例的必要性由断言与旧逻辑差异说明。

## 未验证（不声称）

- `hdc list targets` 仍是 `[Empty]`。当前没有设备，以下全部未证实。
  前台门槛看门狗的真实触发时长未知。`onDidForeground` 在 API 26 之外的设备
  是否触发未知。取消在实际启动窗口内是否真的到达未知。`action` 是否真的
  消除了 201 未知。
- 无窗口化未实现，也不声称已实现。当前实现使用 UIAbility。
  `window.minimize()` 只是尽快把窗口退到后台，启动过渡仍可能可见。
  无窗口方案尚未验证。本任务没有申请任何系统私有权限，
  也没有把 JDK 迁进 Studio。
- `cancelJava` 只杀自身 JVM 的 PID，不保证终止 Java `ProcessBuilder`
  派生的子进程（既有已知限制，本次未改）。
