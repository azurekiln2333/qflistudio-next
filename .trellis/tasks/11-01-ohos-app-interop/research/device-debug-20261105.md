# 真机调试记录 2026-11-05

设备:192.168.68.207:46551,OpenHarmony 7.0.0.105(API 26,MRT-AL10)。
两个应用均已 debug 签名安装。冒烟启动被设备息屏挡住,待解锁后继续。

## 一、构建与安装结果

| 应用 | 仓库 | 产物 | 结果 |
| --- | --- | --- | --- |
| qflistudio(主) | qflistudio/ohos | `entry/build/default/outputs/default/entry-default-signed.hap`(132 MB,04:13) | 安装成功 |
| QFLIJVMX(java) | qfli_java/ohos | `entry/build/default/outputs/default/entry-default-signed.hap`(228 MB,04:03) | 安装成功 |

签名:主应用用 product `default`(机器自动调试签名 `default_ohos_HCrb…`);java 用 product `default` → signingConfig `debugKey`(`default_ohos_Gu8z…`)。两套材料都存在且未改动。

## 二、构建问题:ohpm install 批处理递归(重要)

现象:`flutter build hap --debug` 每次死在 hvigor 的 ohpm 步骤,报
`00306053 ohpm install failed`,前置一行
`BATCH RECURSION exceeds STACK limits, Recursion Count=242`。

根因链:
1. flutter 工具(legacy 路径 `OhosHvigorBuilder.buildHap`,hvigor.dart:419)不做依赖注入,直接调 hvigorw。
2. 该路径只在 Windows 进程链里触发 `ohpm.bat`。`ohpm.bat` 的 `:calculateFirstParamLen` / `:removeFirstParam` 用逐字符 `call :self` 递归解析参数,触发 cmd 的批处理递归上限。
3. 从 Git Bash 直接调 `hvigorw`(sh 脚本)不经过这条 .bat 链,同样的命令成功。

可用构建命令(绕过 flutter 工具,产物等效):

```bash
cd ohos && hvigorw assembleHap -p product=default -p buildMode=debug --no-daemon \
  "-p FLUTTER_TARGET=lib\main.dart" -p TARGET_PLATFORM=ohos-arm64 \
  "-p DART_DEFINES=RkxVVFRFUl9WRVJTSU9OPTMuMjcuNS1vaG9zLTEuMC4x,…" \
  -p DART_OBFUSCATION=false -p TRACK_WIDGET_CREATION=true -p TREE_SHAKE_ICONS=false \
  "-p PACKAGE_CONFIG=D:\MyNewProjects\qflistudio\.dart_tool\package_config.json"
```

副作用记录:中途手动跑 `ohpm install` 把 `oh_modules` 里未在 oh-package.json5 声明的 flutter_ohos、path_provider_ohos 清掉了(legacy 注入不落盘)。后续 hvigor 构建自行恢复,当前构建产物可用。

设备 API 26 与 ohos/build-profile.json5 未提交的 `targetSdkVersion 26.0.0` 匹配,构建无 SDK 缺失问题。

## 三、静态契约审计(代码级发现)

### 断点 1(实锤):桥接能力读错调用方身份

`qflistudio/ohos/entry/src/main/ets/interop/InteropBridgeAbility.ets:53`
`const caller = want.bundleName ?? ''`。

发送方(qfli_java `InteropReceiver.ets:262-266`)的 Want 里 `bundleName` 填的是**目标方** com.azurekiln.qflistudio。SDK 文档(`@ohos.app.ability.Want.d.ts:115-127`)说明真实调用方由系统注入:
`parameters['ohos.aafwk.param.callerBundleName']`。

所以 `isAllowedReceiver('com.azurekiln.qflistudio')` 恒为 false,
`forwardBridgeEvent` 直接丢弃事件。**所有子应用回传事件到不了 Dart 层**。
修法:改读 `want.parameters['ohos.aafwk.param.callerBundleName']`,保留 `want.bundleName` 作兜底。

### 断点 2(高度可疑,待真机证实):payload 目录跨沙盒不可读

- Studio 侧把 payload 写进自己沙盒:`StudioInterop.ets:282` `context.cacheDir/qfli_interop/out/<sessionId>`。
- 接收方直接读:`InteropReceiver.ets:185` `fs.accessSync(payloadDirectory)`。
- OHOS 应用有独立 mount namespace,接收方打开该绝对路径时解析到自己沙盒,目录不存在 → Refusal `bad_request: payload 目录不存在`。
- Want 里没有 `files` 兜底:`start()`(StudioInterop.ets:317-332)不下发 files 参数,`parseRequest`(InteropReceiver.ets:113-169)也不解析 files。
- design.md §1 的目录方案依赖"接收方能读调用方 cache"这一前提,该前提从未在真机验证。

验证命令(解锁后):完整 run 请求 + 抓 `QFLI_INTEROP` hilog,预期看到 `bad_request` 或 `payload 目录不存在`。

### 其他发现

- 探测(probe)路径:`probeByStart` 用 `action: analyze` 真拉起对方(StudioInterop.ets:418-468),依赖 startAbility 错误码 16000001/16000003 判未安装。接收方对 analyze 只回事件不干活,逻辑自洽。
- 接收方编译器:qfli_java 内置 JDK17(`libqfli_jdk_layout.so` 提供 startJava/pollJava;`libqfli_javac.so`=javac,`libqfli_java.so`=java)。编译能力存在,前提是 payload 能拷进来。
- 事件流:接收方逐条 `startAbility` 回传(event=accepted/progress/stdout/stderr/done/error),桥接再经 EventChannel `qfli_interop/bridge/events` 推给 Dart。断点 1 修好前,这条链最后一公里是断的。
- Dart `isSupported` 依赖引擎上报 `TargetPlatform.ohos`(interop_transport.dart:112-122),兜底环境变量 `QFLI_INTEROP=1`。
- qfli_c 现状:product default 用 `releaseKey`(debugKey 闲置),且 module.json5 无 InteropAbility。装 debug 包前需切签名。
- 会话过滤:桥接只转发 `activeSessions` 里的 sessionId,probe 的 `probe<时间戳>` 不满足 `[A-Za-z0-9_-]{8,64}`(含时间戳数字没问题,长度 8+ 满足),事件会被接收方 session 校验拦下,不影响主流程。

## 四、E2E 验证计划(解锁后执行)

1. `aa start -b com.azurekiln.qflistudio -a EntryAbility` 启动主应用。
2. 后台 `hdc hilog | grep -iE "qfli|interop"` 抓日志。
3. 直接模拟接收方事件,验证桥接断点 1:
   `hdc shell aa start -b com.azurekiln.qflistudio -a InteropBridgeAbility --ps protocol "qfli-interop/1" --ps sessionId "e2etestsession01" --ps event "done"`(带 caller 模拟,预期被丢弃 → 证实断点 1)。
4. 从 Studio UI 触发一次 Java 项目跨应用运行,观察接收方是否报 `payload 目录不存在`(断点 2)。
5. 记录全部证据到本文件。

## 五、E2E 第一轮结果(04:18,修复前)

- 桥接能力可被外部拉起(exported 注册生效),事件在 allowlist 处被静默丢弃(当时读 want.bundleName)。
- **接收方真机崩溃**:InteropAbility 的 windowStage 加载 pages/Index(FlutterPage 宿主页),该 ability 无 Flutter 引擎,`FlutterPage.ets:318 aboutToAppear` 抛 `TypeError: Cannot read property getDVModel of null` → jscrash → 进程死亡。接收方无法处理任何请求。
- 崩溃证据:hilog `A03D00/com.azurekiln.qfli.java/JSAPP` 与 faultlogger 的 jscrash 文件(shell 无权直接读取 faultlog 目录,栈从 hilog 取到)。

## 六、修复落码与复测(04:29,修复后)

修复由并行会话落码(本会话真机定位、构建、安装、复测):

| 文件 | 改动 |
| --- | --- |
| qflistudio `InteropBridgeAbility.ets` | 改读系统注入的 `parameters['ohos.aafwk.param.callerBundleName']`,读不到 fail-closed(回退到 want.bundleName 会引入可伪造身份) |
| qfli_java `InteropAbility.ets` | windowStage 改加载新页 `pages/InteropIdle`(纯 ArkUI,不触 Flutter 引擎) |
| qfli_java `pages/InteropIdle.ets` + `main_pages.json` | 新增空白页并注册 |

复测结果(两应用重建、重装后):

- 无新增 jscrash,接收方完整走完请求生命周期后正常 terminateSelf。
- Dart 侧通道注册成功:`Setting handler for channel 'qfli_interop/bridge'` 与 `qfli_interop/bridge/events`(说明引擎上报 ohos、`isSupported` 通过)。
- analyze 请求(done 事件)与 run 请求(error 事件)的 emit 都成功拉起 Studio 的 `InteropBridgeAbility`(hilog AMS `StartAbility ability:com.azurekiln.qflistudio/InteropBridgeAbility` 两条)。桥接对 shell 发起的模拟事件按注入身份 fail-closed 丢弃,属正确行为;应用间真实调用携带 qfli.java 包名,可通过 allowlist。
- **断点 2 行为坐实**:run 请求携带 Studio 沙盒 payload 路径,接收方在启动后 0.2 秒内拒绝并 emit error(无 javac 活动)。接收方 mount namespace 下 `/data/storage/el2/base/...` 解析不到 Studio 的 cache 目录,Want 中也无 files 兜底参数。
- 良性噪音:`QFLI_INTEROP_WINDOW_FAILED 0` 来自 terminateSelf 抢先于 window 内容加载完成,不影响功能,可后续把 terminateSelf 推迟到窗口就绪后消除。

## 七、剩余断点与方案

断点 2(payload 跨沙盒)未修,需协议级决策:

- 方案 A(推荐):Want 直接携带 `files` 参数(协议已有 ≤64 文件、≤256 KiB、digest 校验;日常项目远小于该上限)。接收方优先读 files,`payloadDirectory` 降级为可选。改动最小,Dart/ArkTS 两侧校验已存在。
- 方案 B:file:// URI + `FLAG_AUTH_READ_URI_PERMISSION` 授权接收方读 Studio cache 下的 manifest 与文件。保留目录方案,但要逐文件授权,改动更大。
- 方案 C:公共可写目录——OHOS 无跨应用可写目录,不可行(与 design.md §1 一致)。

选 A 时注意:Want 参数预算需实测 256 KiB 是否可达;超限时按协议回 `payload_too_large` 即可,不做截断。

## 八、断点 2 修复:URI 临时授权(04:55-05:00)

用户决策:payload 传递必须走华为跨应用权限模型,不做 Want 塞文件。选方案 B 变体——file-URI 授权 + zip:

- Studio `StudioInterop.ets`:写文件到 cache → `zlib.compressFile(目录, {level: COMPRESS_LEVEL_BEST_SPEED})`(支持文件夹、保留相对路径,Java 包结构无忧)→ Want 携带 `uri`(fileUri.getUriFromPath)+ `type: 'application/zip'` + `flags: FLAG_AUTH_READ_URI_PERMISSION` + `payloadUri` 参数。
- 接收方 `InteropReceiver.ets`:`copyPayload` 改名 `prepareProject`(async)。流程:`fs.openSync(payloadUri, READ_ONLY)`(无授权即失败,fail-closed)→ 拷 zip 进自己 cache → `zlib.decompressFile` 还原 → `fs.listFileSync(root, {recursion: true})` 取全部相对路径 → 逐条 `validatePath` + 64 文件/256KiB 复检 → 进编译。manifest.json 不再使用。
- `InteropAbility.ets`:调用点 `await prepareProject(...)`。
- Dart 协议层零改动(`payloadDirectory` 本来就是 ArkTS 侧附加的);契约测试 21 项全过(probeByStart 断言 payloadDirectory → payloadUri)。
- design.md §1/§3.1/§5 已记录变更与理由:两应用证书不同(HCrb/Gu8z),同证书应用组共享不可用,URI 授权是官方跨证书机制。

真机复测(两应用重建重装后):

- analyze 回归:emit → 桥接拉起正常(AMS StartAbility 日志)。
- 无授权拒绝路径:shell 伪造 file:// URI(无法带授权 flag),接收方 `openSync` 干净失败 → `bad_request: payload 未获授权或不存在` → error 事件回传 → 无 jscrash。fail-closed 语义验证通过。
- 授权 happy path(真实授权 → 拷贝 → 解压 → javac → 运行)只能由 Studio UI 发起(startAbility 带 flag 才有授权),shell 无法模拟,待 UI 端到端。
- 踩坑:zlib 压缩级别枚举名是 `COMPRESS_LEVEL_BEST_SPEED`,不是 `LEVEL_ONE`(ArkTS 编译报 10505001)。

## 十、全链路打通(07:16-07:28)

### 本轮修复(按发现顺序)

| # | 问题 | 修复 |
| --- | --- | --- |
| 1 | `zlib.compressFile` 对文件夹在 API26 真机上 promise 永不返回 → start() 挂死,对话框"正在连接" | zip 改 Dart 侧 `archive` 包生成(`interop_zip.dart`),ArkTS 只校验+发 URI |
| 2 | Dart 写应用级 cache,ArkTS `cacheDir` 是模块级,前缀校验必失败 → `payload 路径无效` | 改段匹配 `qfli_interop/out/` + 存在性检查 |
| 3 | 打开项目即探测 → JVMX 前台闪现像闪退 | 删 initState 探测,tooltip 改查静态目标表 |
| 4 | 接收方 `onCreate` 阶段 emit → 16200001 caller invalid,**所有事件被吞** | 请求处理推迟到 `onWindowStageCreate`(令牌就绪) |
| 5 | Dart 在 startAbility 返回后才订阅 EventChannel,快速失败事件落空窗 → 永久"正在连接" | StudioInterop 加 `pendingEvents` 缓冲,onListen 时 flush |
| 6 | singleton 复用实例走 `onNewWant` 丢 `want.uri` → payload 拿不到 | 接收方统一从 `parameters.payloadUri` 打开(openSync 对参数 uri 同样吃授权) |
| 7 | exported ability 无 skills 声明,API26 管控拒绝跨应用启动 → **201** `ABMS13313` | InteropAbility 加 skills action `action.system.qfli.interop.request`,Studio Want 同步带 action |
| 8 | `fs.listFileSync(recursion:true)` 返回以 `/` 开头的路径 → `bad_request 路径必须是相对路径` | strip 前导 `/` |
| 9 | 僵尸对话框:事件丢失后对话框永久"正在连接" | run_dialog 加启动超时(timeout+10s),超时显示错误并可关闭 |
| 10 | refuse 与 terminateSelf 竞态 → 错误事件丢失(16200001) | await 事件发出后再 terminate |

### 打通证据(07:28:41-43,shell 抓取)

```
qflistudio: SEND_URI file://…zip → START_OK
qfli.java : IN_WANTURI/IN_PARAMURI 全量到达
          : EMIT seq=1 accepted → seq=2 progress(编译) → seq=3 stderr
          : seq=4 progress(运行) → seq=5 stderr → seq=6 done
          : 会话目录正常清理(cleanUp 执行)
```

事件流完整走到 Dart(对话框在 done 后自动关闭)。stderr 两行 = javac 输出(用户项目可能非零退出或编译告警,属业务正常范围)。

### 遗留(下轮任务)

- 探测仍真拉起对方(analyze),两次快闪仍在;建议缓存探测结果或改无 UI 探测。
- 接收方 `in/` 历史失败会话的空目录未清理(只清当前会话)。
- `QFLI_INTEROP_WINDOW_FAILED 0` 为 terminateSelf 抢先 window 加载的良性噪音。
- 事件链已通但"对话框在 done 前的用户可见性"未做人工确认(自动化轮询时应用已回桌面)。
- **环境故障**:本机 `git.exe` 全路径 127 静默崩溃(疑杀软),flutter 引擎脚本已打 LOCAL PATCH(stamp 命中即复用,不调 git);git 修复后撤销 patch。
- 调试探针日志(IN_KEYS/IN_WANTURI/SEND_URI/EMIT/PREP_FAILED 等)留在代码里,均为 console.error,发布前应降级或删除。

### 测试

qfli_studio_core 4 个测试文件 81 项全过(协议 38、zip 2、契约 21、runner 20)。

## 十一、构建注意事项(沉淀)

- `flutter build hap --debug` 在本机 Windows 进程链里必死于 `ohpm.bat` 逐字符递归(Recursion Count=242)。用 Git Bash 直接调 `hvigorw assembleHap` + flutter 的 -p 参数组,产物等效(见第二节命令)。
- 手动 `ohpm install` 会清理 oh-package.json5 未声明的 oh_modules(flutter 工具链注入不落盘),非必要不要手动跑。
- 设备息屏会挡 `aa start`(Error 10106102),需解锁。
