import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:qfli_python/main.dart' show pythonProfile;
import 'package:qfli_python/python_runner.dart';
import 'package:qfli_studio_core/services/project_templates.dart';
import 'package:qfli_studio_core/services/runner_service.dart';
import 'package:qfli_studio_core/services/studio_profile.dart';

/// Python 版 App 的接线测试。
///
/// 覆盖的正是「一个语言一个 App」的全部接缝：内核怎么知道该显示哪个模板、
/// 该跑哪个入口文件、以及运行后端有没有正确接管/交回。
///
/// 运行后端这一块同时覆盖两条路：**原生后端可用**（用 MethodChannel 替身模拟
/// `libqfli_py.so` 那一侧）和**原生后端不可用**（通道缺失，等价于打包时没把
/// `.so` 放进去；或者通道在、但 .so 加载失败）。
const MethodChannel _nativeChannel = MethodChannel('qfli_py/native');

/// App 自己写的诊断行的前缀，与 `python_runner.dart` 里的 `_appPrefix` 一致。
const String _appPrefix = '[qfli] ';

/// 「程序根本没跑起来」的退出码，与 `PythonProgramRunner.notRunExitCode` 一致。
///
/// 单独拎出来断言，是因为真机上踩过一次：后端没打进 HAP 时显示的是
/// 「（运行结束，退出码 1）」，看起来像程序自己跑完报错，其实一行都没执行。
const int _notRun = PythonProgramRunner.notRunExitCode;

/// 装一个原生后端的替身。
///
/// 传 null 表示「这个构建里没有原生后端」——等价于设备上没打进 `.so`，
/// 此时 `invokeMethod` 会抛 `MissingPluginException`。
void _installNativeHandler(Future<Object?> Function(MethodCall call)? handler) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_nativeChannel, handler);
}

/// 一次成功的原生执行返回。
Map<String, Object?> _outcome({
  int exitCode = 0,
  String output = '',
  String? error,
  bool truncated = false,
}) => <String, Object?>{
  'exitCode': exitCode,
  'output': output,
  'error': error,
  'truncated': truncated,
};

/// `available` 的返回结构（与 ArkTS 侧 PyProbeResult 一致）。
///
/// 刻意不是裸 bool：只说「不可用」没法排查，「没打进 HAP」和「打进去了但
/// dlopen 失败」的修法完全不同，得把原因带回来。
Map<String, Object?> _probe({
  bool available = true,
  String version = '1.24.1 (ecfdd5d)',
  String detail = '',
}) => <String, Object?>{
  'available': available,
  'version': version,
  'detail': detail,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory project;
  late StudioProfile? previousProfile;

  setUp(() {
    previousProfile = StudioProfile.current;
    StudioProfile.current = pythonProfile;
    project = Directory.systemTemp.createTempSync('qfli_python_app_test');
  });

  tearDown(() {
    StudioProfile.current = previousProfile;
    _installNativeHandler(null);
    if (project.existsSync()) project.deleteSync(recursive: true);
  });

  void write(String relative, String content) {
    final file = File(p.join(project.path, relative));
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
  }

  Future<ProgramRunResult?> runEntry(String entry) => pythonProfile.runner!.run(
    projectPath: project.path,
    entryFile: p.join(project.path, entry),
  );

  group('档位收窄', () {
    test('新建项目只放行「空项目」和 Python', () {
      expect(pythonProfile.filterTemplates(ProjectTemplate.values), [
        ProjectTemplate.empty,
        ProjectTemplate.python,
      ]);
    });

    test('默认模板是 Python 而不是空项目', () {
      expect(pythonProfile.defaultTemplate, ProjectTemplate.python);
    });

    test('语言筛选芯片只剩 Python', () {
      // 首页传给档位的候选本来就不含「空项目」——它不是一门语言。
      const all = ['Web', 'Python', 'Java', 'Dart'];
      expect(pythonProfile.filterLanguages(all), ['Python']);
    });

    test('产品名使用 QFLIPyFlow', () {
      expect(pythonProfile.appTitle, 'QFLIPyFlow');
      expect(pythonProfile.showEditorTabs, isFalse);
    });
  });

  group('入口文件识别', () {
    test('优先命中 main.py', () {
      write('main.py', 'print(1)');
      write('other.txt', 'x');
      expect(
        RunnerService.findEntry(project.path),
        p.join(project.path, 'main.py'),
      );
    });

    test('入口表覆盖了模板自带的入口文件', () {
      // 这是「一个语言一个 App」最容易出错的地方：模板统一把源码放在 src/ 下，
      // 而入口表要是只写了根目录的文件名，新建项目后点运行就会找不到入口。
      final mainFile = ProjectTemplate.python.mainFile;
      expect(mainFile, isNotNull, reason: '模板里没有文件');
      expect(pythonProfile.entryFileNames, contains(mainFile));
    });

    test('模板把源码放在 src/ 下时也能找到入口', () {
      final mainFile = ProjectTemplate.python.mainFile!;
      write(mainFile, '# 示例');
      expect(
        RunnerService.findEntry(project.path),
        p.join(project.path, mainFile),
      );
    });
  });

  group('运行后端：没有原生后端时', () {
    test('本语言文件被接管，并说清楚缺的是什么', () async {
      write('main.py', 'print(1)');
      final result = await runEntry('main.py');
      expect(result, isNotNull, reason: '运行后端没有接管本语言文件');
      expect(result!.title, contains('缺少 Python 执行后端'));
      expect(await result.stdout.toList(), isNotEmpty);
      expect(await result.exitCode, _notRun);
    });

    test('别的语言文件交回内核', () async {
      write('main.c', 'x');
      expect(await runEntry('main.c'), isNull);
    });
  });

  group('运行后端：原生后端可用时', () {
    test('走原生，输出与退出码原样带回', () async {
      write('main.py', 'print("hi")');
      final calls = <MethodCall>[];
      _installNativeHandler((call) async {
        calls.add(call);
        if (call.method == 'available') return _probe();
        expect(call.method, 'run');
        final args = call.arguments as Map;
        expect(args['source'], contains('print("hi")'));
        return _outcome(output: 'hi\n');
      });

      final result = await runEntry('main.py');

      // 标题带版本号，所以这里是 'MicroPython 1.24.1 (ecfdd5d)'，
      // 「内嵌 MicroPython」只是拿不到版本号时的退路。
      expect(result!.title, contains('MicroPython'));
      expect(await result.stdout.toList(), ['hi']);
      expect(await result.exitCode, 0);
      // 先探测、再执行：没有探测结果就不该盲调 run。
      expect(calls.map((call) => call.method), ['available', 'run']);
    });

    test('标题带上从 .so 里问出来的真实版本号', () async {
      // 版本号是后端身份的自证：它来自 MicroPython 自己的头文件，不是写死的
      // 常量。显示出来，用户一眼就能判断跑的是不是上游那个实现。
      write('main.py', 'print(1)');
      _installNativeHandler((call) async {
        if (call.method == 'available') {
          return _probe(version: '1.24.1 (ecfdd5d)');
        }
        return _outcome();
      });

      final result = await runEntry('main.py');

      expect(result!.title, contains('MicroPython 1.24.1 (ecfdd5d)'));
    });

    test('available 只回 bool 的旧接线也能跑（两份 .ets 副本没同步时）', () async {
      write('main.py', 'print("hi")');
      _installNativeHandler((call) async {
        if (call.method == 'available') return true;
        return _outcome(output: 'hi\n');
      });

      final result = await runEntry('main.py');

      expect(await result!.stdout.toList(), ['hi']);
      // 拿不到版本号就退回泛称，不能因为少了字段就把整次运行判成失败。
      expect(result.title, contains('内嵌 MicroPython'));
    });

    test('input.txt 整段原样喂给解释器，不按行切', () async {
      // MicroPython 的 input() 自己按行消费；按行切好再拼回去会破坏
      // 「空行」「最后一行没有换行符」这类细节。
      write('main.py', 'print(input())');
      write('input.txt', '第一行\n第二行\n');
      Map? seen;
      _installNativeHandler((call) async {
        if (call.method == 'available') return _probe();
        seen = call.arguments as Map;
        return _outcome();
      });

      await runEntry('main.py');

      expect(seen!['stdin'], '第一行\n第二行\n');
    });

    test('没有 input.txt 时 stdin 是空串', () async {
      write('main.py', 'print(1)');
      Map? seen;
      _installNativeHandler((call) async {
        if (call.method == 'available') return _probe();
        seen = call.arguments as Map;
        return _outcome();
      });

      await runEntry('main.py');

      expect(seen!['stdin'], '');
    });

    test('解释器的错误归到 stderr，截断有提示', () async {
      write('main.py', 'boom');
      _installNativeHandler((call) async {
        if (call.method == 'available') return _probe();
        return _outcome(
          exitCode: 1,
          output: 'ok\n',
          error: 'Traceback...\nNameError: x',
          truncated: true,
        );
      });

      final result = await runEntry('main.py');

      // 程序自己的输出不带前缀；App 补的提示带 [qfli]，两者不会混。
      expect(await result!.stdout.toList(), ['ok']);
      expect(await result.stderr.toList(), [
        'Traceback...',
        'NameError: x',
        // 这里可以省掉花括号：后面跟的是中文字符，Dart 的标识符不含 CJK，
        // 不会像 `$_appPrefixPython` 那样被当成一个变量名。
        '$_appPrefix输出过长，已被截断。',
      ]);
      expect(await result.exitCode, 1);
    });

    test('sys.exit(3) 的退出码透传，不算错误', () async {
      write('main.py', 'import sys\nsys.exit(3)');
      _installNativeHandler((call) async {
        if (call.method == 'available') return _probe();
        return _outcome(exitCode: 3);
      });

      final result = await runEntry('main.py');

      expect(await result!.exitCode, 3);
      expect(await result.stderr.toList(), isEmpty);
    });

    test('原生后端存在但执行失败时，把错误显示出来而不是静默降级', () async {
      // 悄悄退回别的执行路径会让用户看到的运行结果和设备的真实行为对不上，
      // 排查问题时会被误导。
      write('main.py', 'boom');
      _installNativeHandler((call) async {
        if (call.method == 'available') return _probe();
        throw PlatformException(
          code: 'QFLI_PY_NATIVE_FAILED',
          message: '内存不足：申请 MicroPython 的 GC 堆失败。',
        );
      });

      final result = await runEntry('main.py');

      expect(await result!.stderr.toList(), contains(contains('内存不足')));
      expect(await result.exitCode, _notRun);
      expect(result.title, isNot(contains('缺少')));
    });
  });

  group('运行后端：.so 在但没加载起来时', () {
    // 这是真机上真实踩过的坑：libqfli_py.so 打进了 HAP、也装到了设备上，
    // 但它带了一个 HAP 里没有的 DT_NEEDED（libc++_shared.so），dlopen 失败。
    // ArkTS 的 import 拿到 undefined，裸调就会抛
    // "Cannot read property run of undefined" —— 一句有用的信息都没有。
    //
    // 现在的接线会把这种情况变成一条能读的诊断，而且**不**当成「没有后端」：
    // 后端是在的，只是坏了，必须报出来。

    test('说清楚是加载失败，而不是「没打进 HAP」', () async {
      write('main.py', 'print(1)');
      _installNativeHandler((call) async {
        if (call.method == 'available') {
          return _probe(
            available: false,
            detail: 'libqfli_py.so 没能加载：dlopen 阶段就失败了。',
          );
        }
        fail('模块不可用时不该调用 run');
      });

      final result = await runEntry('main.py');

      expect(result!.title, contains('缺少 Python 执行后端'));
      final lines = await result.stdout.toList();
      // ArkTS 侧给的原因要原样透出来——它比 Dart 侧猜的准。
      expect(
        lines,
        contains(
          '$_appPrefix'
          'libqfli_py.so 没能加载：dlopen 阶段就失败了。',
        ),
      );
      expect(await result.exitCode, _notRun);
    });

    test('run 阶段报 QFLI_PY_MODULE_MISSING 时原样显示原因', () async {
      // 探测和 run 之间模块状态理论上不该变，但两条路径都要有兜底：
      // 一旦走到这里，说明前面那次 available 拿到了错的结果。
      write('main.py', 'print(1)');
      _installNativeHandler((call) async {
        if (call.method == 'available') return _probe();
        throw PlatformException(
          code: 'QFLI_PY_MODULE_MISSING',
          message: 'libqfli_py.so 没能加载，在 hilog 里搜 "MUSL-LDSO"。',
        );
      });

      final result = await runEntry('main.py');

      final lines = await result!.stderr.toList();
      expect(lines.single, startsWith(_appPrefix));
      expect(lines.single, contains('MUSL-LDSO'));
      // 是「坏了」不是「没有」：标题不能退回「缺少执行后端」。
      expect(result.title, isNot(contains('缺少')));
      expect(await result.exitCode, _notRun);
    });

    test('「后端没跑起来」的退出码跟「程序自己退出 1」不会撞车', () async {
      // 终端面板把非 0 一律渲染成「（运行结束，退出码 N）」。要是这里也用 1，
      // 用户看到「运行结束，退出码 1」会以为程序跑了并且报错，实际上它一行都没跑。
      expect(_notRun, isNot(1));
      expect(_notRun, 127, reason: '借用 shell 的 command not found 约定');

      write('main.py', 'print(1)');
      _installNativeHandler((call) async {
        if (call.method == 'available') {
          return _probe(available: false, detail: '没打进 HAP。');
        }
        fail('模块不可用时不该调用 run');
      });

      final notRun = await runEntry('main.py');
      expect(await notRun!.exitCode, 127);

      // 对照组：程序真的跑了、自己 sys.exit(1)，退出码就是 1，不带任何前缀。
      _installNativeHandler((call) async {
        if (call.method == 'available') return _probe();
        return _outcome(exitCode: 1);
      });

      final realExit = await runEntry('main.py');
      expect(await realExit!.exitCode, 1);
    });
  });

  group('运行按钮分流', () {
    test('点运行拿到结果，而不是掉进「移动端跑不了」的兜底提示', () async {
      write('main.py', 'print(1)');
      final result = await RunnerService.runProject(
        projectPath: project.path,
        entryFile: p.join(project.path, 'main.py'),
      );
      expect(result, isNotNull);
      expect(result!.hint, isNull, reason: '后端接管了就不该走兜底提示');
      expect(result.title, contains('Python 执行后端'));
    });
  });
}
