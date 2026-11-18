# 鸿蒙跨应用无感后台执行调研（A=qflistudio，B=qfli_java）

日期：2026-11-10。范围：HarmonyOS NEXT / OpenHarmony，手机与平板。

## 0. 阅读说明

- 标记 [官方] 的结论有文档原文支撑。标记 [推测] 的结论是推断，必须真机验证。
- 华为开发者官网（developer.huawei.com）是单页应用，WebFetch 只拿到导航目录。正文改取自 OpenHarmony 文档仓库（gitee.com/openharmony/docs，master 分支）。
- 仓库 master 分支可能领先或落后于真机的 HarmonyOS 版本。API 版本号以文档标注为准，设备实际 API 级别需另行确认。
- 错误码 801 的说明取自 OpenHarmony 通用错误码页。
- 未能取到正文的页面：ServiceExtensionAbility 指南、子进程指南（均返回 404）、新版 app.ability.wantConstant。相关结论已标为 [推测]。

## 1. 错误码 801 与 AppServiceExtensionAbility

### 1.1 801 的含义 [官方]

- 801 是通用错误码 "Capability not supported"。
- 原文：设备已支持该 API 所属的 Syscap，但不支持此 API。
- 官方处理建议：避免在该设备上使用此 API，或在代码中判断设备能力。
- 来源：https://gitee.com/openharmony/docs/blob/master/zh-cn/application-dev/reference/errorcode-universal.md
- 适用：所有设备，所有 API 版本。

### 1.2 AppServiceExtensionAbility 的适用设备与权限 [官方]

- 设备：仅 2in1（PC/平板形态的 2in1），原文"当前仅支持2in1设备"。英文 API 参考写作 "only PC/2-in-1 devices are supported"。
- 起始版本：API 20。
- 权限：ACL 权限 ohos.permission.SUPPORT_APP_SERVICE_EXTENSION。该权限"当前只对企业普通应用开放申请"。
- 调用方限制：调用方必须是服务所属应用，或其 appIdentifier 在服务端 extensionAbilities 的 appIdentifierAllowList 中。
- 不在白名单时的错误码：16000200。服务未启动且无权启动时：16000201。
- 组件内不支持调用 window 相关 API。
- 以 start 方式启动且无连接时，进程"可能被挂起"。
- 来源：
  - https://developer.huawei.com/consumer/cn/doc/harmonyOS-Guides/app-service-extension-ability
  - https://developer.huawei.com/consumer/en/doc/harmonyos-references/js-apis-app-ability-appserviceextensionability
  - https://gitee.com/openharmony/docs/blob/master/zh-cn/application-dev/application-models/app-service-extension-ability.md
  - 错误码：https://gitee.com/openharmony/docs/blob/master/zh-cn/application-dev/reference/apis-ability-kit/errorcode-ability.md

### 1.3 对本项目的结论

- 平板上的 801 与"仅 2in1"一致 [推测，因果关系未经官方文档直接确认]。
- 即使设备支持，该组件也需要企业普通应用的 ACL 权限，普通开发者账号拿不到 [官方]。
- 结论：在手机和平板上放弃 AppServiceExtensionAbility。

## 2. 手机与平板上的跨应用机制

### 2.1 通用启动规则 [官方]

来源：https://gitee.com/openharmony/docs/blob/master/zh-cn/application-dev/application-models/component-startup-rules.md

- 目标组件 exported=true，其他应用才能启动。exported=false 时需要 ohos.permission.START_INVISIBLE_ABILITY，该权限仅系统应用可申请（错误码 16000004）。
- 后台应用启动组件，需要 ohos.permission.START_ABILITIES_FROM_BACKGROUND，仅系统应用可申请。
- 前台判定：进程获焦，或所属 UIAbility 在前台。
- 例外（2in1 与 Tablet）：
  - API 18 起，应用有前台悬浮窗时，退到后台仍可拉起其他 Ability。
  - API 21 起，应用已加入状态栏时，退到后台可拉起自身的 UIAbility。仅限自身，不含 B。
- 错误码 16000018："API version 大于 11 时不允许重定向到第三方应用"，建议改用隐式启动或 openLink。你们的可见 startAbility 已成功，该码是否适用需真机确认 [推测]。
- 含义：A 必须在前台时调用 startAbility，A 自己不能先退后台再启动 B。

### 2.2 逐项评估

| 机制 | 能否不显示 B 的界面 | 依据与限制 |
|---|---|---|
| ServiceExtensionAbility | 官方文档未对第三方开放，视为不可用 | 启动规则页中 startServiceExtensionAbility() 带删除标记（仅系统应用）。ServiceExtension 指南页 404，未读到正文 [推测] |
| AppServiceExtensionAbility | 不可用 | 见第 1 节 |
| UIAbility + startOptions.startupVisibility | 理论可以，是唯一官方"不进入前台"字段 | API 12 起。仅 2in1 与 Tablet。仅 UIAbilityContext.startAbility。须与 processMode 同设。窗口不显示，不调用 onForeground。官方未说明能否用于跨应用 [待真机验证]。错误码 16000067 提示 processMode 需要状态栏图标 [官方] |
| startOptions.hideStartWindow | 不可用 | API 20 起。仅 2in1 与自由多窗口的 Tablet。仅用于启动当前应用自己的 Ability。只隐藏启动页，不隐藏 Ability [官方] |
| startOptions.windowMode / displayId | 不可用 | 只改窗口形态与目标屏幕，窗口仍会显示。windowLeft/Top/Width/Height 仅自由窗口模式 [官方]。把窗口缩到极小属于 [推测]，体验不是"无感" |
| Want flags | 不可用 | 已读的旧页 ability.wantConstant 共 13 个 flag，无 FLAG_START_WITHOUT_TIPS，也无"不抢焦点"的 flag。新版 app.ability.wantConstant 未读到，结论待补 [推测] |
| ExtensionAbility：BACKUP / DATA_SHARE / SERVICE | 不可用 | 属于系统能力，不提供给第三方跨应用执行任意逻辑。bundleManager 枚举页中 SERVICE、DATA_SHARE 带删除标记 [官方，措辞保守] |
| ExtensionAbility：Share / Action | 不可用 | 基于 UIExtension，必然显示界面 [官方：类型描述] |
| ExtensionAbility：EmbeddedUI（API 12 起） | 有可能，值得验证 | B 的进程内执行，界面嵌入 A 的窗口，不跳转到 B 前台。A 把宿主组件缩到 1x1 或透明属于 [推测]。能否跨应用嵌入、是否受 allowlist 限制，官方页未读到 [待验证]。A 退后台时扩展大概率随之销毁 [推测] |
| 跨应用 RPC | 不可用 | 需要先连上对方的 Service 类扩展，而该类扩展不对第三方开放 |
| App Linking / openLink | 不可用 | 本质是启动 B 的 UIAbility，B 界面会显示 [推测] |
| 分布式能力 | 不可用 | 面向跨设备，且 startAbility 对本地 B 没有隐藏效果。启动远端 UIAbility 错误码 16000124 [官方] |

### 2.3 来源汇总（第 2 节）

- StartOptions 字段表：https://gitee.com/openharmony/docs/blob/master/zh-cn/application-dev/reference/apis-ability-kit/js-apis-app-ability-startOptions.md
- wantConstant（旧版）：https://gitee.com/openharmony/docs/blob/master/zh-cn/application-dev/reference/apis-ability-kit/js-apis-ability-wantConstant.md
- ExtensionAbilityType 列表：https://gitee.com/openharmony/docs/blob/master/zh-cn/application-dev/reference/apis-ability-kit/js-apis-bundleManager.md
- 启动规则：https://developer.huawei.com/consumer/en/doc/harmonyos-guides/component-startup-rules

## 3. 长时任务与短时任务

### 3.1 差别 [官方]

| 项目 | 短时任务 transient（requestSuspendDelay） | 长时任务 continuous（startBackgroundRunning） |
|---|---|---|
| 用途 | 保存状态、发送收尾请求等短时间任务 | 用户可感知的长时间后台业务 |
| 时长 | 单次最长 3 分钟，低电量 1 分钟。单日配额默认 10 分钟。同时最多 3 个 | 无固定时限，随业务存在 |
| 权限 | 无 | ohos.permission.KEEP_BACKGROUND_RUNNING，并在 module.json5 的 UIAbility 下声明 backgroundModes |
| 通知 | 无 | 申请成功后系统显示通知。用户删除通知会停止任务 |
| 申请时机 | 必须在前台或 onBackground 回调内，否则失败 | 在 UIAbility 内申请（Stage 模型仅 UIAbility 可申请） |
| 到期行为 | 到期前约 6 秒回调，应用须 cancelSuspendDelay，否则被挂起或终止 | 系统会检测业务真实性，不符会被取消并挂起 |

来源：
- 短时任务：https://developer.huawei.com/consumer/en/doc/harmonyos-guides/transient-task
- 长时任务：https://developer.huawei.com/consumer/en/doc/harmonyos-guides/continuous-task
- API 与错误码：https://developer.huawei.com/consumer/en/doc/doccenter-references/api/js-apis-resourceschedule-backgroundtaskmanager
- 长时任务原文：https://gitee.com/openharmony/docs/blob/master/zh-cn/application-dev/task-management/continuous-task.md

### 3.2 backgroundModes 类型 [官方]

- dataTransfer：数据传输。
- audioPlayback：音视频播放。
- audioRecording：录制。
- location：定位导航。
- bluetoothInteraction：蓝牙。
- multiDeviceConnection：多设备互联。
- wifiInteraction：仅系统应用。
- voip：API 13 起。
- taskKeeping：API 21 起，计算任务。非 PC/2in1 设备需要 ohos.permission.KEEP_BACKGROUND_RUNNING_SYSTEM。
- avPlaybackAndRecord：API 22 起。
- specialScenarioProcessing：API 22 起，开放给 Phone、Tablet、PC/2in1。API 24 起需 ohos.permission.KEEP_BACKGROUND_RUNNING_SPECIAL_SCENARIO。API 23 及之前需 ohos.permission.KEEP_BACKGROUND_RUNNING_SYSTEM。
- nearlink：API 26 起。

对本项目的含义：
- "编译并运行代码"没有对口类型。taskKeeping 最贴切，但在平板上需要 KEEP_BACKGROUND_RUNNING_SYSTEM [官方]。该权限是否对普通开发者开放，官方页未说明，需查权限列表 [待验证]。
- 若用 dataTransfer 之类不对口的类型，系统会"对应用进行管控，退至后台会被挂起或终止" [官方]。
- dataTransfer 还要求进度通知为实况窗 [官方]。

### 3.3 9900002 [官方 + 推测]

- 官方含义：Transient-task verification failed，适用于 requestSuspendDelay 与 getRemainingDelayTime [官方]。
- 你们 hilog 的解释是"超过进入后台的预设时间"。这与官方"须在前台或 onBackground 回调内申请"的规则一致 [推测，官方页未逐字说明该码的触发条件]。
- 规避：只在前台或 onBackground 回调里同步申请。

### 3.4 最小化后约 4 秒被销毁的原因

官方文档没有描述这个 4 秒现象。以下均为 [推测]，按可能性从高到低排列。

1. B 的进程不是被"挂起"，而是被杀。短时任务只防止挂起，不防止系统因其他原因回收。
2. B 由 A 以可见 startAbility 拉起。若 B 的 UIAbility 在 onBackground 后随即 onDestroy，可能是 B 自身的生命周期代码调用了 terminateSelf，或 launchType 与任务栈策略导致销毁。先查 B 的 onBackground、onDestroy 前后日志。
3. 后台业务与申请类型不符，被资源调度管控。
4. 低内存回收。先看 hilog 中 AppMgr、ResourceSchedule、BackgroundTaskManager 的 kill reason。
5. 短时任务申请成功（delay=180000）与销毁并存，说明短时任务本身不是原因，申请对象不是问题所在。

建议的真机取证（只读，不改代码）：
- hilog 过滤销毁时刻前后 2 秒，找 kill reason 与 "died"、"suspend"。
- hidumper 查看 AbilityManagerService 与 BackgroundTaskManager 的任务列表（命令名以设备实际可用为准）。

### 3.5 启用 continuous task 的正确时机与顺序 [官方，来自步骤清单]

1. 声明 ohos.permission.KEEP_BACKGROUND_RUNNING，并在 module.json5 声明 backgroundModes。
2. 在 UIAbility 前台期间调用 wantAgent.getWantAgent。
3. 在回调中调用 startBackgroundRunning(context, modes, wantAgent)。
4. 等 Promise 或回调成功后，才开始执行真正的后台业务。
5. 业务结束立即 stopBackgroundRunning，否则退后台会被挂起。
- 必须在进入后台之前完成第 3 步和第 4 步的成功返回 [推测，官方对"前台申请"只在短时任务页明说]。
- 对 B 来说：B 被拉起后在 onForeground 之后立刻申请，不要等 A 发出"最小化"信号再申请。

## 4. 把编译与运行放进 A 自身

### 4.1 官方事实

- 每个应用运行在独立沙箱，只能访问自身目录 [官方，通用沙箱说明；本次取到的是社区转述，见下文来源]。
- A 无法读取 B 沙箱内的 JDK 或二进制文件，也无法执行 B 沙箱内的文件。这是沙箱的直接结果 [推测，未读到逐条官方原文]。
- ArkTS Worker、TaskPool 都在 A 的进程内，不受跨应用限制，但只能运行 A 自己打包的代码。

### 4.2 可行性判断 [推测，必须验证]

| 做法 | 可行性 | 说明 |
|---|---|---|
| A 的 Worker 运行 A 内置的解释器或编译器（ArkTS、wasm、native .so） | 可行 | 完全在 A 进程内，只要 A 在前台或持有 continuous task |
| A 把 B 的 JDK 拷贝到 A 沙箱后执行 | 高风险 | 不能读 B 沙箱。即便 JDK 随 A 的 HAP 打包，动态下发可执行文件通常被代码签名与可执行内存规则限制，需验证 |
| A 通过子进程（childProcessManager）运行 JDK | 不确定 | 子进程指南页 404，未读到限制 |
| 把 B 的编译运行引擎做成共享库，由 A 的 HAP 直接打包 | 最稳妥 | 需要引擎能编为 arm64 的 .so，且不依赖运行期生成可执行代码（JVM 的 JIT 是风险点） |

### 4.3 来源

- 沙箱说明（社区，非官方）：https://www.cnblogs.com/tslgood/p/22390819
- 官方应用沙箱目录页需另行确认。本次未取到正文。

## 5. 推荐方案排序（体验由好到差）

排序依据：能否不显示 B、对权限的依赖、实现风险。

1. 引擎并入 A（HAR/HSP 或 native .so），A 内部 Worker 执行。
   - 不涉及跨应用，没有闪屏，没有 B。
   - 前提：引擎能在 A 内运行；A 在前台时直接执行，退后台再用 continuous task 或 transient task。
2. B 以 EmbeddedUI（UIExtension）嵌入 A 的窗口。
   - B 的进程执行，界面在 A 内，不抢前台。
   - 官方页未确认跨应用嵌入是否允许，属于验证性方案。
3. startAbility + startOptions.startupVisibility=invisible + processMode（仅 2in1 与 Tablet）。
   - 官方明确"可以不进入前台"。官方未说明能否跨应用。
   - B 须有状态栏图标（16000067 的提示），可能与"无感"冲突。
4. 现有方案：可见 startAbility 拉起 B，B 在 onForeground 同步申请 continuous task（类型待定），完成后回到 A。
   - B 会短暂可见。可靠性取决于 continuous task 类型是否被接受。
5. 可见 startAbility，B 全程停在前台，A 在后台等待。最简单，体验最差。

不在排序内：AppServiceExtensionAbility（仅 2in1 且需企业 ACL，见第 1 节）。

## 6. 必须的真机验证点

1. 取证 4 秒销毁的 kill reason（hilog + hidumper），区分"被杀"与"自我 terminate"。
2. B 是否在 onBackground 里主动销毁自己。
3. 申请 continuous task 在 onForeground 之后立即进行，是否稳定成功。记录错误码，对照 9800005、9800006。
4. 平板上 taskKeeping 的 KEEP_BACKGROUND_RUNNING_SYSTEM 是否能被普通应用获得。
5. specialScenarioProcessing 的权限与适用设备，在目标系统版本（API 级别需读取）上是否可用。
6. startupVisibility + processMode 对跨应用 B 是否生效，是否报 16000067。
7. EmbeddedUI 是否允许 A 嵌入 B，以及 A 缩小宿主窗口后 B 是否继续执行。
8. B 的 UIAbility 若被连续拉起，launchType 对单例复用、onNewWant 的影响。
9. 引擎并入 A 的方案：目标 .so 的运行期代码生成是否被系统拦截，是否能在 Worker 内长时间运行并保持 stdout 回传。

## 7. 结论分级

- 官方来源支持：801 含义，AppServiceExtensionAbility 仅 2in1 且需 ACL，startOptions 各字段的设备范围，hideStartWindow 仅限本应用，startupVisibility 的行为，后台启动需系统权限，transient task 的配额与申请时机，continuous task 的权限、类型、通知与顺序，9900002 的官方名称。
- 推测：4 秒销毁的原因，9900002 的具体触发条件，EmbeddedUI 的跨应用可行性，沙箱对 JDK 执行的限制，Want flag 在新版文档中的情况，ServiceExtensionAbility 对第三方关闭（只从启动规则页的删除标记推断）。
- 不可用来源：华为官网正文未能抓取，正文取自 OpenHarmony 文档仓库 master。版本差异需核对。
