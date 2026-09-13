import 'package:flutter/widgets.dart';
import 'package:re_editor/re_editor.dart';

/// re_editor 的 _deleteBackward 把「首行为空行且光标在 (0,0)」当作文档起点
/// 直接忽略，导致该空行删不掉（中间/末尾空行均正常）。这里替换编辑器的
/// Delete 快捷键动作：该场景把首行并入下一行（与常规编辑器行为一致），
/// 其余场景原样委托给控制器。
class EditorDeleteAction extends Action<CodeShortcutDeleteIntent> {
  EditorDeleteAction(this.controller);

  final CodeLineEditingController controller;

  @override
  Object? invoke(Intent intent) {
    final forward = (intent as CodeShortcutDeleteIntent).forward;
    if (!forward &&
        controller.selection.isCollapsed &&
        controller.selection.baseIndex == 0 &&
        controller.selection.baseOffset == 0 &&
        controller.lineCount > 1 &&
        controller.codeLines[0].text.isEmpty) {
      controller.replaceSelection(
        '',
        const CodeLineSelection(
          baseIndex: 0,
          baseOffset: 0,
          extentIndex: 1,
          extentOffset: 0,
        ),
      );
      return null;
    }
    if (forward) {
      controller.deleteForward();
    } else {
      controller.deleteBackward();
    }
    return null;
  }
}

/// 传给 CodeEditor.shortcutOverrideActions。
Map<Type, Action<Intent>> editorShortcutOverrides(
  CodeLineEditingController controller,
) => {CodeShortcutDeleteIntent: EditorDeleteAction(controller)};
