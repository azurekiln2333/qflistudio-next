import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../i18n/studio_localizations.dart';
import '../services/studio_profile.dart';
import '../services/app_paths.dart';
import '../store/project_store.dart';
import 'content_tools_pages.dart';

/// 主页的功能页。
class FunctionsTab extends StatelessWidget {
  const FunctionsTab({
    super.key,
    required this.onOpenTerminal,
    this.onOpenContentTool,
  });

  final VoidCallback onOpenTerminal;
  final VoidCallback? onOpenContentTool;

  @override
  Widget build(BuildContext context) {
    final l10n = StudioLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.functions)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _QuickToolTile(
            icon: Icons.terminal,
            title: l10n.terminal,
            subtitle: l10n.terminalSubtitle,
            onTap: onOpenTerminal,
          ),
          if (onOpenContentTool != null) ...[
            const SizedBox(height: 8),
            _QuickToolTile(
              icon: switch (StudioProfile.current?.productKey) {
                StudioProductCatalog.jsonKey => Icons.data_object,
                StudioProductCatalog.noteKey => Icons.article_outlined,
                StudioProductCatalog.sqlabKey => Icons.storage_outlined,
                _ => Icons.build_outlined,
              },
              title: switch (StudioProfile.current?.productKey) {
                StudioProductCatalog.jsonKey => l10n.jsonTools,
                StudioProductCatalog.noteKey => l10n.markdownTools,
                StudioProductCatalog.sqlabKey => l10n.sqlTools,
                _ => l10n.functions,
              },
              subtitle: switch (StudioProfile.current?.productKey) {
                StudioProductCatalog.jsonKey => l10n.jsonStructure,
                StudioProductCatalog.noteKey => l10n.markdownPreview,
                StudioProductCatalog.sqlabKey => l10n.executeQuery,
                _ => l10n.functions,
              },
              onTap: onOpenContentTool!,
            ),
          ],
        ],
      ),
    );
  }
}

class ContentToolsPage extends StatelessWidget {
  const ContentToolsPage({super.key, required this.store});

  final ProjectStore store;

  @override
  Widget build(BuildContext context) {
    final profile = StudioProfile.current;
    return switch (profile?.productKey) {
      StudioProductCatalog.jsonKey => const JsonToolPage(),
      StudioProductCatalog.noteKey => const MarkdownToolPage(),
      StudioProductCatalog.sqlabKey => SqlToolPage(projectPath: _projectPath),
      _ => Scaffold(
        appBar: AppBar(title: Text(StudioLocalizations.of(context).functions)),
        body: const SizedBox.shrink(),
      ),
    };
  }

  String? get _projectPath {
    for (final project in store.projects) {
      if (!project.isCloud) return project.path;
    }
    return null;
  }
}

@Deprecated('Use FunctionsTab')
typedef QuickToolsTab = FunctionsTab;

class _QuickToolTile extends StatelessWidget {
  const _QuickToolTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

/// 独立的全屏本地终端页，与编辑器内的终端面板分开维护。
class LocalTerminalPage extends StatefulWidget {
  const LocalTerminalPage({super.key, required this.store});

  final ProjectStore store;

  @override
  State<LocalTerminalPage> createState() => _LocalTerminalPageState();
}

class _LocalTerminalPageState extends State<LocalTerminalPage> {
  late final Future<String?> _workingDirectory = _resolveWorkingDirectory();
  final _sessions = <_LocalTerminalSession>[];
  var _selectedSession = 0;
  var _nextSessionId = 1;
  final _inputFocusNode = FocusNode();

  _LocalTerminalSession get _session => _sessions[_selectedSession];

  bool get _isWindows => Platform.isWindows;

  @override
  void initState() {
    super.initState();
    _sessions.add(_LocalTerminalSession(id: _nextSessionId++));
  }

  @override
  void dispose() {
    _inputFocusNode.dispose();
    for (final session in _sessions) {
      session.dispose();
    }
    super.dispose();
  }

  Future<String?> _resolveWorkingDirectory() async {
    for (final project in widget.store.projects) {
      if (!project.isCloud && Directory(project.path).existsSync()) {
        return project.path;
      }
    }
    final root = await AppPaths.projectsRoot(create: true);
    return root ?? AppPaths.writableDirectory();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = StudioLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.terminal),
        actions: [
          IconButton(
            tooltip: l10n.clear,
            onPressed: _clearSession,
            icon: const Icon(Icons.clear_all),
          ),
          IconButton(
            tooltip: l10n.newTerminal,
            onPressed: _newSession,
            icon: const Icon(Icons.add),
          ),
          IconButton(
            tooltip: StudioLocalizations.of(context).close,
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.close),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<String?>(
        future: _workingDirectory,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return Center(
              child: Semantics(
                label: l10n.loading,
                child: const CircularProgressIndicator(),
              ),
            );
          }
          final path = snapshot.data;
          if (path == null || path.isEmpty) {
            return Center(child: Text(l10n.noWorkingDirectory));
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSessionBar(context),
              Expanded(child: _buildOutput(path)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSessionBar(BuildContext context) {
    final l10n = StudioLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        children: [
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _sessions.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final session = _sessions[index];
                return InputChip(
                  label: Text('${l10n.terminal} ${session.id}'),
                  selected: index == _selectedSession,
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) => _selectSession(index),
                  onDeleted: _sessions.length == 1
                      ? null
                      : () => _closeSession(session.id),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: l10n.newTerminal,
            visualDensity: VisualDensity.compact,
            onPressed: _newSession,
            icon: const Icon(Icons.add),
          ),
          IconButton(
            tooltip: l10n.copyTerminal,
            visualDensity: VisualDensity.compact,
            onPressed: _copySession,
            icon: const Icon(Icons.copy_outlined),
          ),
        ],
      ),
    );
  }

  Widget _buildOutput(String path) {
    final scheme = Theme.of(context).colorScheme;
    final session = _session;
    return Container(
      color: scheme.surfaceContainerLowest,
      child: ListView.builder(
        controller: session.listController,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        itemCount: session.outputLines.length + 1,
        itemBuilder: (context, index) {
          if (index == session.outputLines.length) {
            return _buildPromptLine(path);
          }
          final line = session.outputLines[index];
          return Text(
            line.text,
            style: TextStyle(
              fontFamily: 'Consolas',
              fontFamilyFallback: const ['Courier New', 'monospace'],
              fontSize: 13,
              height: 1.45,
              color: switch (line.kind) {
                _LocalLineKind.command => scheme.primary,
                _LocalLineKind.stderr => scheme.error,
                _LocalLineKind.info => scheme.onSurfaceVariant,
                _LocalLineKind.stdout => scheme.onSurface,
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildPromptLine(String path) {
    final scheme = Theme.of(context).colorScheme;
    final session = _session;
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 8),
      child: Focus(
        onKeyEvent: _onKey,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                _prompt(path),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Consolas',
                  fontFamilyFallback: const ['Courier New', 'monospace'],
                  fontSize: 13,
                  color: scheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: session.inputController,
                focusNode: _inputFocusNode,
                autofocus: true,
                enabled: !session.running,
                maxLines: 1,
                style: TextStyle(
                  fontFamily: 'Consolas',
                  fontFamilyFallback: const ['Courier New', 'monospace'],
                  fontSize: 13,
                  color: scheme.onSurface,
                ),
                decoration: const InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _submit(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _prompt(String path) =>
      _isWindows ? '${p.normalize(path)}>' : '${p.normalize(path)}\$';

  void _newSession() {
    setState(() {
      _sessions.add(_LocalTerminalSession(id: _nextSessionId++));
      _selectedSession = _sessions.length - 1;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _inputFocusNode.requestFocus();
    });
  }

  void _selectSession(int index) {
    if (index == _selectedSession || index < 0 || index >= _sessions.length) {
      return;
    }
    setState(() => _selectedSession = index);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _inputFocusNode.requestFocus();
        _scrollToBottom(_session);
      }
    });
  }

  void _closeSession(int id) {
    if (_sessions.length == 1) {
      return;
    }
    final oldIndex = _sessions.indexWhere((session) => session.id == id);
    if (oldIndex < 0) return;
    final session = _sessions.removeAt(oldIndex);
    session.dispose();
    setState(() {
      if (oldIndex < _selectedSession) {
        _selectedSession--;
      } else if (_selectedSession >= _sessions.length) {
        _selectedSession = _sessions.length - 1;
      }
    });
    _inputFocusNode.requestFocus();
  }

  void _clearSession() {
    setState(() => _session.outputLines.clear());
  }

  Future<void> _copySession() async {
    await Clipboard.setData(
      ClipboardData(
        text: _session.outputLines.map((line) => line.text).join('\n'),
      ),
    );
  }

  void _submit() {
    final command = _session.inputController.text;
    _session.inputController.clear();
    unawaited(_run(command));
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final session = _session;
    if (event.logicalKey == LogicalKeyboardKey.arrowUp &&
        session.historyIndex > 0) {
      session.historyIndex--;
      session.inputController.text = session.history[session.historyIndex];
      session.inputController.selection = TextSelection.collapsed(
        offset: session.inputController.text.length,
      );
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown &&
        session.historyIndex < session.history.length) {
      session.historyIndex++;
      session.inputController.text =
          session.historyIndex == session.history.length
          ? ''
          : session.history[session.historyIndex];
      session.inputController.selection = TextSelection.collapsed(
        offset: session.inputController.text.length,
      );
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _run(String command) async {
    final trimmed = command.trim();
    final session = _session;
    if (trimmed.isEmpty || session.running || session.disposed) return;
    final path = await _workingDirectory;
    if (path == null || path.isEmpty || !mounted || session.disposed) return;
    session.history.add(trimmed);
    session.historyIndex = session.history.length;
    setState(() {
      _append(
        _LocalTermLine(
          text: '${_prompt(path)} $trimmed',
          kind: _LocalLineKind.command,
        ),
        session,
      );
      session.running = true;
    });
    _scrollToBottom(session);

    try {
      final process = await Process.start(
        _isWindows ? 'cmd' : 'sh',
        _isWindows ? ['/c', trimmed] : ['-c', trimmed],
        workingDirectory: path,
        runInShell: false,
      );
      session.currentProcess = process;
      final stdoutDone = process.stdout
          .transform(systemEncoding.decoder)
          .transform(const LineSplitter())
          .listen((line) => _appendProcessLine(session, line, false));
      final stderrDone = process.stderr
          .transform(systemEncoding.decoder)
          .transform(const LineSplitter())
          .listen((line) => _appendProcessLine(session, line, true));
      final timer = Timer(const Duration(seconds: 30), process.kill);
      final code = await process.exitCode;
      timer.cancel();
      await Future.wait([
        stdoutDone.asFuture<void>(),
        stderrDone.asFuture<void>(),
      ]);
      session.currentProcess = null;
      if (!mounted || session.disposed) return;
      setState(() {
        _append(
          _LocalTermLine(
            text: StudioLocalizations.of(context).runEnded(code),
            kind: code == 0 ? _LocalLineKind.info : _LocalLineKind.stderr,
          ),
          session,
        );
        session.running = false;
      });
      _scrollToBottom(session);
    } on ProcessException catch (error) {
      if (!mounted || session.disposed) return;
      setState(() {
        _append(
          _LocalTermLine(
            text: StudioLocalizations.of(
              context,
            ).unableToExecute(error.message),
            kind: _LocalLineKind.stderr,
          ),
          session,
        );
        session.running = false;
      });
      _scrollToBottom(session);
    }
  }

  void _appendProcessLine(
    _LocalTerminalSession session,
    String line,
    bool isError,
  ) {
    if (!mounted || session.disposed) return;
    setState(() {
      _append(
        _LocalTermLine(
          text: line,
          kind: isError ? _LocalLineKind.stderr : _LocalLineKind.stdout,
        ),
        session,
      );
    });
    _scrollToBottom(session);
  }

  void _append(_LocalTermLine line, _LocalTerminalSession session) {
    session.outputLines.add(line);
    if (session.outputLines.length > 1000) {
      session.outputLines.removeRange(0, session.outputLines.length - 1000);
    }
  }

  void _scrollToBottom(_LocalTerminalSession session) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!session.disposed && session.listController.hasClients) {
        session.listController.jumpTo(
          session.listController.position.maxScrollExtent,
        );
      }
    });
  }
}

enum _LocalLineKind { command, stdout, stderr, info }

class _LocalTermLine {
  const _LocalTermLine({required this.text, required this.kind});

  final String text;
  final _LocalLineKind kind;
}

class _LocalTerminalSession {
  _LocalTerminalSession({required this.id});

  final int id;
  final outputLines = <_LocalTermLine>[];
  final inputController = TextEditingController();
  final listController = ScrollController();
  final history = <String>[];
  var historyIndex = -1;
  var running = false;
  var disposed = false;
  Process? currentProcess;

  void dispose() {
    disposed = true;
    currentProcess?.kill();
    inputController.dispose();
    listController.dispose();
  }
}
