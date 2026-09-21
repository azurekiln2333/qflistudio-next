import 'package:flutter/material.dart';

import '../i18n/studio_localizations.dart';
import '../services/structured_content_service.dart';

class JsonToolPage extends StatefulWidget {
  const JsonToolPage({
    super.key,
    this.initialText = '{\n  "name": "QFLI"\n}',
    this.onApply,
  });

  final String initialText;
  final ValueChanged<String>? onApply;

  @override
  State<JsonToolPage> createState() => _JsonToolPageState();
}

class _JsonToolPageState extends State<JsonToolPage> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialText);
  late JsonAnalysis _analysis = JsonDocumentService.analyze(_controller.text);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _analyze() => setState(() {
    _analysis = JsonDocumentService.analyze(_controller.text);
  });

  void _format() {
    final result = JsonDocumentService.analyze(_controller.text);
    if (!result.valid) {
      setState(() => _analysis = result);
      return;
    }
    setState(() {
      _controller.text = result.formatted;
      _controller.selection = TextSelection.collapsed(
        offset: _controller.text.length,
      );
      _analysis = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = StudioLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.jsonTools)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          TextField(
            controller: _controller,
            minLines: 12,
            maxLines: 24,
            onChanged: (_) => _analyze(),
            style: const TextStyle(fontFamily: 'monospace'),
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: l10n.jsonSource,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: _format,
                icon: const Icon(Icons.auto_fix_high_outlined),
                label: Text(l10n.jsonFormat),
              ),
              OutlinedButton.icon(
                onPressed: _analyze,
                icon: const Icon(Icons.check_circle_outline),
                label: Text(l10n.jsonValidate),
              ),
              if (widget.onApply != null)
                OutlinedButton.icon(
                  onPressed: () => widget.onApply!(_controller.text),
                  icon: const Icon(Icons.input_outlined),
                  label: Text(l10n.applyToEditor),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              _analysis.valid ? Icons.check_circle : Icons.error_outline,
              color: _analysis.valid
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.error,
            ),
            title: Text(
              _analysis.valid ? l10n.jsonValid : l10n.jsonInvalid,
            ),
            subtitle: _analysis.error == null
                ? Text('${l10n.jsonRootType}: ${JsonDocumentService.nodeLabel(_analysis.value)}')
                : Text(_analysis.error!),
          ),
          if (_analysis.valid) ...[
            const SizedBox(height: 8),
            Text(l10n.jsonStructure, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _JsonTree(value: _analysis.value),
          ],
        ],
      ),
    );
  }
}

class _JsonTree extends StatelessWidget {
  const _JsonTree({required this.value, this.path = r'$'});

  final Object? value;
  final String path;

  @override
  Widget build(BuildContext context) {
    if (value is Map) {
      final map = value! as Map;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final entry in map.entries)
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text('${entry.key}: ${JsonDocumentService.nodeLabel(entry.value)}'),
                  ),
                  if (entry.value is Map || entry.value is List)
                    _JsonTree(value: entry.value, path: '$path.${entry.key}'),
                ],
              ),
            ),
        ],
      );
    }
    if (value is List) {
      final list = value! as List;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < list.length; i++)
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 4),
              child: Text('[$i]: ${JsonDocumentService.nodeLabel(list[i])}'),
            ),
        ],
      );
    }
    return Text('$path: ${JsonDocumentService.nodeLabel(value)}');
  }
}

class MarkdownToolPage extends StatefulWidget {
  const MarkdownToolPage({
    super.key,
    this.initialText = '# QFLINote\n\nEdit and preview this note.',
    this.onApply,
  });

  final String initialText;
  final ValueChanged<String>? onApply;

  @override
  State<MarkdownToolPage> createState() => _MarkdownToolPageState();
}

class _MarkdownToolPageState extends State<MarkdownToolPage> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialText);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = StudioLocalizations.of(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.markdownTools),
          bottom: TabBar(
            tabs: [
              Tab(child: Center(child: Text(l10n.markdownEdit))),
              Tab(child: Center(child: Text(l10n.markdownPreview))),
            ],
          ),
          actions: [
            if (widget.onApply != null)
              IconButton(
                tooltip: l10n.applyToEditor,
                onPressed: () => widget.onApply!(_controller.text),
                icon: const Icon(Icons.input_outlined),
              ),
          ],
        ),
        body: TabBarView(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _controller,
                expands: true,
                maxLines: null,
                style: const TextStyle(fontFamily: 'monospace'),
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: l10n.markdownSource,
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: _markdownWidgets(context, _controller.text),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _markdownWidgets(BuildContext context, String source) {
    final theme = Theme.of(context);
    final widgets = <Widget>[];
    var inCode = false;
    final code = <String>[];
    for (final line in source.split('\n')) {
      if (line.trimLeft().startsWith('```')) {
        if (inCode) {
          widgets.add(SelectableText(code.join('\n'), style: const TextStyle(fontFamily: 'monospace')));
          code.clear();
        }
        inCode = !inCode;
        continue;
      }
      if (inCode) {
        code.add(line);
        continue;
      }
      if (line.startsWith('# ')) {
        widgets.add(Padding(padding: const EdgeInsets.only(top: 12, bottom: 8), child: Text(line.substring(2), style: theme.textTheme.headlineSmall)));
      } else if (line.startsWith('## ')) {
        widgets.add(Padding(padding: const EdgeInsets.only(top: 10, bottom: 6), child: Text(line.substring(3), style: theme.textTheme.titleLarge)));
      } else if (line.trimLeft().startsWith('- ')) {
        widgets.add(Text('• ${line.trimLeft().substring(2)}'));
      } else if (line.trim().isEmpty) {
        widgets.add(const SizedBox(height: 8));
      } else {
        widgets.add(Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(line)));
      }
    }
    if (code.isNotEmpty) widgets.add(SelectableText(code.join('\n'), style: const TextStyle(fontFamily: 'monospace')));
    return widgets;
  }
}

class SqlToolPage extends StatefulWidget {
  const SqlToolPage({super.key, this.projectPath, this.initialText = 'SELECT 1 AS value;'});

  final String? projectPath;
  final String initialText;

  @override
  State<SqlToolPage> createState() => _SqlToolPageState();
}

class _SqlToolPageState extends State<SqlToolPage> {
  late final TextEditingController _controller = TextEditingController(text: widget.initialText);
  SqlExecutionResult? _result;
  bool _running = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _execute() async {
    setState(() => _running = true);
    final result = await SqlQueryService.execute(source: _controller.text, projectPath: widget.projectPath);
    if (!mounted) return;
    setState(() {
      _running = false;
      _result = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = StudioLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.sqlTools)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          TextField(
            controller: _controller,
            minLines: 8,
            maxLines: 16,
            style: const TextStyle(fontFamily: 'monospace'),
            decoration: InputDecoration(border: const OutlineInputBorder(), labelText: l10n.sqlSource),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _running ? null : _execute,
            icon: _running ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.play_arrow),
            label: Text(l10n.executeQuery),
          ),
          if (_result case final result?) ...[
            const SizedBox(height: 16),
            SelectableText(result.error ?? result.output, style: const TextStyle(fontFamily: 'monospace')),
          ],
        ],
      ),
    );
  }
}
