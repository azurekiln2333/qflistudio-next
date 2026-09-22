import 'dart:async';

import 'package:flutter/foundation.dart';

import '../shell/ansi.dart';
import '../shell/shell_backend.dart';

/// Visual category of a committed output line.
enum TerminalLineKind { output, command, system, error }

/// One rendered row of the terminal buffer.
@immutable
class TerminalLine {
  const TerminalLine(this.segments, this.kind);

  final List<TerminalSegment> segments;
  final TerminalLineKind kind;

  String get text => segments.map((segment) => segment.text).join();
}

/// A single terminal: owns a [ShellBackend], the scrollback buffer and the
/// command history.
class TerminalSession extends ChangeNotifier {
  TerminalSession({
    required this.id,
    required this.title,
    required this.backend,
  }) {
    _subscription = backend.output.listen(_onChunk);
    backend.addListener(_scheduleNotify);
  }

  /// Maximum retained scrollback rows.
  static const int maxLines = 4000;

  final String id;
  String title;
  final ShellBackend backend;

  /// Invoked when the user runs `exit`. Wired up by the manager.
  void Function(TerminalSession session)? onExitRequested;

  final List<TerminalLine> _lines = <TerminalLine>[];
  final List<TerminalSegment> _pending = <TerminalSegment>[];
  final List<String> _history = <String>[];
  final AnsiDecoder _decoder = AnsiDecoder();

  /// Set by a `\r` whose meaning is not yet known, because it depends on the
  /// character that follows — which may only arrive in the next chunk.
  ///
  /// `\r\n` (CRLF, what a PTY or a network protocol sends) is just a newline,
  /// so the line has to be committed. A bare `\r` followed by more text
  /// restarts the row, which is how progress bars redraw in place.
  ///
  /// Treating every `\r` as a row restart — the obvious reading — silently
  /// throws away the line, because the `\r` in `\r\n` clears the row that was
  /// just appended to it.
  bool _rowReset = false;

  StreamSubscription<ShellChunk>? _subscription;
  OutputKind _chunkKind = OutputKind.stdout;
  int _historyCursor = 0;
  bool _disposed = false;
  bool _notifyScheduled = false;

  List<TerminalLine> get lines => List<TerminalLine>.unmodifiable(_lines);

  /// The row currently being assembled; rendered after [lines] while a command
  /// streams output without a trailing newline.
  List<TerminalSegment> get pendingSegments =>
      List<TerminalSegment>.unmodifiable(_pending);

  List<String> get history => List<String>.unmodifiable(_history);

  bool get busy => backend.busy;

  /// True while an interactive tool (netcat, telnet, an SSH shell, the SFTP
  /// prompt) owns the input line.
  bool get attached => backend.attached;

  /// Label of that tool, shown instead of the shell prompt.
  String? get attachLabel => backend.attachLabel;

  String get cwd => backend.cwd;

  /// [cwd] with the home directory shown as `~`, for the prompt and the window
  /// subtitle.
  String get displayCwd => backend.displayCwd;

  String get prompt => backend.prompt;

  String get shellLabel => backend.shellLabel;

  // ------------------------------------------------------------- public API

  /// Echoes the prompt and runs [raw].
  ///
  /// While a network tool holds the connection (netcat, telnet, an SSH shell,
  /// the SFTP prompt) the line is forwarded to it instead of being executed,
  /// and the prompt shown is the tool's own label.
  Future<void> submit(String raw) async {
    final attached = backend.attached;
    final echo = backend.attachEcho;
    final secret = backend.attachSecret;
    final label = backend.attachLabel ?? '';

    final List<TerminalSegment> echoLine;
    if (!attached) {
      echoLine = <TerminalSegment>[
        TerminalSegment('${backend.prompt} ', emphasis: TerminalEmphasis.prompt),
        TerminalSegment(raw, emphasis: TerminalEmphasis.command),
      ];
    } else if (echo) {
      // The tool echoes the line itself, so it is already on screen.
      echoLine = const <TerminalSegment>[];
    } else if (secret) {
      // Nothing echoes a secret, so the prompt's label is the only record that
      // anything was typed. The value itself is never written anywhere.
      echoLine = <TerminalSegment>[
        TerminalSegment(label, emphasis: TerminalEmphasis.prompt),
      ];
    } else {
      // The far end echoes it — an `ssh` shell's remote PTY. Printing a local
      // copy would show every command twice, which is the giveaway that this is
      // not a real terminal.
      echoLine = const <TerminalSegment>[];
    }

    if (echoLine.isNotEmpty) {
      _lines.add(TerminalLine(echoLine, TerminalLineKind.command));
    }
    _pending.clear();
    _trim();

    final command = raw.trim();
    if (command.isEmpty) {
      _scheduleNotify();
      return;
    }

    if (attached) {
      if (command == '.exit' || command == '.quit') {
        _scheduleNotify();
        backend.detach();
        return;
      }
      // Secrets must not be recallable with `↑`; everything else should be, so
      // an `ssh` shell still gets a usable local history.
      if (!secret) {
        _history.add(command);
        _historyCursor = _history.length;
      }
      _scheduleNotify();
      await backend.sendLine(raw);
      return;
    }

    _history.add(command);
    _historyCursor = _history.length;

    if (command == 'exit' || command == 'quit') {
      _scheduleNotify();
      onExitRequested?.call(this);
      return;
    }

    if (command == 'history') {
      if (_history.isEmpty) {
        appendNotice('（历史记录为空）');
      } else {
        for (var i = 0; i < _history.length; i++) {
          _lines.add(
            TerminalLine(
              <TerminalSegment>[
                TerminalSegment(
                  '${(i + 1).toString().padLeft(4)}  ${_history[i]}',
                ),
              ],
              TerminalLineKind.output,
            ),
          );
        }
        _trim();
      }
      _scheduleNotify();
      return;
    }

    _scheduleNotify();
    await backend.execute(command);
  }

  /// Appends an app-generated notice (not shell output).
  void appendNotice(String text, {bool error = false}) {
    _lines.add(
      TerminalLine(
        <TerminalSegment>[
          TerminalSegment(
            text,
            emphasis: error ? TerminalEmphasis.error : TerminalEmphasis.system,
          ),
        ],
        error ? TerminalLineKind.error : TerminalLineKind.system,
      ),
    );
    _trim();
    _scheduleNotify();
  }

  void clear() {
    _lines.clear();
    _pending.clear();
    _rowReset = false;
    _decoder.reset();
    _scheduleNotify();
  }

  Future<void> interrupt() => backend.interrupt();

  /// Moves back through the command history. Returns null when unavailable.
  String? historyPrevious() {
    if (_history.isEmpty) return null;
    if (_historyCursor > 0) _historyCursor--;
    return _history[_historyCursor];
  }

  /// Moves forward through the command history; returns an empty string once
  /// past the newest entry.
  String? historyNext() {
    if (_history.isEmpty) return null;
    if (_historyCursor < _history.length - 1) {
      _historyCursor++;
      return _history[_historyCursor];
    }
    _historyCursor = _history.length;
    return '';
  }

  void resetHistoryCursor() {
    _historyCursor = _history.length;
  }

  // ---------------------------------------------------------------- internal

  void _onChunk(ShellChunk chunk) {
    if (chunk.kind == OutputKind.control) {
      if (chunk.text == 'clear') clear();
      return;
    }

    _chunkKind = chunk.kind;
    for (final segment in _decoder.decode(chunk.text)) {
      _consume(segment);
    }
    _scheduleNotify();
  }

  void _consume(TerminalSegment segment) {
    final text = segment.text;
    var start = 0;

    for (var i = 0; i < text.length; i++) {
      final code = text.codeUnitAt(i);

      if (code == 0x0A) {
        _appendToPending(text.substring(start, i), segment);
        _commitPending();
        start = i + 1;
        // A `\n` directly after a `\r` is the tail of a CRLF pair, not a row
        // restart — the line must survive. See [_rowReset].
        _rowReset = false;
      } else if (code == 0x0D) {
        _appendToPending(text.substring(start, i), segment);
        start = i + 1;
        // What this `\r` meant depends on the *next* character, which may not
        // have arrived yet. `\r\n` is just a newline; a bare `\r` followed by
        // more text restarts the row (progress bars).
        _rowReset = true;
      } else if (_rowReset) {
        _pending.clear();
        _rowReset = false;
      }
    }

    if (start < text.length) {
      _appendToPending(text.substring(start), segment);
    }
  }

  void _appendToPending(String text, TerminalSegment source) {
    if (text.isEmpty) return;
    final emphasis = _emphasisFor(source.style);

    if (_pending.isNotEmpty) {
      final last = _pending.last;
      if (last.style == source.style && last.emphasis == emphasis) {
        _pending[_pending.length - 1] = TerminalSegment(
          '${last.text}$text',
          style: source.style,
          emphasis: emphasis,
        );
        return;
      }
    }

    _pending.add(
      TerminalSegment(text, style: source.style, emphasis: emphasis),
    );
  }

  TerminalEmphasis _emphasisFor(TerminalStyle style) {
    if (style.foreground != null || style.background != null) {
      return TerminalEmphasis.normal;
    }
    switch (_chunkKind) {
      case OutputKind.stderr:
        return TerminalEmphasis.error;
      case OutputKind.system:
      case OutputKind.control:
        return TerminalEmphasis.system;
      case OutputKind.stdout:
        return TerminalEmphasis.normal;
    }
  }

  void _commitPending() {
    if (_pending.isEmpty) {
      _lines.add(const TerminalLine(<TerminalSegment>[], TerminalLineKind.output));
    } else {
      _lines.add(
        TerminalLine(
          List<TerminalSegment>.unmodifiable(_pending),
          _kindFor(_pending),
        ),
      );
    }
    _pending.clear();
    _trim();
  }

  TerminalLineKind _kindFor(List<TerminalSegment> segments) {
    switch (segments.first.emphasis) {
      case TerminalEmphasis.error:
        return TerminalLineKind.error;
      case TerminalEmphasis.system:
        return TerminalLineKind.system;
      case TerminalEmphasis.prompt:
      case TerminalEmphasis.command:
        return TerminalLineKind.command;
      case TerminalEmphasis.normal:
        return TerminalLineKind.output;
    }
  }

  void _trim() {
    final overflow = _lines.length - maxLines;
    if (overflow > 0) _lines.removeRange(0, overflow);
  }

  void _scheduleNotify() {
    if (_notifyScheduled || _disposed) return;
    _notifyScheduled = true;
    Timer.run(() {
      _notifyScheduled = false;
      if (!_disposed) notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    _subscription = null;
    backend.removeListener(_scheduleNotify);
    unawaited(backend.shutdown());
    super.dispose();
  }
}
