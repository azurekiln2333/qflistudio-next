/// Shared contract for language runtimes bundled with QFLI products.
///
/// A runtime may be an interpreter, compiler plus in-process sandbox, VM, or
/// database engine. The UI must use the probe result instead of guessing from
/// the presence of a file or a desktop executable.
library;

enum RuntimeAvailability { available, unavailable, unsupported }

class RuntimeProbe {
  const RuntimeProbe({
    required this.languageTypes,
    required this.availability,
    required this.runtimeName,
    required this.version,
    this.diagnostic,
  });

  final Set<String> languageTypes;
  final RuntimeAvailability availability;
  final String runtimeName;
  final String version;
  final String? diagnostic;

  bool get isAvailable => availability == RuntimeAvailability.available;
}

class RuntimeCompileRequest {
  const RuntimeCompileRequest({
    required this.projectPath,
    required this.entryFile,
    required this.sources,
    this.languageType,
    this.timeout = const Duration(seconds: 30),
  });

  final String projectPath;
  final String entryFile;
  final Map<String, String> sources;
  final String? languageType;
  final Duration timeout;
}

class RuntimeCompileResult {
  const RuntimeCompileResult({
    required this.success,
    required this.diagnostics,
    this.artifactId,
  });

  final bool success;
  final String diagnostics;
  final String? artifactId;
}

class RuntimeRunRequest {
  const RuntimeRunRequest({
    required this.projectPath,
    required this.entryFile,
    this.artifactId,
    this.stdin = '',
    this.timeout = const Duration(seconds: 10),
    this.outputLimit = 1024 * 1024,
  });

  final String projectPath;
  final String entryFile;
  final String? artifactId;
  final String stdin;
  final Duration timeout;
  final int outputLimit;
}

class RuntimeRunResult {
  const RuntimeRunResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
    this.timedOut = false,
    this.truncated = false,
  });

  final int exitCode;
  final String stdout;
  final String stderr;
  final bool timedOut;
  final bool truncated;
}

abstract interface class NativeRuntime {
  Future<RuntimeProbe> probe();

  Future<RuntimeCompileResult> compile(RuntimeCompileRequest request);

  Future<RuntimeRunResult> run(RuntimeRunRequest request);

  Future<void> cancel(String runId);

  Future<void> dispose();
}

/// A truthful runtime for products whose device backend has not been shipped.
/// It is useful during development because callers get a typed diagnostic and
/// cannot accidentally render a successful placeholder execution.
class UnavailableRuntime implements NativeRuntime {
  const UnavailableRuntime({
    required this.languageTypes,
    required this.runtimeName,
    required this.diagnostic,
  });

  final Set<String> languageTypes;
  final String runtimeName;
  final String diagnostic;

  @override
  Future<RuntimeProbe> probe() async => RuntimeProbe(
    languageTypes: languageTypes,
    availability: RuntimeAvailability.unavailable,
    runtimeName: runtimeName,
    version: 'unavailable',
    diagnostic: diagnostic,
  );

  @override
  Future<RuntimeCompileResult> compile(RuntimeCompileRequest request) async =>
      RuntimeCompileResult(success: false, diagnostics: diagnostic);

  @override
  Future<RuntimeRunResult> run(RuntimeRunRequest request) async => RuntimeRunResult(
    exitCode: 127,
    stdout: '',
    stderr: diagnostic,
  );

  @override
  Future<void> cancel(String runId) async {}

  @override
  Future<void> dispose() async {}
}
