import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../i18n/studio_localizations.dart';
import '../services/app_paths.dart';
import '../store/project_store.dart';
import '../terminal/models/terminal_session.dart';
import '../terminal/state/terminal_manager.dart';
import '../terminal/widgets/shortcut_bar.dart';
import '../terminal/widgets/terminal_output.dart';
import '../terminal/widgets/terminal_tabs.dart';

/// Full-screen terminal workspace migrated from Terminax.
class TerminaxTerminalPage extends StatefulWidget {
  const TerminaxTerminalPage({super.key, required this.store});

  final ProjectStore store;

  @override
  State<TerminaxTerminalPage> createState() => _TerminaxTerminalPageState();
}

class _TerminaxTerminalPageState extends State<TerminaxTerminalPage> {
  late final Future<String?> _workingDirectory = _resolveWorkingDirectory();
  final TerminalManager _manager = TerminalManager();
  final PageController _pages = PageController();
  final ValueNotifier<double> _pagePosition = ValueNotifier<double>(0);
  final Map<String, _SessionEditor> _editors = <String, _SessionEditor>{};
  bool _ctrl = false;
  bool _alt = false;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _manager.addListener(_handleManagerChanged);
    _pages.addListener(_handlePageChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final path = await _workingDirectory;
      if (mounted && path != null && _manager.sessionCount == 0) {
        _createSession(path);
      }
    });
  }

  @override
  void dispose() {
    _manager.removeListener(_handleManagerChanged);
    _pages.removeListener(_handlePageChanged);
    _pages.dispose();
    _pagePosition.dispose();
    for (final editor in _editors.values) {
      editor.dispose();
    }
    _editors.clear();
    _manager.dispose();
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

  void _handlePageChanged() {
    if (_pages.hasClients) _pagePosition.value = _pages.page ?? 0;
  }

  void _handleManagerChanged() {
    if (!mounted) return;
    final live = _manager.sessions.map((session) => session.id).toSet();
    _editors.removeWhere((id, editor) {
      if (live.contains(id)) return false;
      editor.dispose();
      return true;
    });
    if (_manager.sessionCount == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final path = await _workingDirectory;
        if (mounted && path != null && _manager.sessionCount == 0) {
          _createSession(path);
        }
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pages.hasClients || _manager.activeIndex < 0) return;
      _pages.jumpToPage(_manager.activeIndex);
    });
    setState(() {});
  }

  _SessionEditor _editorFor(String id) =>
      _editors.putIfAbsent(id, _SessionEditor.new);

  void _createSession(String path) {
    final session = _manager.create(workingDirectory: path);
    _editorFor(session.id);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _editorFor(session.id).focusNode.requestFocus();
    });
  }

  Future<void> _newSession() async {
    final path = await _workingDirectory;
    if (mounted && path != null) _createSession(path);
  }

  Future<void> _submit(TerminalSession session, String raw) async {
    final editor = _editorFor(session.id);
    if (session.busy) return;
    editor.controller.clear();
    setState(() {
      _ctrl = false;
      _alt = false;
    });
    await session.submit(raw);
    if (mounted) editor.focusNode.requestFocus();
  }

  void _setInput(_SessionEditor editor, String text) {
    editor.controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _insertText(_SessionEditor editor, String text) {
    final value = editor.controller.value;
    final start = value.selection.start < 0
        ? value.text.length
        : value.selection.start;
    final end = value.selection.end < 0 ? value.text.length : value.selection.end;
    final result =
        '${value.text.substring(0, start)}$text${value.text.substring(end)}';
    editor.controller.value = TextEditingValue(
      text: result,
      selection: TextSelection.collapsed(offset: start + text.length),
    );
  }

  void _moveCursor(_SessionEditor editor, int delta) {
    final selection = editor.controller.selection;
    final offset = (selection.extentOffset + delta)
        .clamp(0, editor.controller.text.length);
    editor.controller.selection = TextSelection.collapsed(offset: offset);
  }

  void _handleShortcut(ShortcutKey key) {
    final session = _manager.active;
    if (session == null) return;
    final editor = _editorFor(session.id);
    switch (key) {
      case ShortcutKey.escape:
        _setInput(editor, '');
      case ShortcutKey.tab:
        _insertText(editor, '\t');
      case ShortcutKey.arrowLeft:
        _moveCursor(editor, -1);
      case ShortcutKey.arrowRight:
        _moveCursor(editor, 1);
      case ShortcutKey.arrowUp:
        final value = session.historyPrevious();
        if (value != null) _setInput(editor, value);
      case ShortcutKey.arrowDown:
        final value = session.historyNext();
        if (value != null) _setInput(editor, value);
      case ShortcutKey.home:
        editor.controller.selection = const TextSelection.collapsed(offset: 0);
      case ShortcutKey.end:
        editor.controller.selection = TextSelection.collapsed(
          offset: editor.controller.text.length,
        );
      case ShortcutKey.pageUp:
        editor.scroll.pageUp();
      case ShortcutKey.pageDown:
        editor.scroll.pageDown();
      case ShortcutKey.enter:
        unawaited(_submit(session, editor.controller.text));
      case ShortcutKey.backspace:
        _backspace(editor);
      case ShortcutKey.delete:
        _deleteForward(editor);
      case ShortcutKey.clear:
        session.clear();
      case ShortcutKey.interrupt:
        unawaited(session.interrupt());
      case ShortcutKey.paste:
        unawaited(_paste(editor));
      case ShortcutKey.copyAll:
        unawaited(_copyAll(session));
      case ShortcutKey.selectAll:
        editor.controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: editor.controller.text.length,
        );
      case ShortcutKey.toggleKeyboard:
        editor.focusNode.unfocus();
    }
    if (mounted) setState(() {});
  }

  void _handleCtrlLetter(String letter) {
    final session = _manager.active;
    if (session == null) return;
    final editor = _editorFor(session.id);
    switch (letter) {
      case 'A':
        editor.controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: editor.controller.text.length,
        );
      case 'E':
        editor.controller.selection = TextSelection.collapsed(
          offset: editor.controller.text.length,
        );
      case 'U':
        _setInput(editor, '');
      case 'K':
        final offset = editor.controller.selection.extentOffset;
        _setInput(editor, editor.controller.text.substring(0, offset));
      case 'W':
        final text = editor.controller.text;
        final offset = editor.controller.selection.extentOffset;
        final start = text.substring(0, offset).trimRight().lastIndexOf(' ') + 1;
        editor.controller.value = TextEditingValue(
          text: '${text.substring(0, start)}${text.substring(offset)}',
          selection: TextSelection.collapsed(offset: start),
        );
      case 'H':
        _backspace(editor);
      case 'C':
      case 'Z':
        unawaited(session.interrupt());
      case 'D':
        if (editor.controller.text.isEmpty) _manager.close(session.id);
      case 'L':
        session.clear();
    }
    setState(() {
      _ctrl = false;
      _alt = false;
    });
  }

  void _backspace(_SessionEditor editor) {
    final selection = editor.controller.selection;
    if (selection.isValid && selection.start != selection.end) {
      _insertText(editor, '');
      return;
    }
    final offset = selection.extentOffset.clamp(0, editor.controller.text.length);
    if (offset == 0) return;
    editor.controller.value = TextEditingValue(
      text:
          '${editor.controller.text.substring(0, offset - 1)}${editor.controller.text.substring(offset)}',
      selection: TextSelection.collapsed(offset: offset - 1),
    );
  }

  void _deleteForward(_SessionEditor editor) {
    final offset = editor.controller.selection.extentOffset;
    if (offset >= editor.controller.text.length) return;
    editor.controller.value = TextEditingValue(
      text:
          '${editor.controller.text.substring(0, offset)}${editor.controller.text.substring(offset + 1)}',
      selection: TextSelection.collapsed(offset: offset),
    );
  }

  Future<void> _paste(_SessionEditor editor) async {
    final value = await Clipboard.getData(Clipboard.kTextPlain);
    if (value?.text != null) _insertText(editor, value!.text!);
  }

  Future<void> _copyAll(TerminalSession session) async {
    await Clipboard.setData(
      ClipboardData(text: session.lines.map((line) => line.text).join('\n')),
    );
  }

  KeyEventResult _handleHardwareKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final session = _manager.active;
    if (session == null) return KeyEventResult.ignored;
    final editor = _editorFor(session.id);
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _handleShortcut(ShortcutKey.arrowUp);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _handleShortcut(ShortcutKey.arrowDown);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _handleShortcut(ShortcutKey.escape);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.tab) {
      _insertText(editor, '\t');
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
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
            onPressed: () => _manager.active?.clear(),
            icon: const Icon(Icons.clear_all),
          ),
          IconButton(
            tooltip: l10n.newTerminal,
            onPressed: _newSession,
            icon: const Icon(Icons.add),
          ),
          IconButton(
            tooltip: l10n.close,
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      body: FutureBuilder<String?>(
        future: _workingDirectory,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.data == null || snapshot.data!.isEmpty) {
            return Center(child: Text(l10n.noWorkingDirectory));
          }
          if (_manager.sessionCount == 0) return const SizedBox.shrink();
          return Column(
            children: [
              TerminalTabStrip(
                sessions: _manager.sessions,
                activeId: _manager.active?.id,
                pagePosition: _pagePosition,
                onSelect: _manager.select,
                onClose: _manager.close,
                onCloseOthers: _manager.closeOthers,
                onCloseAll: _manager.closeAll,
                onRename: _renameSession,
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pages,
                  itemCount: _manager.sessionCount,
                  onPageChanged: _manager.selectIndex,
                  itemBuilder: (context, index) {
                    final session = _manager.sessions[index];
                    final editor = _editorFor(session.id);
                    return TerminalOutputView(
                      key: ValueKey(session.id),
                      session: session,
                      scrollController: editor.scroll,
                      fontSize: 13,
                      wrap: true,
                      inputController: editor.controller,
                      focusNode: editor.focusNode,
                      onSubmitted: (raw) => _submit(session, raw),
                      onInterrupt: () => session.interrupt(),
                      onKeyEvent: _handleHardwareKey,
                    );
                  },
                ),
              ),
              ShortcutBar(
                ctrlActive: _ctrl,
                altActive: _alt,
                expanded: _expanded,
                busy: _manager.active?.busy ?? false,
                attached: _manager.active?.attached ?? false,
                onCtrlChanged: (value) => setState(() => _ctrl = value),
                onAltChanged: (value) => setState(() => _alt = value),
                onExpandedChanged: (value) => setState(() => _expanded = value),
                onText: (value) {
                  final session = _manager.active;
                  if (session != null) _insertText(_editorFor(session.id), value);
                },
                onKey: _handleShortcut,
                onCtrlLetter: _handleCtrlLetter,
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _renameSession(TerminalSession session) async {
    final controller = TextEditingController(text: session.title);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(StudioLocalizations.of(context).terminal),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(StudioLocalizations.of(context).cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(StudioLocalizations.of(context).create),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null) _manager.rename(session.id, result);
  }
}

class _SessionEditor {
  final TextEditingController controller = TextEditingController();
  final FocusNode focusNode = FocusNode(debugLabel: 'qfli-terminal-input');
  final TerminalScrollController scroll = TerminalScrollController();

  void dispose() {
    controller.dispose();
    focusNode.dispose();
    scroll.dispose();
  }
}
