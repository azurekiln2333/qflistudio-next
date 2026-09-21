/*
 * ArkTS 接线：把 libqfli_py.so 的 run() 挂到 Flutter 的 MethodChannel 上。
 *
 * 为什么需要这一层：Flutter 的 Dart 代码不能直接调 NAPI，链路必须是
 *
 *   Dart → MethodChannel → ArkTS（本文件）→ libqfli_py.so → MicroPython
 *
 * ⚠️ 本文件有两份**逐字节相同**的副本。改任何一份都必须同步另一份，
 * 因为只有下面第二份在构建路径里——它漂了不会有任何编译错误或测试失败：
 *
 *   apps/qfli_python/native/ohos/QfliPyNative.ets                     ← 不在构建路径
 *   apps/qfli_python/ohos/entry/src/main/ets/plugins/QfliPyNative.ets ← 进构建的那份
 *
 * 为什么要留两份：native/ 不在构建路径上，所以那份不会被编译；而 ArkTS 的
 * import 是构建期解析的，`.so` 不在位整个 App 直接编不过，模板也就没法独立存在。
 *
 * 同步检查（两个哈希相等即通过）：
 *   Get-FileHash apps\qfli_python\native\ohos\QfliPyNative.ets,
 *     apps\qfli_python\ohos\entry\src\main\ets\plugins\QfliPyNative.ets -Algorithm MD5
 *
 * 启用步骤（native/README.md 里有完整版）：
 *
 *   1. 把本文件复制到
 *        ohos/entry/src/main/ets/plugins/QfliPyNative.ets
 *   2. 在 EntryAbility.ets 的 configureFlutterEngine 里加一行：
 *        registerQfliPyNativeChannel(flutterEngine);
 *   3. 把 libqfli_py.so 放到 ohos/entry/libs/arm64-v8a/
 *      （用 native/build.ps1 会自动拷过去，**不需要**改 oh-package.json5）
 *
 * ⚠️ ArkTS 的 import 是**构建期**解析的：`.so` 不在位，整个 App 直接编不过。
 * 但反过来不成立——`.so` 在位、构建通过，**不代表运行时装得上**：只要它的
 * 动态依赖里有一个 HAP 里没有的库（典型是 libc++_shared.so），dlopen 就会
 * 失败，而这条 import 拿到的会是 undefined。所以下面所有对原生模块的调用
 * 都先判空，见 nativeModule 那段注释。
 */
import qfliPyNative from 'libqfli_py.so';
import {
  FlutterEngine,
  MethodChannel,
  MethodCall,
  MethodResult,
} from '@ohos/flutter_ohos';
import { hilog } from '@kit.PerformanceAnalysisKit';

/** 与 native/src/qfli_py_napi.cpp 的返回结构一一对应。 */
interface PyRunOutcome {
  exitCode: number;
  output: string;
  error: string | null;
  truncated: boolean;
}

/** 与 native/src/qfli_py_napi.cpp 导出的成员一一对应。 */
interface QfliPyModule {
  run(source: string, stdin: string, heapKb: number): PyRunOutcome;
  version(): string;
}

/** `available` 的返回结构：不只是一个 bool，还带「为什么不可用」。 */
interface PyProbeResult {
  available: boolean;
  version: string;
  detail: string;
}

/** Dart 侧 PythonProgramRunner 用的通道名。 */
const CHANNEL_NATIVE = 'qfli_py/native';

/** 与 native/src/qfli_py_bridge.c 的默认堆大小一致（8 MB）。 */
const DEFAULT_HEAP_KB = 8 * 1024;

const LOG_DOMAIN = 0x0000;
const LOG_TAG = 'QfliPyNative';

/**
 * 原生模块句柄。
 *
 * 刻意**不**直接写 `qfliPyNative.run(...)`。
 *
 * 当 libqfli_py.so 的 dlopen 失败时，ArkTS 的这个 import 拿到的是 undefined。
 * 此时裸调会抛 "Cannot read property run of undefined"——这条报错里没有一个字
 * 有用：看不出是哪个 .so、什么原因、怎么修。而 dlopen 失败最常见的原因是
 * 「.so 带了一个 HAP 里没有的动态依赖」（比如 libc++_shared.so），hilog 里其实
 * 写得很清楚，只是没人会想到去那里找。
 *
 * 所以先取出来判空，把「不可用」变成一条能读的诊断。
 */
const nativeModule = qfliPyNative as QfliPyModule | undefined;

/** 模块是否真的可用（不是「文件在不在」，是「dlopen 成没成功」）。 */
function nativeReady(): boolean {
  return nativeModule !== undefined && nativeModule !== null
    && typeof nativeModule.run === 'function';
}

/** 模块不可用时的说明。写给用户看，不是写给日志看。 */
const MODULE_MISSING_DETAIL =
  'libqfli_py.so 没能加载：ArkTS 的 import 拿到的是 undefined，'
  + '说明这个 .so 在 dlopen 阶段就失败了。'
  + '最常见的原因是它带了一个 HAP 里没有的动态依赖（典型是 libc++_shared.so）——'
  + '在 hilog 里搜 "MUSL-LDSO" 能看到具体缺哪个库。'
  + '重新编译：apps/qfli_python/native/build.ps1（它会校验动态依赖）。';

/** 取版本号，拿不到就返回空串（不影响可用性判断）。 */
function nativeVersion(): string {
  if (!nativeReady()) {
    return '';
  }
  try {
    return nativeModule.version();
  } catch (e) {
    return '';
  }
}

function runNative(
  source: string,
  stdin: string,
  heapKb: number,
): PyRunOutcome {
  return nativeModule.run(source, stdin, heapKb) as PyRunOutcome;
}

/**
 * 启动自检。
 *
 * 做两件事，都是为了让「后端到底通没通」在 hilog 里一眼可见，不必装完再点开
 * App 手点一次运行：
 *
 *   1. 报出 .so 的加载结果和 MicroPython 的真实版本号；
 *   2. 真跑一段 Python（sys.version / sys.implementation），把结果打出来。
 *
 * 第 2 步顺带把 VM 初始化掉（8MB GC 堆），第一次按运行的时候少一点等待。
 * 整个自检失败不影响 App 启动——出错只写日志。
 *
 * 排查时：hdc shell hilog -x | Select-String QfliPyNative
 */
function selfCheck(): void {
  if (!nativeReady()) {
    hilog.error(LOG_DOMAIN, LOG_TAG, 'libqfli_py.so 未加载：%{public}s',
      MODULE_MISSING_DETAIL);
    return;
  }

  try {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'libqfli_py.so 已加载，MicroPython %{public}s',
      nativeVersion());

    const probe = runNative(
      'import sys\nprint(sys.version)\nprint(sys.implementation)',
      '', 0);
    hilog.info(LOG_DOMAIN, LOG_TAG,
      '自检 exitCode=%{public}d output=%{public}s',
      probe.exitCode, probe.output);
  } catch (e) {
    const err = e as Error;
    hilog.error(LOG_DOMAIN, LOG_TAG, '自检失败：%{public}s', err.message);
  }
}

/** 把原生执行后端注册到 Flutter 引擎上。 */
export function registerQfliPyNativeChannel(flutterEngine: FlutterEngine): void {
  selfCheck();

  const channel = new MethodChannel(
    flutterEngine.dartExecutor.getBinaryMessenger(),
    CHANNEL_NATIVE,
  );
  channel.setMethodCallHandler({
    onMethodCall(call: MethodCall, result: MethodResult): void {
      if (call.method === 'available') {
        // Dart 侧用它探测原生后端，并在不可用时把 detail 原样显示给用户。
        // 返回结构而不是裸 bool：只说「没有」没法排查，得说清楚「为什么没有」。
        const ready = nativeReady();
        const probe: PyProbeResult = {
          available: ready,
          version: ready ? nativeVersion() : '',
          detail: ready ? '' : MODULE_MISSING_DETAIL,
        };
        result.success(probe);
        return;
      }
      if (call.method !== 'run') {
        result.notImplemented();
        return;
      }
      if (!nativeReady()) {
        // 通道在、模块没加载起来：这是一次**失败**，不是「这个构建里没有后端」。
        // 不能静默吞掉，否则用户看到的结果和设备真实行为对不上。
        result.error('QFLI_PY_MODULE_MISSING', MODULE_MISSING_DETAIL, null);
        return;
      }
      try {
        const source = (call.argument('source') as string) ?? '';
        const stdin = (call.argument('stdin') as string) ?? '';
        const heapKb = (call.argument('heapKb') as number) ?? DEFAULT_HEAP_KB;
        const outcome = runNative(source, stdin, heapKb);
        result.success({
          'exitCode': outcome.exitCode,
          'output': outcome.output,
          'error': outcome.error,
          'truncated': outcome.truncated,
        });
      } catch (e) {
        const err = e as Error;
        result.error('QFLI_PY_NATIVE_FAILED', `${err.message}`, null);
      }
    },
  });
}
