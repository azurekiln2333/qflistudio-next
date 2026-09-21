import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:re_editor/re_editor.dart';

import '../editor/highlight_import.dart';
import '../editor/highlight_themes.dart';
import '../store/settings_store.dart';
import '../widgets/settings_section.dart';

class HighlightSettingsPage extends StatefulWidget {
  const HighlightSettingsPage({super.key, required this.settings});

  final SettingsStore settings;

  @override
  State<HighlightSettingsPage> createState() => _HighlightSettingsPageState();
}

class _HighlightSettingsPageState extends State<HighlightSettingsPage> {
  static const _example = '''<!-- 给每一个灵感上色 -->
<style>
  .hello { color: #2196f3; padding: 16px; }
</style>
<div class="hello">QFLIStudio+</div>
<script>
  const message = "Hello, world!";
  console.log(message);
</script>''';
  final _preview = CodeLineEditingController.fromText(_example);
  bool _importing = false;

  SettingsStore get settings => widget.settings;

  @override
  void dispose() {
    _preview.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('代码高亮')),
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) {
          final codeTheme = HighlightThemes.themeFor(
            context,
            'preview.html',
            null,
            settings: settings,
          );
          final palette = HighlightThemes.paletteFor(context, settings);
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 840),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  SettingsSection(
                    title: '显示',
                    children: [
                      SwitchListTile(
                        secondary: const Icon(Icons.code_rounded),
                        title: const Text('语法高亮'),
                        subtitle: const Text('按语言区分关键字、字符串与注释'),
                        value: settings.syntaxHighlighting,
                        onChanged: settings.setSyntaxHighlighting,
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                        child: DropdownButtonFormField<String>(
                          key: ValueKey(settings.highlightTheme),
                          initialValue: settings.highlightTheme,
                          decoration: const InputDecoration(labelText: '代码配色'),
                          isExpanded: true,
                          items: [
                            const DropdownMenuItem(
                              value: 'system',
                              child: Text('跟随应用外观'),
                            ),
                            const DropdownMenuItem(
                              value: 'light',
                              child: Text('Visual Studio 浅色'),
                            ),
                            const DropdownMenuItem(
                              value: 'dark',
                              child: Text('GitHub 深色'),
                            ),
                            if (settings.importedHighlightTheme != null)
                              DropdownMenuItem(
                                value: 'custom',
                                child: Text(
                                  settings.importedHighlightTheme!.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              settings.setHighlightTheme(value);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  SettingsSection(
                    title: '实时预览 · HTML / CSS / JavaScript',
                    children: [
                      SizedBox(
                        height: 224,
                        child: RepaintBoundary(
                          child: CodeEditor(
                            controller: _preview,
                            readOnly: true,
                            autofocus: false,
                            style: CodeEditorStyle(
                              fontSize: 13,
                              fontFamily: 'monospace',
                              backgroundColor:
                                  codeTheme?.theme['root']?.backgroundColor ??
                                  scheme.surfaceContainerLow,
                              textColor:
                                  codeTheme?.theme['root']?.color ??
                                  scheme.onSurface,
                              codeTheme: codeTheme,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SettingsSection(
                    title: '主题与自定义颜色',
                    children: [
                      ListTile(
                        leading: const Icon(Icons.file_download_outlined),
                        title: const Text('导入配色主题'),
                        subtitle: const Text(
                          'TextMate .tmTheme / VS Code JSON、JSONC',
                        ),
                        trailing: _importing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.chevron_right),
                        onTap: _importing
                            ? null
                            : () => _import(grammar: false),
                      ),
                      if (settings.importedHighlightTheme case final imported?)
                        ListTile(
                          leading: const Icon(Icons.palette_outlined),
                          title: Text(imported.name),
                          subtitle: Text('${imported.rules.length} 条配色规则'),
                          trailing: IconButton(
                            tooltip: '移除导入的主题',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: settings.removeHighlightTheme,
                          ),
                        ),
                      const Divider(height: 1, indent: 20, endIndent: 20),
                      for (final entry in HighlightThemes.tokenLabels.entries)
                        ListTile(
                          title: Text(entry.value),
                          subtitle: Text(
                            settings.highlightColors[entry.key] ?? '使用主题颜色',
                          ),
                          leading: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color:
                                  palette[entry.key]?.color ?? scheme.onSurface,
                              shape: BoxShape.circle,
                              border: Border.all(color: scheme.outlineVariant),
                            ),
                          ),
                          trailing: const Icon(Icons.edit_outlined, size: 20),
                          onTap: () => _editColor(entry.key, entry.value),
                        ),
                      if (settings.highlightColors.isNotEmpty)
                        Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: TextButton.icon(
                              onPressed: settings.resetHighlightColors,
                              icon: const Icon(Icons.restore),
                              label: const Text('恢复主题默认颜色'),
                            ),
                          ),
                        ),
                    ],
                  ),
                  SettingsSection(
                    title: '自定义语法',
                    children: [
                      SwitchListTile(
                        secondary: const Icon(Icons.extension_outlined),
                        title: const Text('TextMate 兼容语法'),
                        subtitle: const Text('匹配文件后缀时优先使用导入的语法'),
                        value: settings.textMateEnabled,
                        onChanged: settings.setTextMateEnabled,
                      ),
                      ListTile(
                        leading: const Icon(Icons.note_add_outlined),
                        title: const Text('导入语法文件'),
                        subtitle: const Text('.tmLanguage.json，支持指定文件后缀'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _importing ? null : () => _import(grammar: true),
                      ),
                      for (final grammar in settings.customGrammars)
                        ListTile(
                          title: Text(grammar.name),
                          subtitle: Text(grammar.fileTypes.join(' · ')),
                          leading: const Icon(Icons.data_object),
                          trailing: IconButton(
                            tooltip: '移除 ${grammar.name}',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => settings.removeTextMateGrammar(
                              grammar.scopeName,
                            ),
                          ),
                        ),
                      const ExpansionTile(
                        title: Text('导入兼容范围'),
                        childrenPadding: EdgeInsets.fromLTRB(20, 0, 20, 20),
                        children: [
                          Text(
                            '配色支持普通 scope、逗号分隔 scope 与字体样式；不解析父作用域选择器和语义高亮。'
                            '\n\n语法支持 match、begin/end、patterns、repository 的 #include 和捕获组 0。'
                            '递归、外部语法引用、复杂捕获及 Oniguruma 扩展暂不支持，导入时会提示原因。',
                          ),
                        ],
                      ),
                    ],
                  ),
                  Text(
                    '大于 256 KB 或单行超过 2048 个字符时自动使用纯文本显示。'
                    '高亮计算超时也会回退，文件内容和编辑功能保持可用。',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _editColor(String token, String label) async {
    final value = await showDialog<String>(
      context: context,
      builder: (_) => _ColorDialog(
        label: label,
        value: settings.highlightColors[token] ?? '',
      ),
    );
    if (value != null) await settings.setHighlightColor(token, value);
  }

  Future<void> _import({required bool grammar}) async {
    final method = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.folder_open_outlined),
              title: const Text('从文件导入'),
              onTap: () => Navigator.pop(context, 'file'),
            ),
            ListTile(
              leading: const Icon(Icons.content_paste),
              title: const Text('粘贴配置内容'),
              onTap: () => Navigator.pop(context, 'paste'),
            ),
          ],
        ),
      ),
    );
    if (method == null || !mounted) return;
    setState(() => _importing = true);
    try {
      var source = '';
      var name = '自定义配色';
      if (method == 'file') {
        try {
          final file = await openFile(
            acceptedTypeGroups: [
              XTypeGroup(
                label: grammar ? 'TextMate 语法' : '配色主题',
                extensions: grammar
                    ? ['json', 'jsonc']
                    : ['json', 'jsonc', 'tmTheme'],
              ),
            ],
          );
          if (file == null) return;
          if (await file.length() > maxHighlightImportSize) {
            throw const FormatException('配置文件不能超过 512 KB');
          }
          source = await file.readAsString();
          name = file.name;
        } on MissingPluginException {
          // 鸿蒙未提供 file_selector 时仍可通过粘贴导入。
          if (mounted) _message('当前平台请使用粘贴导入');
        }
      }
      if (!mounted) return;
      final input = await showDialog<({String source, String? fileTypes})>(
        context: context,
        builder: (_) => _ImportDialog(grammar: grammar, source: source),
      );
      if (input == null) return;
      final importedName = grammar
          ? await settings.importTextMateGrammar(
              input.source,
              fileTypes: input.fileTypes,
            )
          : await settings.importHighlightTheme(input.source, name: name);
      if (mounted) _message('已导入 $importedName');
    } on FormatException catch (error) {
      if (mounted) _message(error.message);
    } catch (error) {
      if (mounted) _message('导入失败：$error');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

class _ImportDialog extends StatefulWidget {
  const _ImportDialog({required this.grammar, required this.source});
  final bool grammar;
  final String source;
  @override
  State<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<_ImportDialog> {
  late final _source = TextEditingController(text: widget.source);
  final _fileTypes = TextEditingController();
  @override
  void dispose() {
    _source.dispose();
    _fileTypes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.grammar ? '导入 TextMate 语法' : '导入配色主题'),
    content: SizedBox(
      width: 520,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _source,
              minLines: 6,
              maxLines: 10,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: widget.grammar ? '语法 JSON' : '主题 JSON / XML',
                alignLabelWithHint: true,
              ),
            ),
            if (widget.grammar) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _fileTypes,
                decoration: const InputDecoration(
                  labelText: '文件后缀（可选）',
                  hintText: 'lua, luau',
                  helperText: '留空时使用语法文件中的 fileTypes',
                ),
              ),
            ],
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, (
          source: _source.text,
          fileTypes: _fileTypes.text.trim().isEmpty
              ? null
              : _fileTypes.text.trim(),
        )),
        child: const Text('导入'),
      ),
    ],
  );
}

class _ColorDialog extends StatefulWidget {
  const _ColorDialog({required this.label, required this.value});
  final String label;
  final String value;
  @override
  State<_ColorDialog> createState() => _ColorDialogState();
}

class _ColorDialogState extends State<_ColorDialog> {
  late final _controller = TextEditingController(text: widget.value);
  final _form = GlobalKey<FormState>();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('${widget.label}颜色'),
    content: Form(
      key: _form,
      child: TextFormField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: '十六进制颜色',
          hintText: '#2196F3',
        ),
        validator: (value) {
          try {
            parseHighlightColor(value ?? '');
            return null;
          } on FormatException {
            return '请输入有效颜色，例如 #2196F3';
          }
        },
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, ''),
        child: const Text('使用主题颜色'),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.pop(context, _controller.text.trim());
          }
        },
        child: const Text('保存'),
      ),
    ],
  );
}
