/*
 * ArkTS 接线：把 libqfli_c.so 的 run() 挂到 Flutter 的 MethodChannel 上。
 *
 * 为什么需要这一层：Flutter 的 Dart 代码不能直接调 NAPI，链路必须是
 *
 *   Dart → MethodChannel → ArkTS（本文件）→ libqfli_c.so → picoc
 *
 * 用法（native/README.md 里有完整步骤）：
 *
 *   1. 把本文件放到
 *        ohos/entry/src/main/ets/plugins/QfliCNative.ets
 *   2. 在 EntryAbility.ets 的 configureFlutterEngine 里加一行：
 *        registerQfliCNativeChannel(flutterEngine);
 *   3. 在 ohos/oh-package.json5 里声明对 .so 的依赖：
 *        "dependencies": { "libqfli_c.so": "file:./libs" }
 *
 * 没有 .so 时不要引入本文件——ArkTS 的 import 是构建期解析的，
 * 文件不存在会直接让整个 App 编不过。
 */
import qfliCNative from 'libqfli_c.so';
import {
  FlutterEngine,
  MethodChannel,
  MethodCall,
  MethodResult,
} from '@ohos/flutter_ohos';

/** 与 native/src/qfli_c_napi.cpp 的返回结构一一对应。 */
interface CRunOutcome {
  exitCode: number;
  output: string;
  error: string | null;
  truncated: boolean;
}

/** Dart 侧 RunnerService 用的通道名，与 qfli_c 的 Dart 实现保持一致。 */
const CHANNEL_NATIVE = 'qfli_c/native';

function runNative(
  files: string[],
  workDir: string,
  stdin: string,
  stackSize: number,
): CRunOutcome {
  return qfliCNative.run(files, workDir, stdin, stackSize) as CRunOutcome;
}

/** 把原生执行后端注册到 Flutter 引擎上。 */
export function registerQfliCNativeChannel(flutterEngine: FlutterEngine): void {
  const channel = new MethodChannel(
    flutterEngine.dartExecutor.getBinaryMessenger(),
    CHANNEL_NATIVE,
  );
  channel.setMethodCallHandler({
    onMethodCall(call: MethodCall, result: MethodResult): void {
      if (call.method === 'available') {
        // Dart 侧用它探测原生后端是否可用。
        result.success(true);
        return;
      }
      if (call.method !== 'run') {
        result.notImplemented();
        return;
      }
      try {
        const files = (call.argument('files') as string[]) ?? [];
        const workDir = (call.argument('workDir') as string) ?? '';
        const stdin = (call.argument('stdin') as string) ?? '';
        const stackSize = (call.argument('stackSize') as number) ?? 0;
        const outcome = runNative(files, workDir, stdin, stackSize);
        result.success({
          'exitCode': outcome.exitCode,
          'output': outcome.output,
          'error': outcome.error,
          'truncated': outcome.truncated,
        });
      } catch (e) {
        const err = e as Error;
        result.error('QFLI_C_NATIVE_FAILED', `${err.message}`, null);
      }
    },
  });
}
