# 9900002 的官方依据：瞬态任务与前台/窗口可见性 2026-11-09（B 只读研究）

范围：只读本地 SDK 与官方头文件。未操作真机，未改任何代码。
目的：给 C 修的 `requestSuspendDelay` 失败一条可引用的依据链，说明
9900002「after the preset time of entering background」到底约束什么，
以及 `onDidForeground` 与资源服务更新的关系。

## 结论摘要

1. **SDK 层面没有“必须前台”的声明**。ArkTS 与 NDK 两套 API 的
   `requestSuspendDelay` 文档只列错误码，不写前置条件。所以任何“官方要求
   必须可见”的说法都不能引 d.ts。
2. **错误码是同一个**。`9900002` 在 NDK 里是
   `ERR_TRANSIENT_TASK_SERVICE_VERIFICATION_FAILED`，注释只有一句
   `Transient task verification failed.`。SDK 不区分“额度耗尽”与
   “进入后台过久”，两者都落在 9900002。
3. **“preset time” 是系统侧措辞，不在 SDK 里**。当前代码按 message 子串
   识别该原因，这是唯一可用的区分手段，属于合理做法，不是猜权限。
4. **`onDidForeground` 不负责下发资源额度**。官方文档只说它是“完全切到
   前台之后”的回调，可用于测量过渡耗时。没有一句说它会刷新后台额度。
5. **因此“等 `onDidForeground` 再申请”不是官方要求**。它是本工程自己的
   时序假设，真机已证伪（申请仍得 9900002）。
6. 代码里 `this.foreground` 由 `onDidForeground` 置位，而
   `@since 20`，工程 `compatibleSdkVersion` 是 `5.1.0(18)`。这个回调在
   18 上是否触发没有任何官方保证。把它当作放行条件，从一开始就缺少依据。

## 依据 1：ArkTS API 只列错误码，不写前置条件

`@ohos.resourceschedule.backgroundTaskManager.d.ts`，API 20 与 API 23
两份内容一致：

```
D:\ProgramFiles\Huawei\OpenHarmony\Sdk\23\ets\api\@ohos.resourceschedule.backgroundTaskManager.d.ts:481
    function requestSuspendDelay(reason: string, callback: Callback<void>): DelaySuspendInfo;
```

其文档块（行 465-481）完整内容是：

- `@brief`：`Requests delayed transition to the suspended state.`
- `@param reason`：`Indicates the reason for delayed transition to the suspended state.`
- `@param callback`：`The callback delay time expired.`
- `@returns`：`Info of delay request.`
- `@throws 401 / 9800001 / 9800002 / 9800003 / 9800004 / 9900001 / 9900002`
- `@syscap SystemCapability.ResourceSchedule.BackgroundTaskManager.TransientTask`
- `@since 9`

没有 `@permission`，没有“必须在后台/前台调用”，没有“窗口必须可见”。
同一文件里真正的权控 API（如 `requestSuspendDelay` 之外的连续任务接口）
才带 `@throws 201 - Permission denied` 与 `202 - Not System App`。
瞬态任务的声明里这两个码都没有，说明调用它不需要额外授权。

API 20 同一处：`Sdk\20\ets\api\@ohos.resourceschedule.backgroundTaskManager.d.ts:379`，
文档块行 363-379，内容逐字相同。

## 依据 2：NDK 定义确认 9900002 的语义与“验证失败”

头文件 `transient_task_type.h`：

```
D:\ProgramFiles\Huawei\OpenHarmony\Sdk\23\native\sysroot\usr\include\transient_task\transient_task_type.h
    ERR_TRANSIENT_TASK_CLIENT_INFO_VERIFICATION_FAILED = 9900001,   // uid or pid info verify failed
    ERR_TRANSIENT_TASK_SERVICE_VERIFICATION_FAILED = 9900002,       // Transient task verification failed.
```

`transient_task_api.h` 行 55-61 的返回码说明：

```
 * @return ERR_TRANSIENT_TASK_OK 0 - Success.
 *         401    - Invalid parameter.
 *         9800002 - Parcelable failed.
 *         9800003 - Transact failed.
 *         9800004 - System service not ready.
 *         9900001 - uid or pid info verify failed.
 *         9900002 - Transient task verification failed.
```

两点可直接引用：

- 9900001 是**调用方身份**失败（uid/pid）。9900002 是**任务本身**没通过
  验证。两者分开了，所以本工程遇到的不是身份或授权问题。
- 9900002 的注释不细分原因。额度耗尽、后台停留过久、同名任务重复申请，
  在 API 表面都返回 9900002。**SDK 没有给出可区分的原因字段。**

## 依据 3：为什么按 message 子串识别是唯一可用的区分

`InteropBackgroundRunner.ets:142-145`：

```ts
function isStaleBackgroundRejection(failure: BusinessError): boolean {
  if (Number(failure.code) !== 9900002) return false;
  return `${failure.message}`.includes('after the preset time of entering background');
}
```

- 码相同，只能靠 message 区分。SDK 里没有枚举、没有原因枚举、没有额外字段。
- 该措辞不在任何本地 SDK 文件里（`Select-String 9900002` 只命中 d.ts 与
  `net.vpnExtension.d.ts`，两者都不含这句）。它由系统服务在运行时给出。
- 因此这段代码不是“猜私有权限”，而是**在唯一可用的信息上做区分**。
  它也只放行这一种原因，其他 9900002 立即失败，没有绕过额度。

同一个 `reserveAllowance()` 里的重试上限是 5 次、间隔 250ms（共约 1 秒），
`attempt === 4` 时无条件抛出。这个窗口**远小于**任何“等后台年龄重置”所需
的时间量级。真机上如果 message 命中但 1 秒内不恢复，重试实质无效。
这是当前实现的可疑点，供 C 判断，我不下结论。

## 依据 4：`onDidForeground` 官方只说是“完全切前台之后”的回调

`Sdk\20\ets\api\@ohos.app.ability.UIAbility.d.ts:548-564`：
`onWillForeground` / `onDidForeground` 均为 `@since 20`。

`onDidForeground` 文档原文（行 549-553）：

```
 * Triggered after the application has transitioned to the foreground.
 * It is called after onForeground.
 * It can be used to capture the moment when the application fully transitions to the foreground.
 * When paired with onWillForeground, it can also measure the duration from the application's
 * initial foreground entry to its full transition into the foreground state.
 * <p>**NOTE**:
 * <br>This API returns the result synchronously and does not support asynchronous callback.
 * </p>
```

`onForeground` 文档原文（行 525-528）：

```
 * Triggered when the application transitions from the background to the foreground.
 * It is called between onWillForeground and onDidForeground.
 * It can be used to request system resources required, for example, requesting location
 * services when the application transitions to the foreground.
```

关键对比，这是本次研究的核心发现：

- 官方把 **`onForeground`** 描述为“可以用来申请所需的系统资源”，给出的例子
  是定位服务。也就是说**申请资源的位置在 `onForeground`，不在
  `onDidForeground`**。
- `onDidForeground` 的用途被描述为“捕捉完全切到前台那一刻”“配合
  `onWillForeground` 测量过渡耗时”。**它没有任何一句提到资源申请或额度下发。**
- 两句都写明“同步返回、不支持异步回调”。所以在 `onDidForeground` 里做
  异步申请本身也不符合该回调的约定。

结论：把瞬态额度的申请**前置依赖**在 `onDidForeground` 上，在官方文档里
找不到依据。反过来，`onForeground` 才是文档点名用来申请资源的位置。

## 依据 5：`@since 20` 与工程的 `compatibleSdkVersion`

`D:\MyNewProjects\qfli_java\ohos\build-profile.json5`：

```
"compatibleSdkVersion": "5.1.0(18)",
"runtimeOS": "HarmonyOS",
"targetSdkVersion": "6.1.1(24)"
```

`compatibleSdkVersion` 是 18，`onDidForeground` 是 `@since 20`。在 18 的
运行时上，该回调是否触发没有任何官方保证。而
`InteropBackgroundAbility.ets:131` 用 `this.foreground = true` 把它当作放行
条件，`onCreate` 的 8 秒看门狗只是兜底。这不是“设备有问题”，是**把高于
compatible 版本的 API 当中必发生**的设计缺陷。

同一份 SDK 里 `onForeground` 是 `@since 9`（`Sdk\23\...UIAbility.d.ts:510`），
18 上一定有。若需要一个跨版本稳定的过渡点，`onForeground` 是唯一有依据的选择。

## 未能证实（不声称）

- 本地没有任何 OpenHarmony 系统源码树，也没有
  `transient_task_manager` 的服务端实现。所以**“后台停留多久后拒绝”的具体
  秒数我没有权威依据**。SDK 只给 `TRANSIENT_TASK_MAX_NUM 3`（最大并发数）
  与 `remainingQuota`、`actualDelayTime` 两个字段，没有暴露时间窗常量。
- “preset time” 的准确值、以及它是否按进程还是按 ability 计龄，本地无从
  查证。我不猜。
- `onDidForeground` 在 18 上是否触发，只能靠真机日志确认。C 的
  `QFLI_BG_ALLOWANCE` 日志（attempt/elapsed/code/codeType/message/stale）
  就是为此设计的，那是唯一可行的取证手段。
- 保持进程前台是否能让额度恢复，我没有依据说“能”。官方文档没有这条承诺。
  因此本工程不应依赖“申请失败就重试到成功”作为修复方向。

## 给 C 的可执行判断（基于以上依据，非建议新增权限）

1. 不要把放行条件押在 `onDidForeground`（`@since 20`，工程 compatible 18）。
   官方文档点名用来申请资源的是 `onForeground`（`@since 9`）。
2. 9900002 无法从 API 侧区分原因，按 message 区分是唯一手段，保持不变即可。
   但 5 次 × 250ms ≈ 1 秒的重试窗口，对“后台年龄”类限制大概率无效。
3. 真正确证只能靠 `QFLI_BG_ALLOWANCE` 日志里的 `codeType` 与 `message`
   原文。日志到手前不要改判定逻辑，否则是在没有依据的基础上换一个假设。
4. 不申请任何私有权限。SDK 声明里瞬态任务不带 `201/202`，本就不需要额外
   授权；问题不在权限层。
