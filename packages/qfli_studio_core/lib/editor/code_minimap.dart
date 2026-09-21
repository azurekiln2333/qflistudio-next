import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:re_editor/re_editor.dart';

/// 缩略导航只采样最多 600 行；移动光标时复用内容快照。
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
  static const _maxSamples = 600;
  CodeLines? _snapshot;
  List<({int line, int indent, int length})> _rows = [];
  int _lineCount = 1;
  int _focusedLine = 0;

  @override
  void initState() {
    super.initState();
    _updateSnapshot();
    widget.controller.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(covariant CodeMinimap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onChanged);
      widget.controller.addListener(_onChanged);
      _snapshot = null;
      _updateSnapshot();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _updateSnapshot() {
    final lines = widget.controller.codeLines;
    _focusedLine = widget.controller.selection.extentIndex;
    if (identical(lines, _snapshot)) return;
    _snapshot = lines;
    _lineCount = math.max(1, lines.length);
    final stride = math.max(1, (_lineCount / _maxSamples).ceil());
    final rows = <({int line, int indent, int length})>[];
    for (var index = 0; index < lines.length; index += stride) {
      final text = lines[index].text;
      var indent = 0;
      // 只查看有限的前导空白，压缩成一行的 HTML/CSS 不会复制整行字符串。
      while (indent < text.length &&
          indent < 120 &&
          (text.codeUnitAt(indent) == 32 || text.codeUnitAt(indent) == 9)) {
        indent++;
      }
      if (indent == text.length) continue;
      rows.add((
        line: index,
        indent: indent.clamp(0, 80),
        length: (text.length - indent).clamp(1, 120),
      ));
    }
    _rows = rows;
  }

  void _onChanged() {
    if (identical(_snapshot, widget.controller.codeLines) &&
        _focusedLine == widget.controller.selection.extentIndex) {
      return;
    }
    setState(_updateSnapshot);
  }

  void _jumpTo(double dy, double height) {
    if (height <= 0) return;
    final line = (dy / height * _lineCount).floor().clamp(0, _lineCount - 1);
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
    return SizedBox(
      width: widget.width,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final drawHeight = math.min(constraints.maxHeight, _lineCount * 2.5);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (event) => _jumpTo(event.localPosition.dy, drawHeight),
            onVerticalDragUpdate: (event) =>
                _jumpTo(event.localPosition.dy, drawHeight),
            child: RepaintBoundary(
              child: ColoredBox(
                color: scheme.surfaceContainerLow,
                child: CustomPaint(
                  painter: _MinimapPainter(
                    rows: _rows,
                    lineCount: _lineCount,
                    focusedLine: _focusedLine,
                    height: drawHeight,
                    lineColor: scheme.outlineVariant,
                    focusedColor: scheme.primary,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MinimapPainter extends CustomPainter {
  _MinimapPainter({
    required this.rows,
    required this.lineCount,
    required this.focusedLine,
    required this.height,
    required this.lineColor,
    required this.focusedColor,
  });

  final List<({int line, int indent, int length})> rows;
  final int lineCount;
  final int focusedLine;
  final double height;
  final Color lineColor;
  final Color focusedColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 8 || height <= 0) return;
    final width = size.width - 8;
    final step = height / lineCount;
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = (step * 0.6).clamp(1.0, 2.0)
      ..color = lineColor;
    for (final row in rows) {
      final x = 4 + row.indent / 200 * width;
      final end = math.min(size.width - 4, x + row.length / 160 * width);
      final y = row.line * step + step / 2;
      canvas.drawLine(Offset(x, y), Offset(end, y), paint);
    }
    paint
      ..color = focusedColor.withValues(alpha: 0.25)
      ..strokeWidth = 2;
    final y = focusedLine * step + step / 2;
    canvas.drawLine(Offset(2, y), Offset(size.width - 2, y), paint);
  }

  @override
  bool shouldRepaint(covariant _MinimapPainter old) =>
      old.rows != rows ||
      old.focusedLine != focusedLine ||
      old.height != height ||
      old.lineColor != lineColor ||
      old.focusedColor != focusedColor;
}
