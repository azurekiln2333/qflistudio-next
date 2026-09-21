import 'package:flutter/material.dart';
import 'package:re_editor/re_editor.dart';

/// 查找/替换面板：由 findBuilder 提供给 CodeEditor，
/// 通过 CodeFindController 驱动编辑器内置搜索。
class EditorFindPanel extends StatelessWidget implements PreferredSizeWidget {
  const EditorFindPanel({
    super.key,
    required this.controller,
    required this.readOnly,
  });

  final CodeFindController controller;
  final bool readOnly;

  /// 未打开查找时占位为 0：编辑器把该高度加进顶部 padding，
  /// 固定高度会让代码区常驻一大块空白。
  @override
  Size get preferredSize =>
      Size.fromHeight(controller.value == null ? 0 : 48);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final active = controller.value != null;
        if (!active) return const SizedBox(height: 0, width: double.infinity);
        final matches = controller.allMatchSelections?.length ?? 0;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          color: scheme.surfaceContainerHigh,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: MediaQuery.sizeOf(context).width - 24),
            child: Row(
            children: [
              SizedBox(
                width: 180,
                child: TextField(
                  controller: controller.findInputController,
                  focusNode: controller.findInputFocusNode,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: '查找内容',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onChanged: (_) {},
                ),
              ),
              IconButton(
                tooltip: '区分大小写',
                onPressed: controller.toggleCaseSensitive,
                icon: const Icon(Icons.text_fields, size: 18),
              ),
              IconButton(
                tooltip: '正则模式',
                onPressed: controller.toggleRegex,
                icon: const Icon(Icons.code, size: 18),
              ),
              Text(
                '$matches 项',
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
              IconButton(
                tooltip: '上一个',
                onPressed: controller.previousMatch,
                icon: const Icon(Icons.keyboard_arrow_up, size: 20),
              ),
              IconButton(
                tooltip: '下一个',
                onPressed: controller.nextMatch,
                icon: const Icon(Icons.keyboard_arrow_down, size: 20),
              ),
              if (!readOnly) ...[
                IconButton(
                  tooltip: '替换当前',
                  onPressed: controller.replaceMatch,
                  icon: const Icon(Icons.find_replace, size: 18),
                ),
                IconButton(
                  tooltip: '全部替换',
                  onPressed: controller.replaceAllMatches,
                  icon: const Icon(Icons.done_all, size: 18),
                ),
              ],
              IconButton(
                tooltip: '关闭',
                onPressed: controller.close,
                icon: const Icon(Icons.close, size: 18),
              ),
            ],
          ),
          ),
          ),
        );
      },
    );
  }
}

/// 带替换输入的双行面板：在查找面板上点展开按钮后显示。
/// 简化实现：替换输入框常驻在第二行（只读模式隐藏整行）。
class EditorFindReplacePanel extends StatelessWidget
    implements PreferredSizeWidget {
  const EditorFindReplacePanel({
    super.key,
    required this.controller,
    required this.readOnly,
  });

  final CodeFindController controller;
  final bool readOnly;

  @override
  Size get preferredSize => Size.fromHeight(
      controller.value == null ? 0 : (readOnly ? 48 : 92));

  @override
  Widget build(BuildContext context) {
    if (readOnly) {
      return EditorFindPanel(controller: controller, readOnly: true);
    }
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (controller.value == null) {
          return const SizedBox(height: 0, width: double.infinity);
        }
        return Column(
          children: [
            EditorFindPanel(controller: controller, readOnly: false),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
              child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  SizedBox(
                    width: 220,
                    child: TextField(
                      controller: controller.replaceInputController,
                      focusNode: controller.replaceInputFocusNode,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: '替换为',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: controller.replaceAllMatches,
                    child: const Text('全部替换'),
                  ),
                ],
              ),
              ),
            ),
          ],
        );
      },
    );
  }
}
