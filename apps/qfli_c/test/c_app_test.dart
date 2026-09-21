import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:qfli_c/c_runner.dart';
import 'package:qfli_c/main.dart' show cProfile;
import 'package:qfli_studio_core/services/project_templates.dart';
import 'package:qfli_studio_core/services/runner_service.dart';
import 'package:qfli_studio_core/services/studio_profile.dart';

/// 换掉档位里的运行后端，其余设置照搬 [cProfile]。
///
/// 用来把「跑飞了」这类用例的上限压到几百毫秒——生产默认是 10 秒，
/// 真按默认跑，一个用例就卡十秒。
StudioProfile profileWith(ProgramRunner runner) => StudioProfile(
  id: cProfile.id,
  appTitle: cProfile.appTitle,
  templates: cProfile.templates,
  runner: runner,
  entryFileNames: cProfile.entryFileNames,
);

/// C 版 App 的接线测试：档位收窄 + 运行按钮真的把 C 代码跑起来。
///
/// 这些用例覆盖的正是「一个语言一个 App」这个方案的全部接缝——
/// 内核怎么知道该显示哪个模板、该用哪个运行后端、该跑哪个入口文件。
void main() {
  // MethodChannel 需要绑定；真实 App 里由 runApp 完成。
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory project;
  late StudioProfile? previousProfile;

  setUp(() {
    previousProfile = StudioProfile.current;
    StudioProfile.current = cProfile;
    project = Directory.systemTemp.createTempSync('qfli_c_app_test');
  });

  tearDown(() {
    StudioProfile.current = previousProfile;
    if (project.existsSync()) project.deleteSync(recursive: true);
  });

  void write(String relative, String content) {
    final file = File(p.join(project.path, relative));
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
  }

  /// 走一遍「点运行」的完整路径，并断言确实拿到了结果。
  Future<RunResult> runC([String entry = 'main.c']) async {
    final result = await RunnerService.runProject(
      projectPath: project.path,
      entryFile: p.join(project.path, entry),
    );
    expect(result, isNotNull, reason: '运行按钮没有返回结果');
    return result!;
  }

  /// 终端面板就是这么逐行消费输出流的。
  Future<List<String>> stdoutOf(RunResult result) => result.stdout!.toList();
  Future<List<String>> stderrOf(RunResult result) => result.stderr!.toList();

  group('档位收窄', () {
    test('新建项目只放行「空项目」和 C', () {
      expect(cProfile.filterTemplates(ProjectTemplate.values), [
        ProjectTemplate.empty,
        ProjectTemplate.c,
      ]);
    });

    test('默认模板是 C 而不是空项目', () {
      expect(cProfile.defaultTemplate, ProjectTemplate.c);
    });

    test('语言筛选芯片只剩 C', () {
      // 首页传给档位的候选本来就不含「空项目」——它不是一门语言。
      const all = ['C', 'Python', 'Java', 'C++', 'Web'];
      expect(cProfile.filterLanguages(all), ['C']);
    });

    test('产品名带 C 版后缀', () {
      expect(cProfile.appTitle, 'QFLIForge');
      expect(cProfile.showEditorTabs, isFalse);
    });
  });

  group('入口文件识别', () {
    test('优先命中 main.c', () {
      write('main.c', 'int main(void) { return 0; }');
      write('main.py', 'print("hi")');
      expect(
        RunnerService.findEntry(project.path),
        p.join(project.path, 'main.c'),
      );
    });

    test('main.c 在 src/ 下也能找到', () {
      write('src/main.c', 'int main(void) { return 0; }');
      // 入口表里写的是 'src/main.c'，p.join 不会改动段内已有的分隔符。
      expect(
        RunnerService.findEntry(project.path),
        p.join(project.path, 'src/main.c'),
      );
    });

    test('没有 C 文件时不误报入口', () {
      write('main.py', 'print("hi")');
      // 默认入口表里的 main.py 仍会命中，但 C 版的运行后端不会接管它。
      expect(
        RunnerService.findEntry(project.path),
        p.join(project.path, 'main.py'),
      );
    });
  });

  group('运行按钮', () {
    test('跑 main.c 拿到输出与退出码', () async {
      write('main.c', '''
#include <stdio.h>
int main(void) {
    for (int i = 1; i <= 3; i++) printf("第 %d 行\\n", i);
    return 7;
}
''');
      final result = await runC();
      expect(result.title, contains('应用内 C 解释器'));
      expect(await stdoutOf(result), ['第 1 行', '第 2 行', '第 3 行']);
      expect(await stderrOf(result), isEmpty);
      expect(await result.exitCode, 7);
    });

    test('多文件工程：main.c 调用 utils.c 里的函数', () async {
      write('utils.h', 'int triple(int x);');
      write('utils.c', 'int triple(int x) { return x * 3; }');
      write('main.c', '''
#include <stdio.h>
#include "utils.h"
int main(void) {
    printf("%d\\n", triple(14));
    return 0;
}
''');
      final result = await runC();
      expect(await stderrOf(result), isEmpty);
      expect(await stdoutOf(result), ['42']);
    });

    test('input.txt 作为标准输入', () async {
      write('input.txt', '7 35\n');
      write('main.c', '''
#include <stdio.h>
int main(void) {
    int a = 0, b = 0;
    scanf("%d %d", &a, &b);
    printf("%d\\n", a * b);
    return 0;
}
''');
      final result = await runC();
      expect(await stderrOf(result), isEmpty);
      expect(await stdoutOf(result), ['245']);
    });

    test('没有 input.txt 时 scanf 读到 EOF 而不是崩溃', () async {
      write('main.c', '''
#include <stdio.h>
int main(void) {
    int a = 99;
    int read = scanf("%d", &a);
    printf("%d %d\\n", read, a);
    return 0;
}
''');
      final result = await runC();
      expect(await stdoutOf(result), ['-1 99']);
    });

    test('语法错误进 stderr 并带回原始行号', () async {
      write('main.c', '''
#include <stdio.h>
int main(void) {
    int a = ;
    return 0;
}
''');
      final result = await runC();
      final errors = await stderrOf(result);
      expect(errors.any((line) => line.contains('语法错误')), isTrue);
      expect(errors.any((line) => line.contains('main.c:3')), isTrue);
      expect(await result.exitCode, isNot(0));
    });

    test('死循环被时间上限中止，报错点明是超时', () async {
      // 默认上限是 10 秒，测试里换成很短的一个，免得一个用例就卡十秒。
      StudioProfile.current = profileWith(
        const CProgramRunner(timeLimit: Duration(milliseconds: 250)),
      );
      write('main.c', '''
int main(void) {
    for (;;) { }
    return 0;
}
''');
      final result = await runC();
      final errors = await stderrOf(result);
      expect(errors.any((line) => line.contains('还没结束')), isTrue);
      expect(await result.exitCode, 124);
    });

    test('百万级循环不会被误判成死循环', () async {
      // 这条曾经是坏的：800 万步的旧上限只够跑 0.3 秒，
      // 300 万次的求和循环会被误报成死循环。
      write('main.c', '''
#include <stdio.h>
int main(void) {
    long sum = 0;
    for (int i = 0; i < 3000000; i++) sum += i;
    printf("%ld\\n", sum % 97);
    return 0;
}
''');
      final result = await runC();
      expect(await stderrOf(result), isEmpty);
      expect(await result.exitCode, 0);
    });

    test('缺 input.txt 时终端里出现提示，而不是一个看不出错的结果', () async {
      // 没有输入时程序会拿着 0 值继续算，输出一个**看起来正常但其实错误**
      // 的结果。这条断言保证用户至少能看到原因。
      write('main.c', '''
#include <stdio.h>
int main(void) {
    int n, sum = 0;
    for (int i = 0; i < 3; i++) {
        scanf("%d", &n);
        sum += n;
    }
    printf("和 = %d\\n", sum);
    return 0;
}
''');
      final result = await runC();
      expect(await stdoutOf(result), ['和 = 0']);
      final notes = await stderrOf(result);
      expect(notes.any((line) => line.contains('input.txt')), isTrue);
    });

    test('放了 input.txt 就不再提示', () async {
      write('input.txt', '10\n20\n30\n');
      write('main.c', '''
#include <stdio.h>
int main(void) {
    int n, sum = 0;
    for (int i = 0; i < 3; i++) {
        scanf("%d", &n);
        sum += n;
    }
    printf("和 = %d\\n", sum);
    return 0;
}
''');
      final result = await runC();
      expect(await stdoutOf(result), ['和 = 60']);
      expect(await stderrOf(result), isEmpty);
    });

    test('GBK 编码的源码不会读崩', () async {
      // 用 GBK 字节写中文注释和字符串，模拟从 Windows 记事本存出来的文件。
      const source =
          '#include <stdio.h>\n'
          'int main(void) {\n'
          '    printf("你好\\n");  // 中文注释\n'
          '    return 0;\n'
          '}\n';
      const gbk = <String, List<int>>{
        '你': [0xC4, 0xE3],
        '好': [0xBA, 0xC3],
        '中': [0xD6, 0xD0],
        '文': [0xCE, 0xC4],
        '注': [0xD7, 0xA2],
        '释': [0xCA, 0xCD],
      };
      final bytes = <int>[];
      for (final unit in source.codeUnits) {
        final mapped = gbk[String.fromCharCode(unit)];
        if (mapped != null) {
          bytes.addAll(mapped);
        } else {
          bytes.add(unit);
        }
      }
      File(p.join(project.path, 'main.c')).writeAsBytesSync(bytes);

      final result = await runC();
      expect(await stderrOf(result), isEmpty);
      expect(await stdoutOf(result), ['你好']);
    });
  });

  group('原生后端', () {
    // 用假的原生后端替身，把「Dart → MethodChannel → ArkTS → NAPI」这条
    // 链路的 Dart 这一段测掉。真实 .so 需要 NDK 才能编，见 native/README.md。
    const channel = MethodChannel('qfli_c/native');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    void mockNative({
      required bool available,
      Map<String, Object?>? runResult,
    }) {
      messenger.setMockMethodCallHandler(channel, (call) async {
        switch (call.method) {
          case 'available':
            return available;
          case 'run':
            if (runResult == null) {
              throw PlatformException(
                code: 'QFLI_C_NATIVE_FAILED',
                message: '解释器崩了',
              );
            }
            return runResult;
          default:
            return null;
        }
      });
    }

    tearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
    });

    test('原生后端可用时优先走 .so', () async {
      write('main.c', 'int main(void) { return 0; }');
      mockNative(
        available: true,
        runResult: {
          'exitCode': 3,
          'output': '原生输出\n第二行\n',
          'error': null,
          'truncated': false,
        },
      );
      final result = await runC();
      expect(result.title, contains('原生 picoc'));
      expect(await stdoutOf(result), ['原生输出', '第二行']);
      expect(await stderrOf(result), isEmpty);
      expect(await result.exitCode, 3);
    });

    test('原生后端只把 .c 交给 picoc，头文件走 #include', () async {
      write('utils.h', 'int triple(int x);');
      write('utils.c', 'int triple(int x) { return x * 3; }');
      write(
        'main.c',
        '#include "utils.h"\nint main(void) { return triple(1); }',
      );
      final seen = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'available') return true;
        if (call.method == 'run') {
          final args = call.arguments as Map;
          seen.addAll((args['files'] as List).cast<String>());
          return {
            'exitCode': 0,
            'output': '',
            'error': null,
            'truncated': false,
          };
        }
        return null;
      });
      await runC();
      expect(seen.where((f) => f.endsWith('.c')).length, 2);
      expect(seen.any((f) => f.endsWith('utils.h')), isFalse);
      // 入口必须排在第一个：picoc 顺序扫描，含 main() 的应该先被定义。
      expect(seen.first, endsWith('main.c'));
    });

    test('原生后端报错时把诊断信息推到 stderr', () async {
      write('main.c', 'int main(void) { return 0; }');
      mockNative(
        available: true,
        runResult: {
          'exitCode': 1,
          'output': '',
          'error': 'main.c:3: syntax error\n',
          'truncated': false,
        },
      );
      final result = await runC();
      expect(await stdoutOf(result), isEmpty);
      expect(await stderrOf(result), ['main.c:3: syntax error']);
      expect(await result.exitCode, 1);
    });

    test('输出被截断时补一条提示', () async {
      write('main.c', 'int main(void) { return 0; }');
      mockNative(
        available: true,
        runResult: {
          'exitCode': 0,
          'output': 'x\n',
          'error': null,
          'truncated': true,
        },
      );
      final result = await runC();
      expect(await stderrOf(result), ['输出过长，已被截断。']);
    });

    test('设备上没有 .so 时退回 Dart 解释器', () async {
      write('main.c', '''
#include <stdio.h>
int main(void) { printf("dart\\n"); return 0; }
''');
      mockNative(available: false);
      final result = await runC();
      expect(result.title, contains('应用内 C 解释器'));
      expect(await stdoutOf(result), ['dart']);
    });

    test('原生后端存在但执行失败时不静默换后端', () async {
      write('main.c', 'int main(void) { return 0; }');
      mockNative(available: true); // run 会抛 PlatformException
      final result = await runC();
      // 悄悄退回解释器会让用户看到的结果和设备的真实行为对不上，
      // 所以这里要把失败暴露出来。
      expect(await stderrOf(result), isNotEmpty);
      expect(await result.exitCode, isNot(0));
    });
  });

  group('不接管', () {
    test('非 .c 入口交回内核', () async {
      write('main.py', 'print("hi")');
      final result = await cProfile.runner!.run(
        projectPath: project.path,
        entryFile: p.join(project.path, 'main.py'),
      );
      expect(result, isNull);
    });

    test('C++ 入口也交回内核（本版不做 C++）', () async {
      write('main.cpp', 'int main() { return 0; }');
      final result = await cProfile.runner!.run(
        projectPath: project.path,
        entryFile: p.join(project.path, 'main.cpp'),
      );
      expect(result, isNull);
    });
  });
}
