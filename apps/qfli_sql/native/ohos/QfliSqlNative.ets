import qfliSqlNative from 'libqfli_sql.so';
import {
  FlutterEngine,
  MethodChannel,
  MethodCall,
  MethodResult,
} from '@ohos/flutter_ohos';

interface QfliSqlModule {
  execute(source: string, databasePath: string): {
    available: boolean;
    exitCode: number;
    output: string;
    error: string;
    truncated: boolean;
  };
  version(): string;
}

const nativeModule = qfliSqlNative as QfliSqlModule | undefined;
const CHANNEL_NATIVE = 'qfli_sql/native';

export function registerQfliSqlNativeChannel(engine: FlutterEngine): void {
  const channel = new MethodChannel(
    engine.dartExecutor.getBinaryMessenger(),
    CHANNEL_NATIVE,
  );
  channel.setMethodCallHandler({
    onMethodCall(call: MethodCall, result: MethodResult): void {
      if (nativeModule === undefined) {
        result.error(
          'SQL_NATIVE_MISSING',
          'libqfli_sql.so could not be loaded.',
          null,
        );
        return;
      }
      try {
        if (call.method === 'execute') {
          const source = call.argument('source') as string;
          const databasePath = call.argument('databasePath') as string;
          result.success(nativeModule.execute(source, databasePath));
        } else if (call.method === 'version') {
          result.success(nativeModule.version());
        } else {
          result.notImplemented();
        }
      } catch (error) {
        result.error('SQL_NATIVE_FAILED', `${error}`, null);
      }
    },
  });
}
