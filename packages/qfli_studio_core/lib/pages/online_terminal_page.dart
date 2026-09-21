import 'package:flutter/material.dart';

import '../../services/api_client.dart';
import '../../store/auth_store.dart';

/// 在线终端：命令发送到 azurekiln-qfli-server 执行（每用户独立沙箱目录），
/// 由服务器提供 python/gcc/java 等移动端没有的工具链。
class OnlineTerminalPage extends StatefulWidget {
  const OnlineTerminalPage({super.key, required this.auth});

  final AuthStore auth;

  @override
  State<OnlineTerminalPage> createState() => _OnlineTerminalPageState();
}

class _OnlineTerminalPageState extends State<OnlineTerminalPage> {
  final _outputLines = <_TermLine>[];
  final _inputController = TextEditingController();
  final _listController = ScrollController();
  final _history = <String>[];
  bool _running = false;
  String? _cwd;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _printCwd());
  }

  @override
  void dispose() {
    _inputController.dispose();
    _listController.dispose();
    super.dispose();
  }

  Future<void> _printCwd() async {
    try {
      final result = await ApiClient.instance.terminalExec(
        widget.auth.token!,
        'pwd',
      );
      if (!mounted) return;
      setState(() {
        _cwd = result.stdout.trim().isEmpty ? '~' : result.stdout.trim();
        _outputLines.add(
          _TermLine(text: '在线终端（服务器沙箱）· 工作目录：$_cwd', kind: _LineKind.info),
        );
      });
      _scrollToBottom();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _outputLines.add(_TermLine(text: e.message, kind: _LineKind.stderr));
      });
    }
  }

  Future<void> _run(String command) async {
    final trimmed = command.trim();
    if (trimmed.isEmpty || _running) return;
    _history.add(trimmed);
    setState(() {
      _outputLines.add(_TermLine(text: '\$ $trimmed', kind: _LineKind.command));
      _running = true;
    });
    _scrollToBottom();
    try {
      final result = await ApiClient.instance.terminalExec(
        widget.auth.token!,
        trimmed,
      );
      if (!mounted) return;
      setState(() {
        for (final line in result.stdout.split('\n')) {
          if (line.isNotEmpty) {
            _outputLines.add(_TermLine(text: line, kind: _LineKind.stdout));
          }
        }
        for (final line in result.stderr.split('\n')) {
          if (line.isNotEmpty) {
            _outputLines.add(_TermLine(text: line, kind: _LineKind.stderr));
          }
        }
        _outputLines.add(
          _TermLine(
            text: result.exitCode == 0 ? '（退出码 0）' : '（退出码 ${result.exitCode}）',
            kind: result.exitCode == 0 ? _LineKind.info : _LineKind.stderr,
          ),
        );
        _running = false;
      });
      _scrollToBottom();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _outputLines.add(_TermLine(text: e.message, kind: _LineKind.stderr));
        _running = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_listController.hasClients) {
        _listController.jumpTo(_listController.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('在线终端'),
        actions: [
          IconButton(
            tooltip: '清屏',
            onPressed: () => setState(() => _outputLines.clear()),
            icon: const Icon(Icons.restart_alt),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _outputLines.isEmpty
                ? Center(
                    child: Text(
                      '输入命令，在服务器上执行\n适合 python / gcc / java 等移动端没有的工具链',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.6,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _listController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    itemCount: _outputLines.length,
                    itemBuilder: (context, i) {
                      final line = _outputLines[i];
                      return SelectableText(
                        line.text,
                        style: TextStyle(
                          fontFamily: 'Consolas',
                          fontFamilyFallback: const [
                            'Courier New',
                            'monospace',
                          ],
                          fontSize: 12.5,
                          height: 1.45,
                          color: switch (line.kind) {
                            _LineKind.command => scheme.primary,
                            _LineKind.stderr => scheme.error,
                            _LineKind.info => scheme.onSurfaceVariant,
                            _LineKind.stdout => scheme.onSurface,
                          },
                        ),
                      );
                    },
                  ),
          ),
          Divider(height: 1, thickness: 1, color: scheme.outlineVariant),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  Text(
                    '~>',
                    style: TextStyle(
                      fontFamily: 'Consolas',
                      fontSize: 12,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      enabled: !_running,
                      style: const TextStyle(
                        fontFamily: 'Consolas',
                        fontSize: 13,
                      ),
                      decoration: InputDecoration(
                        isCollapsed: true,
                        border: InputBorder.none,
                        hintText: _running ? '执行中…' : '如：python3 main.py',
                        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                      onSubmitted: _run,
                    ),
                  ),
                  IconButton(
                    tooltip: '执行',
                    onPressed: _running
                        ? null
                        : () => _run(_inputController.text),
                    icon: const Icon(Icons.play_arrow, size: 20),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _LineKind { command, stdout, stderr, info }

class _TermLine {
  const _TermLine({required this.text, required this.kind});

  final String text;
  final _LineKind kind;
}
