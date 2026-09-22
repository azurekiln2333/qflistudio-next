import 'package:flutter_test/flutter_test.dart';
import 'package:qfli_studio_core/runtime/native_runtime.dart';

void main() {
  test('unavailable runtimes never report a successful execution', () async {
    const runtime = UnavailableRuntime(
      languageTypes: {'c', 'cpp'},
      runtimeName: 'qfli_clang_bridge',
      diagnostic: 'device bridge is not installed',
    );

    final probe = await runtime.probe();
    final result = await runtime.run(
      const RuntimeRunRequest(projectPath: '.', entryFile: 'main.cpp'),
    );

    expect(probe.languageTypes, containsAll(<String>['c', 'cpp']));
    expect(probe.isAvailable, isFalse);
    expect(result.exitCode, 127);
    expect(result.stderr, contains('not installed'));
  });

  test('requests carry bounded execution defaults', () {
    const compile = RuntimeCompileRequest(
      projectPath: '/project',
      entryFile: 'main.c',
      sources: {'main.c': 'int main(void) { return 0; }'},
    );
    const run = RuntimeRunRequest(projectPath: '/project', entryFile: 'main.c');

    expect(compile.timeout, const Duration(seconds: 30));
    expect(run.timeout, const Duration(seconds: 10));
    expect(run.outputLimit, 1024 * 1024);
  });
}
