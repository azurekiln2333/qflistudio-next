import 'package:flutter/material.dart';
import 'package:re_editor/re_editor.dart';

/// 编辑器右侧的代码鸟瞰条（minimap）：
/// 每行绘制一条与缩进/长度成比例的细条，点击/拖动跳转到对应行。
/// 面向大文件做了降采样，保证流畅。
class CodeMinimap extends StatefulWidget {
  const CodeMinimap({
    super.key,
    required this.controller,
    required this.scrollController,
    this.width = 72,
  });

  final CodeLineEditingController controller;
  final CodeScrollController scrollController;
  final double width;

  @override
  State<CodeMinimap> createState() => _CodeMinimapState();
}

class _CodeMinimapState extends State<CodeMinimap> {
  static const double _rowHeight = 2.5;
  static const int _maxRows = 1000;

  int _focusedLine = -1;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(covariant CodeMinimap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    final selection = widget.controller.selection;
    if (_focusedLine != selection.extentIndex) {
      setState(() => _focusedLine = selection.extentIndex);
    }
  }

  void _jumpTo(int line) {
    widget.controller.selection = CodeLineSelection.collapsed(
      index: line,
      offset: 0,
    );
    widget.scrollController.makeVisible(
      CodeLinePosition(index: line, offset: 0),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (details) => _jumpTo(_lineAt(details.localPosition.dy)),
      onVerticalDragUpdate: (details) =>
          _jumpTo(_lineAt(details.localPosition.dy)),
      child: Container(
        width: widget.width,
        color: scheme.surfaceContainerLow,
        child: CustomPaint(
          painter: _MinimapPainter(
            controller: widget.controller,
            focusedLine: _focusedLine,
            rowHeight: _rowHeight,
            maxRows: _maxRows,
            lineColor: scheme.outlineVariant,
            focusedColor: scheme.primary,
            indentColor: scheme.outline.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }

  int _lineAt(double dy) {
    final lineCount = widget.controller.codeLines.length;
    if (lineCount == 0) return 0;
    final step = _effectiveRowHeight(lineCount);
    final index = (dy / step).floor().clamp(0, lineCount - 1);
    return index;
  }

  double _effectiveRowHeight(int lineCount) =>
      lineCount > _maxRows ? _rowHeight * _maxRows / lineCount : _rowHeight;
}

class _MinimapPainter extends CustomPainter {
  _MinimapPainter({
    required this.controller,
    required this.focusedLine,
    required this.rowHeight,
    required this.maxRows,
    required this.lineColor,
    required this.focusedColor,
    required this.indentColor,
  });

  final CodeLineEditingController controller;
  final int focusedLine;
  final double rowHeight;
  final int maxRows;
  final Color lineColor;
  final Color focusedColor;
  final Color indentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final lines = controller.codeLines;
    final count = lines.length;
    if (count == 0) return;
    final step = count > maxRows ? rowHeight * maxRows / count : rowHeight;
    final scale = count > maxRows ? count / maxRows : 1;
    final maxWidth = size.width - 8;
    var maxLen = 1;
    for (var i = 0; i < count; i++) {
      final len = lines[i].text.length;
      if (len > maxLen) maxLen = len;
    }

    final paint = Paint()..strokeCap = StrokeCap.round;
    for (var i = 0; i < count; i++) {
      // 降采样时每桶只画代表行。
      if (scale > 1 && (i % scale.ceil()) != 0) continue;
      final text = lines[i].text;
      final trimmed = text.trimLeft();
      if (trimmed.isEmpty) continue;
      final indentRatio = (text.length - trimmed.length) / text.length;
      final widthRatio = (trimmed.length / maxLen).clamp(0.02, 1.0);
      final y = i * step + step / 2;
      final x = 4.0 + indentRatio * maxWidth * 0.5;
      final w = (widthRatio * maxWidth * 0.6).clamp(2.0, maxWidth - (x - 4));
      final isFocused = i == focusedLine;
      paint.color = isFocused ? focusedColor : lineColor;
      paint.strokeWidth = (step * 0.6).clamp(1.0, 2.2);
      canvas.drawLine(Offset(x, y), Offset(x + w, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MinimapPainter oldDelegate) =>
      oldDelegate.focusedLine != focusedLine ||
      oldDelegate.controller != controller;
}
