import 'package:flutter/material.dart';
import 'package:re_editor/re_editor.dart';

/// 各语言默认快捷符号（空格分隔，可多字符 token）。
const Map<String, List<String>> kDefaultSymbolSets = {
  'Java': [';', '{', '}', '(', ')', '[', ']', '"', "'", '<', '>', '='],
  'Python': [':', '(', ')', '[', ']', '"', "'", '#', '_', '='],
  'C': [';', '{', '}', '(', ')', '[', ']', '"', "'", '<', '>', '&', '*'],
  'C++': [';', '{', '}', '(', ')', '[', ']', '<', '>', '::', '"', "'"],
  'Web': ['<', '>', '/', '=', '"', ':', ';', '(', ')'],
  'Dart': [';', '{', '}', '(', ')', '[', ']', '"', "'", '<', '>', '=>', '_'],
  'Lua': ['(', ')', '[', ']', '{', '}', '"', "'", '=', '.', ':'],
  'JavaScript': [';', '{', '}', '(', ')', '[', ']', '"', "'", '<', '>', '=', '=>'],
  'TypeScript': [';', '{', '}', '(', ')', '[', ']', '"', "'", '<', '>', '=', '=>'],
  'Kotlin': [';', '{', '}', '(', ')', '[', ']', '"', "'", '=', '->', '?'],
  'Go': [';', '{', '}', '(', ')', '[', ']', '"', ':=', '<', '>', '&'],
  'Rust': [';', '{', '}', '(', ')', '[', ']', '"', '<', '>', '->', '::', '&'],
  'C#': [';', '{', '}', '(', ')', '[', ']', '"', "'", '<', '>', '=', '=>'],
  'PHP': [';', '{', '}', '(', ')', '[', ']', '"', "'", '<', '>', '=', '->'],
  'Ruby': ['(', ')', '[', ']', '{', '}', '"', "'", '#', '=', '|'],
  'JSON': ['{', '}', '[', ']', ':', ',', '"'],
  'HTML': ['<', '>', '/', '=', '"', '<', '>'],
};

/// 文件扩展名 → 语言名（与项目语言标注一致）。
String languageForFileName(String fileName) {
  final ext = fileName.contains('.')
      ? fileName.substring(fileName.lastIndexOf('.')).toLowerCase()
      : '';
  const map = {
    '.py': 'Python',
    '.java': 'Java',
    '.c': 'C', '.h': 'C',
    '.cpp': 'C++', '.hpp': 'C++', '.cc': 'C++',
    '.html': 'Web', '.htm': 'Web',
    '.dart': 'Dart',
    '.lua': 'Lua',
    '.js': 'JavaScript', '.mjs': 'JavaScript',
    '.ts': 'TypeScript', '.tsx': 'TypeScript',
    '.kt': 'Kotlin',
    '.go': 'Go',
    '.rs': 'Rust',
    '.cs': 'C#',
    '.php': 'PHP',
    '.rb': 'Ruby',
    '.json': 'JSON',
  };
  return map[ext] ?? '';
}

/// 快捷符号栏：显示当前文件语言的常用符号，点击插入到光标处；
/// 长按任意符号进入快速编辑（增删改当前语言的符号集）。
class SymbolsBar extends StatelessWidget {
  const SymbolsBar({
    super.key,
    required this.language,
    required this.controller,
    required this.symbols,
    required this.onSymbolsEdited,
  });

  final String language;
  final CodeLineEditingController controller;
  final List<String> symbols;
  final ValueChanged<List<String>> onSymbolsEdited;

  void _insert(String symbol) {
    controller.replaceSelection(symbol);
  }

  Future<void> _editSymbols(BuildContext context) async {
    final edited = [...symbols];
    final addController = TextEditingController();
    final result = await showDialog<List<String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('快捷符号 · $language'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '拖动卡片排序，点 × 删除',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: edited.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text('暂无符号，请在下方添加'),
                        )
                      : ReorderableListView.builder(
                          shrinkWrap: true,
                          buildDefaultDragHandles: false,
                          itemCount: edited.length,
                          onReorder: (oldIndex, newIndex) {
                            setState(() {
                              if (newIndex > oldIndex) newIndex -= 1;
                              final item = edited.removeAt(oldIndex);
                              edited.insert(newIndex, item);
                            });
                          },
                          itemBuilder: (context, i) {
                            return ReorderableDragStartListener(
                              key: ValueKey('$i-${edited[i]}'),
                              index: i,
                              child: ListTile(
                                dense: true,
                                leading: const Icon(Icons.drag_handle),
                                title: Text(
                                  edited[i],
                                  style: const TextStyle(
                                    fontFamily: 'Consolas',
                                    fontSize: 15,
                                  ),
                                ),
                                trailing: IconButton(
                                  tooltip: '删除',
                                  icon: const Icon(Icons.close, size: 18),
                                  onPressed: () =>
                                      setState(() => edited.removeAt(i)),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: addController,
                        decoration: const InputDecoration(
                          isDense: true,
                          labelText: '添加符号（可多字符，如 =>）',
                        ),
                        onSubmitted: (v) {
                          final token = v.trim();
                          if (token.isNotEmpty) {
                            setState(() {
                              edited.add(token);
                              addController.clear();
                            });
                          }
                        },
                      ),
                    ),
                    IconButton(
                      tooltip: '添加',
                      onPressed: () {
                        final token = addController.text.trim();
                        if (token.isNotEmpty) {
                          setState(() {
                            edited.add(token);
                            addController.clear();
                          });
                        }
                      },
                      icon: const Icon(Icons.add_circle),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(edited),
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    if (result != null) {
      final cleaned = result.where((s) => s.isNotEmpty).toList();
      onSymbolsEdited(cleaned);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: scheme.outlineVariant)),
        ),
        child: Row(
          children: [
            Expanded(
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: [
                  for (var i = 0; i < symbols.length; i++) ...[
                    if (i > 0) const SizedBox(width: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: GestureDetector(
                        onLongPress: () => _editSymbols(context),
                        child: Card.filled(
                          margin: EdgeInsets.zero,
                          color: scheme.surfaceContainerHighest
                              .withValues(alpha: 0.6),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => _insert(symbols[i]),
                            onLongPress: () => _editSymbols(context),
                            child: SizedBox(
                              height: 32,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                ),
                                child: Center(
                                  child: Text(
                                    symbols[i],
                                    style: TextStyle(
                                      fontFamily: 'Consolas',
                                      fontSize: 15,
                                      color: scheme.onSurface,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            GestureDetector(
              onLongPress: () => _editSymbols(context),
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(
                  Icons.tune,
                  size: 16,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
