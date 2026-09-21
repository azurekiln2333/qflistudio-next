import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../i18n/studio_localizations.dart';

/// 本地终端面板：命令响应式 shell（`sh -c` / `cmd /c`），沙箱权限内执行。
/// 移动端系统无编译器，复杂工具（gcc/python 等）需走在线终端。
class TerminalPane extends StatefulWidget {
  const TerminalPane({
    super.key,
    required this.workingDirectory,
    this.onClose,
    this.onCollapseChanged,
    this.onResizeDelta,
  });

  final String workingDirectory;

  /// 用户点击面板上的关闭按钮时回调（编辑器隐藏整个面板）。
  final VoidCallback? onClose;

  /// 折叠状态变化回调（编辑器据此调整外层高度）。
  final ValueChanged<bool>? onCollapseChanged;

  final ValueChanged<double>? onResizeDelta;

  @override
  State<TerminalPane> createState() => TerminalPaneState();
}

class TerminalPaneState extends State<TerminalPane> {
  final _outputLines = <_TermLine>[];
  final _inputController = TextEditingController();
  final _listController = ScrollController();
  final _history = <String>[];
  int _historyIndex = -1;
  bool _running = false;
  Process? _currentProcess;
  bool _collapsed = false;

  static const _maxLines = 500;

  bool get _isWindows => Platform.isWindows;

  @override
  void dispose() {
    _currentProcess?.kill();
    _inputController.dispose();
    _listController.dispose();
    super.dispose();
  }

  Future<void> _run(String command) async {
    final trimmed = command.trim();
    if (trimmed.isEmpty || _running) return;
    final l10n = StudioLocalizations.of(context);
    _history.add(trimmed);
    _historyIndex = _history.length;
    setState(() {
      _outputLines.add(
        _TermLine(text: '$_prompt $trimmed', kind: _LineKind.command),
      );
      _running = true;
    });
    _scrollToBottom();

    try {
      final process = await Process.start(
        _isWindows ? 'cmd' : 'sh',
        _isWindows ? ['/c', trimmed] : ['-c', trimmed],
        workingDirectory: widget.workingDirectory,
        runInShell: false,
      );
      _currentProcess = process;
      final stdoutFuture = process.stdout
          .transform(systemEncoding.decoder)
          .transform(const LineSplitter())
          .toList();
      final stderrFuture = process.stderr
          .transform(systemEncoding.decoder)
          .transform(const LineSplitter())
          .toList();
      final timer = Timer(const Duration(seconds: 30), () {
        process.kill();
      });
      final code = await process.exitCode;
      timer.cancel();
      _currentProcess = null;
      final stdout = await stdoutFuture;
      final stderr = await stderrFuture;
      if (!mounted) return;
      setState(() {
        for (final line in stdout) {
          _append(_TermLine(text: line, kind: _LineKind.stdout));
        }
        for (final line in stderr) {
          _append(_TermLine(text: line, kind: _LineKind.stderr));
        }
        _append(
          _TermLine(
            text: l10n.exitCode(code),
            kind: code == 0 ? _LineKind.info : _LineKind.stderr,
          ),
        );
        _running = false;
      });
      _scrollToBottom();
    } on ProcessException catch (e) {
      if (!mounted) return;
      setState(() {
        _append(
          _TermLine(
            text: l10n.unableToExecute(e.message),
            kind: _LineKind.stderr,
          ),
        );
        _running = false;
      });
      _scrollToBottom();
    }
  }

  void _append(_TermLine line) {
    _outputLines.add(line);
    if (_outputLines.length > _maxLines) {
      _outputLines.removeRange(0, _outputLines.length - _maxLines);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_listController.hasClients) {
        _listController.jumpTo(_listController.position.maxScrollExtent);
      }
    });
  }

  void _submit() {
    final text = _inputController.text;
    _inputController.clear();
    _run(text);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowUp &&
        _history.isNotEmpty &&
        _historyIndex > 0) {
      _historyIndex--;
      _inputController.text = _history[_historyIndex];
      _inputController.selection = TextSelection.collapsed(
        offset: _inputController.text.length,
      );
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown &&
        _historyIndex < _history.length) {
      _historyIndex++;
      _inputController.text = _historyIndex == _history.length
          ? ''
          : _history[_historyIndex];
      _inputController.selection = TextSelection.collapsed(
        offset: _inputController.text.length,
      );
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// 运行按钮：接管一个外部进程，持续回显输出。
  void attachProcess(String title, Process process) {
    // 记下来，退出页面时可以 kill 掉还在跑的进程。
    _currentProcess = process;
    attachOutput(
      title: title,
      stdout: process.stdout
          .transform(systemEncoding.decoder)
          .transform(const LineSplitter()),
      stderr: process.stderr
          .transform(systemEncoding.decoder)
          .transform(const LineSplitter()),
      exitCode: process.exitCode,
    );
  }

  /// 运行按钮：接管任意一对输出流。
  ///
  /// 外部进程和「应用内运行时」（语言 App 自带的解释器/编译器）都走这里，
  /// 终端面板不关心输出到底来自子进程还是当前 isolate。
  void attachOutput({
    required String title,
    required Stream<String> stdout,
    required Stream<String> stderr,
    required Future<int> exitCode,
  }) {
    final l10n = StudioLocalizations.of(context);
    setState(() {
      _append(_TermLine(text: '▶ $title', kind: _LineKind.info));
      _running = true;
    });
    _scrollToBottom();
    unawaited(() async {
      final outDone = stdout.listen((line) {
        if (!mounted) return;
        setState(() => _append(_TermLine(text: line, kind: _LineKind.stdout)));
        _scrollToBottom();
      }).asFuture<void>();
      final errDone = stderr.listen((line) {
        if (!mounted) return;
        setState(() => _append(_TermLine(text: line, kind: _LineKind.stderr)));
        _scrollToBottom();
      }).asFuture<void>();
      await Future.wait([outDone, errDone]);
      final code = await exitCode;
      _currentProcess = null;
      if (!mounted) return;
      setState(() {
        _append(
          _TermLine(
            text: l10n.runEnded(code),
            kind: code == 0 ? _LineKind.info : _LineKind.stderr,
          ),
        );
        _running = false;
      });
      _scrollToBottom();
    }());
  }

  /// 追加调试输出行（Web 预览 console 转发）。
  void appendDebug(String text) {
    setState(() {
      _append(_TermLine(text: text, kind: _LineKind.debug));
    });
    _scrollToBottom();
  }

  /// 追加系统提示行。
  void appendSystem(String text) {
    setState(() {
      _append(_TermLine(text: text, kind: _LineKind.info));
    });
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = StudioLocalizations.of(context);
    if (_collapsed) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() => _collapsed = false);
          widget.onCollapseChanged?.call(false);
        },
        child: Container(
          height: 36,
          color: scheme.surfaceContainerHigh,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(Icons.terminal, size: 16, color: scheme.primary),
              const SizedBox(width: 8),
              Text(
                l10n.terminalCollapsed,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: l10n.close,
                visualDensity: VisualDensity.compact,
                onPressed: widget.onClose,
                icon: const Icon(Icons.close, size: 18),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.onResizeDelta != null)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragUpdate: (details) =>
                widget.onResizeDelta!(-details.delta.dy),
            child: Container(
              height: 8,
              color: scheme.surfaceContainerHighest,
              child: Center(
                child: Container(
                  width: 42,
                  height: 2,
                  decoration: BoxDecoration(
                    color: scheme.onSurfaceVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
        Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          color: scheme.surfaceContainerHigh,
          child: Row(
            children: [
              Icon(Icons.terminal, size: 16, color: scheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.terminalHeader,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (_running)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              IconButton(
                tooltip: l10n.close,
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  setState(() => _collapsed = true);
                  widget.onCollapseChanged?.call(true);
                },
                icon: const Icon(Icons.keyboard_arrow_down, size: 20),
              ),
              IconButton(
                tooltip: l10n.close,
                visualDensity: VisualDensity.compact,
                onPressed: widget.onClose,
                icon: const Icon(Icons.close, size: 18),
              ),
            ],
          ),
        ),
        Divider(height: 1, thickness: 1, color: scheme.outlineVariant),
        Expanded(
          child: ListView.builder(
            controller: _listController,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: _outputLines.length,
            itemBuilder: (context, i) {
              final line = _outputLines[i];
              return Text(
                line.text,
                style: TextStyle(
                  fontFamily: 'Consolas',
                  fontFamilyFallback: const ['Courier New', 'monospace'],
                  fontSize: 12.5,
                  height: 1.45,
                  color: switch (line.kind) {
                    _LineKind.command => scheme.primary,
                    _LineKind.stderr => scheme.error,
                    _LineKind.info => scheme.onSurfaceVariant,
                    _LineKind.debug => scheme.tertiary,
                    _LineKind.stdout => scheme.onSurface,
                  },
                ),
              );
            },
          ),
        ),
        Divider(height: 1, thickness: 1, color: scheme.outlineVariant),
        Focus(
          onKeyEvent: _onKey,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    _prompt,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Consolas',
                      fontSize: 12,
                      color: scheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    style: const TextStyle(
                      fontFamily: 'Consolas',
                      fontSize: 13,
                    ),
                    decoration: InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      hintText: l10n.terminalShellHint('ls / cat main.py)'),
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                ),
                IconButton(
                  tooltip: l10n.execute,
                  onPressed: _running ? null : _submit,
                  icon: const Icon(Icons.play_arrow, size: 20),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String get _prompt => Platform.isWindows
      ? '${p.normalize(widget.workingDirectory)}>'
      : '${p.normalize(widget.workingDirectory)}\$';
}

enum _LineKind { command, stdout, stderr, info, debug }

class _TermLine {
  const _TermLine({required this.text, required this.kind});

  final String text;
  final _LineKind kind;
}
