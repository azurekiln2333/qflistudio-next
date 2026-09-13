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
    final controller = TextEditingController(text: symbols.join(' '));
    final result = await showDialog<List<String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('快捷符号 · $language'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '以空格分隔符号，按顺序显示在符号栏：',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: '; { } ( ) [ ]',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(
              controller.text.trim().split(RegExp(r'\s+')),
            ),
            child: const Text('保存'),
          ),
        ],
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
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        children: [
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                for (final symbol in symbols)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: GestureDetector(
                      onLongPress: () => _editSymbols(context),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => _insert(symbol),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            symbol,
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
    );
  }
}
