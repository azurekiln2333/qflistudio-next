import 'package:qfli_studio_core/services/studio_profile.dart';

import 'c_runner.dart';
import 'clang_runner.dart';
import 'cpp_runner.dart';

/// Routes both source families supported by QFLIForge to their real backend.
class ForgeProgramRunner implements ProgramRunner {
  ForgeProgramRunner({
    this.c = const CProgramRunner(),
    this.cpp = const CppProgramRunner(),
    ClangProgramRunner? clang,
  }) : clang = clang ?? ClangProgramRunner();

  final CProgramRunner c;
  final CppProgramRunner cpp;
  final ClangProgramRunner clang;

  @override
  Future<ProgramRunResult?> run({
    required String projectPath,
    required String entryFile,
  }) async {
    final clangResult = await clang.run(
      projectPath: projectPath,
      entryFile: entryFile,
    );
    if (clangResult != null) return clangResult;
    final cResult = await c.run(projectPath: projectPath, entryFile: entryFile);
    if (cResult != null) return cResult;
    return cpp.run(projectPath: projectPath, entryFile: entryFile);
  }
}
