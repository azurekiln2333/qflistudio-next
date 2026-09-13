import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:re_editor/re_editor.dart';

/// 编辑器选择工具栏宿主：
/// 监听代码控制器选区变化，选中非空时在编辑器顶栏
/// 显示工具条：
/// × 关闭 | 选中文本 | 全选 / 剪切 / 复制 / 粘贴。
///
/// 工具条直接放在编辑器主布局中，而不是插入 root Overlay。Overlay 在
/// TabBarView、路由顶栏和部分平台窗口实现下可能被遮挡。
class SelectionToolbarHost extends StatefulWidget {
  const SelectionToolbarHost({
    super.key,
    required this.controller,
    required this.child,
  });

  final CodeLineEditingController controller;
  final Widget child;

  @override
  State<SelectionToolbarHost> createState() => _SelectionToolbarHostState();
}

class _SelectionToolbarHostState extends State<SelectionToolbarHost> {
  late final ValueNotifier<bool> _suppressed;
  bool _resetScheduled = false;

  @override
  void initState() {
    super.initState();
    _suppressed = ValueNotifier<bool>(false);
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(covariant SelectionToolbarHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _suppressed.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    // 关闭工具栏后，等选区真正收起再允许它在下一次选择时出现。
    if (!_suppressed.value ||
        !widget.controller.selection.isCollapsed ||
        _resetScheduled) {
      return;
    }
    _resetScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resetScheduled = false;
      if (mounted && widget.controller.selection.isCollapsed) {
        _suppressed.value = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // child 作为 AnimatedBuilder 的 child 传入，选区拖动时只重建工具栏，
    // 不重建 CodeEditor，避免拖动过程闪烁和选区跳动。
    return AnimatedBuilder(
      animation: Listenable.merge([widget.controller, _suppressed]),
      child: widget.child,
      builder: (context, child) {
        final showToolbar =
            !widget.controller.selection.isCollapsed &&
            widget.controller.selectedText.isNotEmpty &&
            !_suppressed.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showToolbar) _buildToolbar(),
            Expanded(child: child!),
          ],
        );
      },
    );
  }

  Widget _buildToolbar() {
    return SelectionToolbarBar(controller: widget.controller);
  }
}

/// AppBar 中显示的选区操作栏。
///
/// 当 [pasteOnly] 为 true 时只显示 关闭 / 全选 / 粘贴（长按空行触发）。
class SelectionToolbarBar extends StatelessWidget {
  const SelectionToolbarBar({
    super.key,
    required this.controller,
    this.pasteOnly = false,
    this.onDismiss,
  });

  final CodeLineEditingController controller;

  /// 仅显示粘贴按钮（长按空行时使用）。
  final bool pasteOnly;

  /// 外部关闭回调（用于清理长按触发的状态）。
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // 与 CodeEditor 同一 TapRegion group：点击工具条不算"点击编辑器外部"，
    // 不会触发 unfocus（否则按钮按下瞬间编辑器失焦、工具条随选区销毁，
    // 表现为按钮按不了、点击穿透到后面的编辑器）。
    return TapRegion(
      groupId: CodeEditor,
      child: Material(
      color: scheme.surfaceContainerHigh,
      child: SizedBox(
        height: kToolbarHeight,
        child: Row(
          children: [
            IconButton(
              tooltip: '关闭',
              onPressed: _dismiss,
              icon: const Icon(Icons.close),
            ),
            Expanded(
              child: Text(
                pasteOnly ? '粘贴文本' : '选择文本',
                maxLines: 1,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              tooltip: '全选',
              onPressed: controller.selectAll,
              icon: const Icon(Icons.select_all),
            ),
            if (!pasteOnly)
              IconButton(
                tooltip: '剪切',
                onPressed: controller.cut,
                icon: const Icon(Icons.content_cut_outlined),
              ),
            if (!pasteOnly)
              IconButton(
                tooltip: '复制',
                onPressed: controller.copy,
                icon: const Icon(Icons.content_copy_outlined),
              ),
            IconButton(
              tooltip: '粘贴',
              onPressed: () async {
                // 点击工具条会让编辑器失焦，异步读剪贴板期间选区可能
                // 被平台行为改动：先快照，写入前恢复，确保贴在原位置。
                final selection = controller.selection;
                final data = await Clipboard.getData(Clipboard.kTextPlain);
                final text = data?.text;
                if (text == null || text.isEmpty) return;
                controller.selection = selection;
                controller.replaceSelection(text);
              },
              icon: const Icon(Icons.content_paste_outlined),
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
      ),
    );
  }

  void _dismiss() {
    onDismiss?.call();
    final selection = controller.selection;
    controller.selection = CodeLineSelection.collapsed(
      index: selection.extentIndex,
      offset: selection.extentOffset,
    );
  }
}

/// 把当前文件的选区控制器暴露给 [builder]，选区变化时重建。
///
/// AppBar 的 leading 槽位是定宽的，换成 0 宽的 widget 仍会占位，只有
/// `leading: null` 才能真正归零；这要求在构造 AppBar 时就知道选区状态，
/// 所以由这里统一驱动重建，而不是只替换 AppBar 里的某个子 widget。
class SelectionToolbarScope extends StatelessWidget {
  const SelectionToolbarScope({
    super.key,
    required this.editor,
    required this.controllerBuilder,
    required this.builder,
  });

  final Listenable editor;
  final CodeLineEditingController? Function() controllerBuilder;
  final Widget Function(
    BuildContext context,
    CodeLineEditingController? controller,
  )
  builder;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: editor,
      builder: (context, _) {
        final controller = controllerBuilder();
        if (controller == null) return builder(context, null);
        return ListenableBuilder(
          listenable: controller,
          builder: (context, _) => builder(context, controller),
        );
      },
    );
  }
}
