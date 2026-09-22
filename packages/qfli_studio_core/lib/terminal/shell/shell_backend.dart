import 'dart:async';

import 'package:flutter/foundation.dart';

/// Where a chunk of shell output came from.
enum OutputKind {
  stdout,
  stderr,
  system,

  /// Control message consumed by the UI (currently only `clear`).
  control,
}

/// A piece of raw shell output.
@immutable
class ShellChunk {
  const ShellChunk(this.text, this.kind);

  final String text;
  final OutputKind kind;
}

/// Common contract for every shell implementation: a real OS process on
/// desktop / mobile, or the bundled virtual filesystem used for practice and as
/// a fallback on platforms without `dart:io`.
///
/// Implementations are [ChangeNotifier]s so the UI can react to `busy` and
/// `cwd` transitions without polling.
abstract class ShellBackend extends ChangeNotifier {
  /// Human readable name shown in the UI, e.g. `PowerShell`.
  String get shellLabel;

  /// Current working directory.
  String get cwd;

  /// [cwd] rendered for display, with a leading home directory shown as `~` the
  /// way a shell prompt does it.
  ///
  /// Only the prompt and the window subtitle use this. `pwd` still prints the
  /// real absolute path, matching what a real shell does.
  String get displayCwd;

  /// Prompt rendered in front of the input line.
  String get prompt;

  /// True while an external command is executing.
  bool get busy;

  /// Whether [interrupt] can actually stop a running command.
  bool get canInterrupt;

  /// Raw output stream. Chunks may split escape sequences mid-way.
  Stream<ShellChunk> get output;

  /// Runs [command]. Built-in commands are handled by the backend itself.
  Future<void> execute(String command);

  /// Best-effort cancellation of the running command (Ctrl+C).
  Future<void> interrupt();

  /// Releases resources. Named `shutdown` to avoid clashing with
  /// [ChangeNotifier.dispose].
  Future<void> shutdown();

  /// Non-null while an interactive tool (netcat, telnet, an SSH shell, the SFTP
  /// prompt) owns the input line. The session then routes submitted lines to
  /// [sendLine] instead of executing them as commands.
  String? get attachLabel;

  /// True while [attachLabel] is set.
  bool get attached;

  /// Whether the attached tool echoes what it receives. When false the
  /// terminal must not echo either, or remote-echoed input would appear twice.
  bool get attachEcho;

  /// Whether the attached tool wants a prompt drawn on the input row.
  ///
  /// False when the far end prints its own prompt as ordinary output, so ours
  /// would appear as a second one ahead of the cursor.
  bool get attachPrompt;

  /// Whether the attached tool is asking for a secret. The terminal masks the
  /// input and keeps it out of the scrollback and the history.
  ///
  /// Distinct from `!attachEcho`: an `ssh` shell does not echo locally (the
  /// remote does) but is not secret.
  bool get attachSecret;

  /// Feeds one line of input to the attached tool.
  Future<void> sendLine(String line);

  /// Leaves interactive mode, tearing the connection down.
  void detach();
}

/// Shared plumbing: output stream, built-in commands, busy bookkeeping and the
/// [NetHost] implementation every backend hands to the network toolkit.
abstract class BaseShellBackend extends ChangeNotifier implements ShellBackend {
  // Synchronous delivery matters: output must land in the session buffer before
  // `execute` completes, otherwise a following command echo could be inserted
  // in the middle of this command's output.
  final StreamController<ShellChunk> _controller =
      StreamController<ShellChunk>.broadcast(sync: true);

  bool _busy = false;
  bool _disposed = false;
  String _cwd = '';

  void Function()? _cancelHandler;

  @override
  Stream<ShellChunk> get output => _controller.stream;

  @override
  String get cwd => _cwd;

  /// Directory that `~` stands for, or null when this backend has no home.
  ///
  /// Deliberately not part of [ShellBackend]: only the backend itself needs it,
  /// to build the prompt and to expand `~` in paths.
  @protected
  String? get homeDirectory => null;

  @override
  String get displayCwd => compactPath(cwd);

  /// [path] with a leading [homeDirectory] replaced by `~`.
  ///
  /// Shared by every backend so the prompt looks the same everywhere, and
  /// public so tests can pin down the boundary cases (a sibling directory whose
  /// name merely starts with the home path must not be compacted).
  String compactPath(String path) {
    final home = homeDirectory;
    if (home == null || home.isEmpty) return path;
    if (path == home) return '~';
    // Match either separator so a Windows home (`C:\Users\me`) compacts even
    // when the session is holding a forward-slash path.
    for (final separator in const <String>['/', r'\']) {
      if (path.startsWith('$home$separator')) {
        return '~${path.substring(home.length)}';
      }
    }
    return path;
  }

  @override
  bool get busy => _busy;

  @override
  bool get canInterrupt => true;

  @override
  String? get attachLabel => null;

  @override
  bool get attached => false;

  @override
  bool get attachEcho => true;

  @override
  bool get attachPrompt => true;

  @override
  bool get attachSecret => false;

  @protected
  set cwd(String value) {
    if (_cwd == value) return;
    _cwd = value;
    _notify();
  }

  @protected
  set busyState(bool value) {
    if (_busy == value) return;
    _busy = value;
    _notify();
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @protected
  void emit(String text, [OutputKind kind = OutputKind.stdout]) {
    if (_disposed || text.isEmpty) return;
    _controller.add(ShellChunk(text, kind));
  }

  @protected
  void emitLine(String text, [OutputKind kind = OutputKind.stdout]) =>
      emit('$text\n', kind);

  // --------------------------------------------------------------- execution

  @override
  Future<void> execute(String command) async {
    if (_busy || attached) return;
    final trimmed = command.trim();
    if (trimmed.isEmpty) return;
    if (await handleBuiltin(trimmed)) return;

    busyState = true;
    try {
      await runExternal(trimmed);
    } catch (error) {
      emitLine('shell: $error', OutputKind.stderr);
    } finally {
      busyState = false;
    }
  }

  /// Commands shared by every backend. Returns true when fully handled.
  @protected
  Future<bool> handleBuiltin(String command) async {
    switch (command) {
      case 'clear':
      case 'cls':
        emit('clear', OutputKind.control);
        return true;
      case 'pwd':
        emitLine(cwd);
        return true;
      case 'help':
        emitLine(helpText);
        return true;
    }

    if (command == 'cd' || command.startsWith('cd ')) {
      final target = command == 'cd' ? '~' : command.substring(3).trim();
      return changeDirectory(target);
    }

    return false;
  }

  /// Multi-line help text shown by the `help` built-in.
  @protected
  String get helpText;

  /// Resolves [target] and updates [cwd]. Returns true when handled, even if
  /// the directory does not exist (the error is reported via [emit]).
  @protected
  Future<bool> changeDirectory(String target);

  /// Executes a non-built-in command.
  @protected
  Future<void> runExternal(String command);

  @override
  Future<void> sendLine(String line) async {
    // QFLI local sessions do not attach network tools.
  }

  @override
  void detach() {
  }

  @override
  Future<void> interrupt() async {
    final cancel = _cancelHandler;
    if (cancel != null) {
      emitLine('^C', OutputKind.system);
      cancel();
      return;
    }
    await onInterrupt();
  }

  /// Ctrl+C handling for backends that own a child process directly. Called
  /// only when no cancellable task is registered.
  @protected
  Future<void> onInterrupt() async {}

  // --------------------------------------------------------------- lifecycle

  @override
  Future<void> shutdown() async {
    _disposed = true;
    _cancelHandler = null;
    await _controller.close();
    dispose();
  }
}
