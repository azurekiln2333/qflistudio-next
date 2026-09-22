import 'package:flutter/material.dart';

import '../models/terminal_session.dart';
import '../shell/ansi.dart';
import '../theme/app_theme.dart';

/// Owns the scroll position of one terminal view so the shortcut bar can drive
/// page up / down / home / end on the active terminal.
class TerminalScrollController extends ChangeNotifier {
  TerminalScrollController() {
    scroll.addListener(_handleScroll);
  }

  final ScrollController scroll = ScrollController();

  bool _stick = true;

  /// True while the view should follow new output.
  bool get stickToBottom => _stick;

  static const double _slack = 32;

  void _handleScroll() {
    if (!scroll.hasClients) return;
    final position = scroll.position;
    _stick = position.pixels >= position.maxScrollExtent - _slack;
  }

  double get _pageExtent => scroll.hasClients
      ? scroll.position.viewportDimension * 0.85
      : 320;

  void pageUp() => _animateBy(-_pageExtent);

  void pageDown() => _animateBy(_pageExtent);

  void toTop() {
    if (!scroll.hasClients) return;
    _stick = false;
    scroll.animateTo(
      0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  void toBottom() {
    if (!scroll.hasClients) return;
    _stick = true;
    scroll.animateTo(
      scroll.position.maxScrollExtent,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  void _animateBy(double delta) {
    if (!scroll.hasClients) return;
    final position = scroll.position;
    final target =
        (position.pixels + delta).clamp(0.0, position.maxScrollExtent);
    scroll.animateTo(
      target,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }
}

/// Renders the scrollback buffer of [session] with the prompt and the live
/// input line as its final row — the way a real terminal works, rather than a
/// separate input box pinned to the bottom of the screen.
///
/// Tapping anywhere on the canvas focuses the input. The tap is detected with a
/// raw [Listener] rather than a [GestureDetector] so it never competes in the
/// gesture arena with text selection or with scrolling.
class TerminalOutputView extends StatefulWidget {
  const TerminalOutputView({
    super.key,
    required this.session,
    required this.scrollController,
    required this.fontSize,
    required this.wrap,
    required this.inputController,
    required this.focusNode,
    required this.onSubmitted,
    required this.onInterrupt,
    required this.onKeyEvent,
  });

  final TerminalSession session;
  final TerminalScrollController scrollController;
  final double fontSize;
  final bool wrap;
  final TextEditingController inputController;
  final FocusNode focusNode;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onInterrupt;
  final KeyEventResult Function(FocusNode node, KeyEvent event) onKeyEvent;

  @override
  State<TerminalOutputView> createState() => _TerminalOutputViewState();
}

class _TerminalOutputViewState extends State<TerminalOutputView> {
  /// A press longer than this many pixels of movement was a scroll or a
  /// selection drag, not a tap.
  static const double _tapSlop = 12;

  int _itemCount = 0;
  Offset? _pointerDown;

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_handleSessionChanged);
    widget.inputController.addListener(_handleInputChanged);
    widget.focusNode.addListener(_handleFocusChanged);
    _itemCount = _count();
    _scrollToBottom();
  }

  @override
  void didUpdateWidget(covariant TerminalOutputView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session) {
      oldWidget.session.removeListener(_handleSessionChanged);
      widget.session.addListener(_handleSessionChanged);
      _itemCount = _count();
      _scrollToBottom();
    }
    if (oldWidget.inputController != widget.inputController) {
      oldWidget.inputController.removeListener(_handleInputChanged);
      widget.inputController.addListener(_handleInputChanged);
    }
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_handleFocusChanged);
      widget.focusNode.addListener(_handleFocusChanged);
    }
  }

  @override
  void dispose() {
    widget.session.removeListener(_handleSessionChanged);
    widget.inputController.removeListener(_handleInputChanged);
    widget.focusNode.removeListener(_handleFocusChanged);
    super.dispose();
  }

  int _count() {
    // +1 for the prompt/input row that always closes the buffer. Trailing
    // partial output is part of that row, not a row of its own.
    return widget.session.lines.length + 1;
  }

  void _handleSessionChanged() {
    if (!mounted) return;
    final count = _count();
    final grew = count != _itemCount;
    _itemCount = count;
    setState(() {});
    if (grew) _scrollToBottom();
  }

  void _handleInputChanged() {
    if (!mounted) return;
    // Long input can push the prompt row past the viewport edge.
    _scrollToBottom();
  }

  void _handleFocusChanged() {
    if (!mounted) return;
    // Opening the software keyboard shrinks the viewport; keep the prompt row
    // visible rather than letting it slide under the keyboard.
    if (widget.focusNode.hasFocus) _scrollToBottom();
    setState(() {});
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = widget.scrollController;
      if (!controller.stickToBottom || !controller.scroll.hasClients) return;
      controller.scroll.jumpTo(controller.scroll.position.maxScrollExtent);
    });
  }

  void _handlePointerDown(PointerDownEvent event) {
    _pointerDown = event.position;
  }

  void _handlePointerUp(PointerUpEvent event) {
    final start = _pointerDown;
    _pointerDown = null;
    if (start == null) return;
    if ((event.position - start).distance > _tapSlop) return;
    if (widget.focusNode.hasFocus) return;
    // Deferred by one frame: an enclosing SelectionArea takes focus on tap up,
    // so requesting it now would be undone immediately.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.focusNode.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppTheme.palette(context);
    final baseStyle = AppTheme.mono(widget.fontSize, color: palette.foreground);
    final scheme = Theme.of(context).colorScheme;

    final lines = widget.session.lines;
    final inputIndex = lines.length;
    final itemCount = inputIndex + 1;

    return Listener(
      onPointerDown: _handlePointerDown,
      onPointerUp: _handlePointerUp,
      child: ColoredBox(
        color: palette.background,
        child: Scrollbar(
          controller: widget.scrollController.scroll,
          child: ListView.builder(
            controller: widget.scrollController.scroll,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
            itemCount: itemCount,
            itemBuilder: (context, index) {
              if (index == inputIndex) {
                return _buildInputLine(scheme, palette, baseStyle);
              }

              final segments = lines[index].segments;
              if (segments.isEmpty) return Text(' ', style: baseStyle);

              return Text.rich(
                TextSpan(
                  style: baseStyle,
                  children: <TextSpan>[
                    for (final segment in segments)
                      _spanFor(segment, baseStyle, scheme, palette),
                  ],
                ),
                softWrap: widget.wrap,
                overflow:
                    widget.wrap ? TextOverflow.clip : TextOverflow.visible,
              );
            },
          ),
        ),
      ),
    );
  }

  /// The prompt plus the live edit field, rendered as ordinary terminal text so
  /// it reads as the last line of the buffer.
  ///
  /// Whatever the shell last wrote *without* a newline is put on the same row,
  /// ahead of the field. That is what makes it look like a terminal rather than
  /// a stack of input boxes: the cursor ends up immediately after the remote
  /// prompt (`root@host:~# `) instead of on a line of its own underneath it.
  Widget _buildInputLine(
    ColorScheme scheme,
    TerminalPalette palette,
    TextStyle baseStyle,
  ) {
    final backend = widget.session.backend;
    final attached = backend.attached;
    final pending = widget.session.pendingSegments;
    final maxLeadingWidth = MediaQuery.sizeOf(context).width * 0.6;

    // Which prompt, if any, this row draws ahead of the cursor.
    //
    //   * not attached — the backend's own prompt (`~$ `).
    //   * attached, prompt: false — nothing. An `ssh` shell prints its own
    //     prompt as ordinary output, so it is already at the start of this row;
    //     drawing our label in front of it would put the cursor after two
    //     prompts.
    //   * attached, prompt: true, echo: true — nothing either, because the far
    //     end echoes what we send, so anything we drew would be doubled.
    //   * attached, prompt: true, echo: false — our label. Nothing else is
    //     printed for it, so this is the only thing telling the user what they
    //     are typing into (a password prompt, an SFTP session).
    final String? promptText;
    if (!attached) {
      promptText = widget.session.prompt;
    } else if (!backend.attachPrompt || backend.attachEcho) {
      promptText = null;
    } else {
      promptText = backend.attachLabel;
    }

    // No extra vertical padding: the live row has to sit on exactly the same
    // line rhythm as the history above it, or it reads as a separate widget
    // bolted on underneath rather than the last line of one continuous canvas.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (pending.isNotEmpty)
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxLeadingWidth),
            child: Text.rich(
              TextSpan(
                style: baseStyle,
                children: <TextSpan>[
                  for (final segment in pending)
                    _spanFor(segment, baseStyle, scheme, palette),
                ],
              ),
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        if (promptText != null)
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxLeadingWidth),
            child: Text(
              promptText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.mono(
                widget.fontSize,
                color: scheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        if (pending.isNotEmpty || promptText != null) const SizedBox(width: 8),
        Expanded(
          child: Focus(
            onKeyEvent: widget.onKeyEvent,
            child: TextField(
              controller: widget.inputController,
              focusNode: widget.focusNode,
              style: AppTheme.mono(
                widget.fontSize,
                color: palette.foreground,
              ),
              cursorColor: scheme.primary,
              cursorWidth: 2,
              cursorRadius: const Radius.circular(1),
              // Only a tool that says it wants a secret masks the input.
              // Inferring it from `!attachEcho` was wrong: an `ssh` shell does
              // not echo locally because the remote PTY echoes, which is not
              // the same thing as being a secret — that hid the user's own
              // typing behind dots.
              obscureText: attached && backend.attachSecret,
              maxLines: 1,
              textInputAction: TextInputAction.send,
              onSubmitted: widget.onSubmitted,
              autocorrect: false,
              enableSuggestions: false,
              // No border, no fill, no padding: the field has to be
              // indistinguishable from the surrounding terminal text.
              decoration: InputDecoration(
                isCollapsed: true,
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hint: _InputHint(
                  controller: widget.inputController,
                  focused: widget.focusNode.hasFocus,
                  text: attached ? '输入内容，回车发送' : '输入命令，回车执行',
                  style: AppTheme.mono(
                    widget.fontSize,
                    color: palette.foreground.withValues(alpha: 0.3),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (widget.session.busy)
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: _InterruptChip(
              color: scheme.error,
              onTap: widget.onInterrupt,
            ),
          ),
      ],
    );
  }

  TextSpan _spanFor(
    TerminalSegment segment,
    TextStyle base,
    ColorScheme scheme,
    TerminalPalette palette,
  ) {
    Color? color;
    var weight = base.fontWeight;
    var decoration = TextDecoration.none;

    switch (segment.emphasis) {
      case TerminalEmphasis.prompt:
        color = scheme.primary;
        weight = FontWeight.w600;
      case TerminalEmphasis.command:
        color = palette.foreground;
        weight = FontWeight.w500;
      case TerminalEmphasis.system:
        color = palette.foreground.withValues(alpha: 0.55);
      case TerminalEmphasis.error:
        color = palette.resolve(1);
      case TerminalEmphasis.normal:
        color = palette.resolve(segment.style.foreground ?? -1);
        if (segment.style.bold) weight = FontWeight.w700;
        if (segment.style.dim) color = color.withValues(alpha: 0.6);
        if (segment.style.underline) decoration = TextDecoration.underline;
    }

    return TextSpan(
      text: segment.text,
      style: base.copyWith(
        color: color,
        fontWeight: weight,
        decoration: decoration,
        backgroundColor: segment.style.background == null
            ? null
            : palette.resolve(segment.style.background!),
      ),
    );
  }
}

/// Placeholder shown only while the field is empty *and* unfocused, so a
/// focused terminal looks like a plain prompt with a blinking cursor.
class _InputHint extends StatelessWidget {
  const _InputHint({
    required this.controller,
    required this.focused,
    required this.text,
    required this.style,
  });

  final TextEditingController controller;
  final bool focused;
  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    if (focused) return const SizedBox.shrink();
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        if (value.text.isNotEmpty) return const SizedBox.shrink();
        return Text(text, style: style);
      },
    );
  }
}

/// Small inline "stop" affordance shown at the end of the prompt row while a
/// command is running.
class _InterruptChip extends StatelessWidget {
  const _InterruptChip({required this.color, required this.onTap});

  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '中断当前命令 (Ctrl+C)',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.stop_circle_outlined, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                '中断',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
