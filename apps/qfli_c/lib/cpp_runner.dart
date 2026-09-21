import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:qfli_studio_core/services/studio_profile.dart';

/// C++ backend boundary for QFLIForge.
///
/// The C++ interpreter is not bundled yet, so this backend reports that state
/// explicitly instead of producing fake output. The profile and routing are
/// already shared with C and can be replaced independently when the runtime is
/// ready.
class CppProgramRunner implements ProgramRunner {
  const CppProgramRunner();

  static const Set<String> _sourceExtensions = {
    '.cpp',
    '.cc',
    '.cxx',
    '.hpp',
    '.hh',
  };

  @override
  Future<ProgramRunResult?> run({
    required String projectPath,
    required String entryFile,
  }) async {
    if (!_sourceExtensions.contains(p.extension(entryFile).toLowerCase())) {
      return null;
    }
    return _notReady(p.basename(entryFile));
  }

  ProgramRunResult _notReady(String fileName) {
    final controller = StreamController<String>();
    scheduleMicrotask(() {
      controller
        ..add('C++ 运行后端尚未就绪。')
        ..add('现在可以编辑、格式化和保存 C++ 项目。')
        ..close();
    });
    return ProgramRunResult(
      title: '运行 $fileName（C++ 运行后端未就绪）',
      stdout: controller.stream,
      stderr: const Stream<String>.empty(),
      exitCode: Future<int>.value(kProgramNotRunExitCode),
    );
  }
}
