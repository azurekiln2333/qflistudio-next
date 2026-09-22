import 'dart:async';
import 'dart:io';

/// Starts a process for [ProcessSupervisor].
///
/// Keeping process creation behind this callback lets tests provide a fake
/// [Process] without changing the production API.
typedef ProcessStarter =
    Future<Process> Function(
      String executable,
      List<String> arguments, {
      String? workingDirectory,
      Map<String, String>? environment,
      bool includeParentEnvironment,
      bool runInShell,
      ProcessStartMode mode,
    });

/// Terminates a Windows process and all of its descendants.
///
/// The return value reports whether the tree command handled the process. A
/// false result causes [ManagedProcess] to fall back to [Process.kill].
typedef WindowsProcessTreeTerminator = Future<bool> Function(int pid);

/// Owns every process started through it and cancels all remaining processes
/// during shutdown.
class ProcessSupervisor {
  ProcessSupervisor({
    ProcessStarter? processStarter,
    WindowsProcessTreeTerminator? windowsProcessTreeTerminator,
    bool? isWindows,
  }) : _processStarter = processStarter ?? _startProcess,
       _windowsProcessTreeTerminator =
           windowsProcessTreeTerminator ?? _terminateWindowsProcessTree,
       _isWindows = isWindows ?? Platform.isWindows;

  final ProcessStarter _processStarter;
  final WindowsProcessTreeTerminator _windowsProcessTreeTerminator;
  final bool _isWindows;
  final Set<ManagedProcess> _processes = <ManagedProcess>{};
  bool _disposed = false;

  /// Number of processes that have not completed cleanup.
  int get activeCount => _processes.length;

  /// A snapshot of the currently owned processes.
  Iterable<ManagedProcess> get activeProcesses =>
      List<ManagedProcess>.unmodifiable(_processes);

  /// Starts and registers a process before waiting for [Process.start] to
  /// complete. The returned object is the only process handle callers need.
  Future<ManagedProcess> start(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
    bool runInShell = false,
    ProcessStartMode mode = ProcessStartMode.normal,
  }) {
    if (_disposed) {
      throw StateError('ProcessSupervisor has been disposed');
    }

    late final ManagedProcess managedProcess;
    managedProcess = ManagedProcess._(
      windows: _isWindows,
      windowsProcessTreeTerminator: _windowsProcessTreeTerminator,
      onCleanup: () => _processes.remove(managedProcess),
    );
    _processes.add(managedProcess);

    return _startRegistered(
      managedProcess,
      executable,
      arguments,
      workingDirectory: workingDirectory,
      environment: environment,
      includeParentEnvironment: includeParentEnvironment,
      runInShell: runInShell,
      mode: mode,
    );
  }

  Future<ManagedProcess> _startRegistered(
    ManagedProcess managedProcess,
    String executable,
    List<String> arguments, {
    required String? workingDirectory,
    required Map<String, String>? environment,
    required bool includeParentEnvironment,
    required bool runInShell,
    required ProcessStartMode mode,
  }) async {
    try {
      final process = await _processStarter(
        executable,
        arguments,
        workingDirectory: workingDirectory,
        environment: environment,
        includeParentEnvironment: includeParentEnvironment,
        runInShell: runInShell,
        mode: mode,
      );
      managedProcess.attach(process);
      return managedProcess;
    } catch (error, stackTrace) {
      managedProcess.failToStart(error, stackTrace);
      rethrow;
    }
  }

  /// Cancels every pending and running process, waiting for each exit code.
  Future<void> cancelAll() async {
    await Future.wait(_processes.map((process) => process.cancel()));
  }

  /// Idempotent app/page shutdown operation.
  Future<void> dispose() async {
    if (_disposed) {
      await cancelAll();
      return;
    }
    _disposed = true;
    await cancelAll();
  }

  /// Alias that reads naturally at app shutdown call sites.
  Future<void> shutdown() => dispose();
}

/// A process whose streams and lifetime are owned by a [ProcessSupervisor].
class ManagedProcess {
  ManagedProcess._({
    required bool windows,
    required WindowsProcessTreeTerminator windowsProcessTreeTerminator,
    required void Function() onCleanup,
  }) : _windows = windows,
       _windowsProcessTreeTerminator = windowsProcessTreeTerminator,
       _onCleanup = onCleanup;

  final bool _windows;
  final WindowsProcessTreeTerminator _windowsProcessTreeTerminator;
  final void Function() _onCleanup;
  final Completer<Process> _processReady = Completer<Process>();
  final Completer<int> _exitCode = Completer<int>();
  final Completer<void> _stdoutDone = Completer<void>();
  final Completer<void> _stderrDone = Completer<void>();
  final StreamController<List<int>> _stdoutController =
      StreamController<List<int>>.broadcast();
  final StreamController<List<int>> _stderrController =
      StreamController<List<int>>.broadcast();

  Process? _process;
  StreamSubscription<List<int>>? _stdoutSubscription;
  StreamSubscription<List<int>>? _stderrSubscription;
  Future<void>? _cancelFuture;
  Future<void>? _cleanupFuture;
  bool _cleanedUp = false;
  bool _cancelling = false;

  /// The operating-system process id after start has completed.
  int get pid => _requireProcess.pid;

  /// Forwarded stdout. The supervisor drains the underlying process stream.
  Stream<List<int>> get stdout => _stdoutController.stream;

  /// Forwarded stderr. The supervisor drains the underlying process stream.
  Stream<List<int>> get stderr => _stderrController.stream;

  /// Stdin for the managed process.
  IOSink get stdin => _requireProcess.stdin;

  /// Completes with the process exit code, including after cancellation.
  Future<int> get exitCode => _exitCode.future;

  /// Whether cancellation or natural completion has finished cleanup.
  bool get isDone => _cleanedUp;

  /// Completes when the process exits and all supervisor cleanup is done.
  Future<int> waitForExit() => exitCode;

  void attach(Process process) {
    if (_process != null) {
      throw StateError('ManagedProcess is already attached');
    }
    _process = process;
    _processReady.complete(process);

    _stdoutSubscription = process.stdout.listen(
      _stdoutController.add,
      onError: _forwardStdoutError,
      onDone: () {
        unawaited(_stdoutController.close());
        _complete(_stdoutDone);
      },
    );
    _stderrSubscription = process.stderr.listen(
      _stderrController.add,
      onError: _forwardStderrError,
      onDone: () {
        unawaited(_stderrController.close());
        _complete(_stderrDone);
      },
    );
    unawaited(_observeExit(process));
  }

  void failToStart(Object error, StackTrace stackTrace) {
    if (!_processReady.isCompleted) {
      _processReady.completeError(error, stackTrace);
      unawaited(
        _processReady.future.then<void>(
          (_) {},
          onError: (Object error, StackTrace stackTrace) {},
        ),
      );
    }
    if (!_exitCode.isCompleted) {
      _exitCode.completeError(error, stackTrace);
      unawaited(
        _exitCode.future.then<void>(
          (_) {},
          onError: (Object error, StackTrace stackTrace) {},
        ),
      );
    }
    unawaited(_cleanup());
  }

  /// Idempotently stops the process and waits for its exit code.
  Future<void> cancel() {
    if (_cleanedUp) return Future<void>.value();
    return _cancelFuture ??= _cancelInternal();
  }

  /// Alias for lifecycle owners that use dispose terminology.
  Future<void> dispose() => cancel();

  Future<void> _cancelInternal() async {
    _cancelling = true;
    Process? process;
    try {
      process = await _processReady.future;
    } catch (_) {
      await _cleanup();
      return;
    }

    try {
      await process.stdin.close();
    } catch (_) {
      // A process can close stdin concurrently while it is being cancelled.
    }

    var treeTerminated = false;
    if (_windows) {
      try {
        treeTerminated = await _windowsProcessTreeTerminator(process.pid);
      } catch (_) {
        // Fall back to the direct process handle if taskkill is unavailable.
      }
    }
    if (!_windows || !treeTerminated) {
      process.kill();
    }

    try {
      final code = await process.exitCode;
      await _cleanup();
      if (!_exitCode.isCompleted) _exitCode.complete(code);
    } catch (error, stackTrace) {
      await _cleanup();
      if (!_exitCode.isCompleted) _exitCode.completeError(error, stackTrace);
    }
  }

  Future<void> _observeExit(Process process) async {
    try {
      final code = await process.exitCode;
      if (_cancelling) {
        await (_cancelFuture ?? Future<void>.value());
      } else {
        await _waitForStreams();
        await _cleanup();
        if (!_exitCode.isCompleted) _exitCode.complete(code);
      }
    } catch (error, stackTrace) {
      if (!_cancelling) await _waitForStreams();
      await _cleanup();
      if (!_exitCode.isCompleted) _exitCode.completeError(error, stackTrace);
    }
  }

  Future<void> _cleanup() {
    return _cleanupFuture ??= _cleanupInternal();
  }

  Future<void> _cleanupInternal() async {
    if (_cleanedUp) return;
    _cleanedUp = true;
    await Future.wait(<Future<void>>[
      _cancelSubscription(_stdoutSubscription),
      _cancelSubscription(_stderrSubscription),
    ]);
    _complete(_stdoutDone);
    _complete(_stderrDone);
    await Future.wait(<Future<void>>[
      _closeController(_stdoutController),
      _closeController(_stderrController),
    ]);
    _onCleanup();
  }

  Process get _requireProcess {
    final process = _process;
    if (process == null) {
      throw StateError('Process has not finished starting');
    }
    return process;
  }

  Future<void> _waitForStreams() =>
      Future.wait<void>(<Future<void>>[_stdoutDone.future, _stderrDone.future]);

  static void _complete(Completer<void> completer) {
    if (!completer.isCompleted) completer.complete();
  }

  void _forwardStdoutError(Object error, StackTrace stackTrace) {
    _stdoutController.addError(error, stackTrace);
  }

  void _forwardStderrError(Object error, StackTrace stackTrace) {
    _stderrController.addError(error, stackTrace);
  }

  static Future<void> _cancelSubscription(
    StreamSubscription<List<int>>? subscription,
  ) async {
    await subscription?.cancel();
  }

  static Future<void> _closeController(
    StreamController<List<int>> controller,
  ) => controller.close();
}

Future<Process> _startProcess(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
  Map<String, String>? environment,
  bool includeParentEnvironment = true,
  bool runInShell = false,
  ProcessStartMode mode = ProcessStartMode.normal,
}) {
  return Process.start(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    environment: environment,
    includeParentEnvironment: includeParentEnvironment,
    runInShell: runInShell,
    mode: mode,
  );
}

Future<bool> _terminateWindowsProcessTree(int pid) async {
  try {
    final result = await Process.run('taskkill', <String>[
      '/PID',
      '$pid',
      '/T',
      '/F',
    ], runInShell: false);
    return result.exitCode == 0;
  } on ProcessException {
    return false;
  }
}
