import 'package:qfli_studio_core/services/studio_profile.dart';

import 'c_runner.dart';
import 'cpp_runner.dart';

/// Routes both source families supported by QFLIForge to their real backend.
class ForgeProgramRunner implements ProgramRunner {
  const ForgeProgramRunner({
    this.c = const CProgramRunner(),
    this.cpp = const CppProgramRunner(),
  });

  final CProgramRunner c;
  final CppProgramRunner cpp;

  @override
  Future<ProgramRunResult?> run({
    required String projectPath,
    required String entryFile,
  }) async {
    final cResult = await c.run(projectPath: projectPath, entryFile: entryFile);
    if (cResult != null) return cResult;
    return cpp.run(projectPath: projectPath, entryFile: entryFile);
  }
}
