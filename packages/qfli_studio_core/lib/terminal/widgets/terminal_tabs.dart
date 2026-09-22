import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/terminal_session.dart';
import '../shell/ansi.dart';
import '../theme/app_theme.dart';

/// Height of one row of the strip, shared with the screen that budgets the
/// column around it.
const double kTerminalTabStripHeight = 52;

/// Actions offered by a long-press on a tab.
enum _TabAction { rename, close, closeOthers, closeAll }

/// Strip of open terminals, built on Material's own [TabBar].
///
/// The framework already ships a tab component with a correct indicator,
/// scrolling behaviour, accessibility and Material 3 styling, so there is no
/// reason to reimplement one. What it does not ship is a way to drive that
/// indicator from a *different* pager than [TabBarView], which is what the
/// terminal canvas needs — the canvas keeps its own pager because `TabBarView`
/// would reimpose `PageView`'s 50%-of-a-page snap threshold.
///
/// The bridge is the same one `TabBarView` uses internally: write the pager's
/// fractional page into the [TabController]'s `index` and `offset`. See
/// `_syncController`.
///
/// Creating terminals is deliberately *not* offered here — the overflow menu
/// has a new-terminal entry and `Ctrl+T` does the same, so a second button in
/// the strip was only clutter. Long-pressing a tab opens the per-terminal menu
/// (rename / close / close others / close all).
class TerminalTabStrip extends StatefulWidget {
  const TerminalTabStrip({
    super.key,
    required this.sessions,
    required this.activeId,
    required this.pagePosition,
    required this.onSelect,
    required this.onClose,
    required this.onCloseOthers,
    required this.onCloseAll,
    required this.onRename,
    this.flat = false,
  });

  final List<TerminalSession> sessions;
  final String? activeId;

  /// Fractional page index of the canvas, e.g. `0.4` when the second terminal
  /// is 40% of the way in.
  final ValueListenable<double> pagePosition;

  final ValueChanged<String> onSelect;
  final ValueChanged<String> onClose;
  final ValueChanged<String> onCloseOthers;
  final VoidCallback onCloseAll;
  final ValueChanged<TerminalSession> onRename;

  /// Paint the strip on the *canvas* colour instead of a seeded surface tone.
  ///
  /// The strip floats directly over the terminal, so any surface tint would
  /// show up as a band of a different colour across the top of the canvas —
  /// the same trap the key row avoids. In this mode only the indicator and the
  /// text separate a selected tab from the rest.
  final bool flat;

  @override
  State<TerminalTabStrip> createState() => _TerminalTabStripState();
}

class _TerminalTabStripState extends State<TerminalTabStrip>
        // Not `SingleTickerProviderStateMixin`: opening or closing a terminal
        // replaces the TabController, and each replacement needs a fresh ticker.
        with
        TickerProviderStateMixin {
  TabController? _tabs;

  @override
  void initState() {
    super.initState();
    widget.pagePosition.addListener(_syncController);
    _rebuildController();
  }

  @override
  void didUpdateWidget(covariant TerminalTabStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pagePosition != widget.pagePosition) {
      oldWidget.pagePosition.removeListener(_syncController);
      widget.pagePosition.addListener(_syncController);
    }
    // `TabController` has no way to change its length, so a new one is the only
    // option when terminals are opened or closed.
    if (oldWidget.sessions.length != widget.sessions.length) {
      _rebuildController();
    }
  }

  @override
  void dispose() {
    widget.pagePosition.removeListener(_syncController);
    _tabs?.dispose();
    super.dispose();
  }

  void _rebuildController() {
    _tabs?.dispose();
    final count = widget.sessions.length;
    if (count == 0) {
      _tabs = null;
      return;
    }
    final controller = TabController(
      length: count,
      vsync: this,
      initialIndex: _clampIndex(widget.activeId),
    );
    controller.addListener(_handleControllerChanged);
    _tabs = controller;
    _syncController();
  }

  int _clampIndex(String? id) {
    if (id == null) return 0;
    final index = widget.sessions.indexWhere((session) => session.id == id);
    return index < 0 ? 0 : index;
  }

  /// Keeps [TabBar]'s own idea of the selection in step when the user taps a
  /// tab, so the indicator animates even before the pager has caught up.
  void _handleControllerChanged() {
    if (_tabs?.indexIsChanging ?? false) return;
    if (mounted) setState(() {});
  }

  /// Mirrors the pager's fractional page into the controller.
  ///
  /// While the pager is between pages — mid-drag or mid-animation — only the
  /// `offset` tracks it, exactly what `TabBarView` does in its own scroll
  /// handler. The `index` follows once the pager *rests* on a page: a
  /// single-page swipe lands one whole tab away, where a
  /// `distance > one tab` gate never fires and the selection would stay
  /// behind on the tab the gesture started from.
  void _syncController() {
    final controller = _tabs;
    if (controller == null || !mounted) return;

    final page = widget.pagePosition.value;
    final rounded = page.round().clamp(0, controller.length - 1);
    // Overwriting the index during a tap's own animation would reset the
    // indicator's slide, so leave the controller alone while it animates.
    if (!controller.indexIsChanging &&
        (page - rounded).abs() < 0.001 &&
        rounded != controller.index) {
      controller.index = rounded;
    }
    // `offset` asserts on this: during an animated index change the controller
    // owns the animation and must not have it overwritten.
    if (controller.indexIsChanging) return;
    controller.offset = (page - controller.index).clamp(-1.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final controller = _tabs;
    if (controller == null) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final palette = AppTheme.palette(context);

    return ColoredBox(
      // Never `scheme.surfaceContainer*`: the strip sits on the terminal, and a
      // seeded surface would draw a tinted band across the top of the canvas.
      color: widget.flat ? palette.background : scheme.surfaceContainerLow,
      child: TabBar(
        controller: controller,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        // Flat: the strip has no chrome of its own, so the divider Material
        // draws under it would read as a rule across the canvas.
        dividerColor: widget.flat ? Colors.transparent : null,
        // The indicator is the *only* thing separating the selected tab from
        // the rest in flat mode, so it keeps the theme's accent colour rather
        // than a canvas tone.
        indicatorColor: widget.flat ? scheme.primary : null,
        // The canvas is the source of truth, so a tap only reports the
        // selection; the pager animates and the indicator follows from
        // `_syncController`.
        onTap: (index) => widget.onSelect(widget.sessions[index].id),
        tabs: <Widget>[
          for (final session in widget.sessions) _buildTab(session, palette),
        ],
      ),
    );
  }

  /// The per-terminal menu opened by a long-press.
  ///
  /// "Close" is always live — closing the last terminal is what the screen
  /// turns into a fresh one. "Close others" and "close all" only make sense
  /// once there is more than one, so with a single tab they render greyed
  /// rather than vanishing, which keeps the menu the same shape either way.
  Future<void> _showTabMenu(TerminalSession session, Offset at) async {
    final moreThanOne = widget.sessions.length > 1;
    final action = await showMenu<_TabAction>(
      context: context,
      position: RelativeRect.fromLTRB(at.dx, at.dy, at.dx, at.dy),
      items: <PopupMenuEntry<_TabAction>>[
        const PopupMenuItem<_TabAction>(
          value: _TabAction.rename,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.drive_file_rename_outline, size: 20),
            title: Text('重命名'),
          ),
        ),
        const PopupMenuItem<_TabAction>(
          value: _TabAction.close,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.close_rounded, size: 20),
            title: Text('关闭终端'),
          ),
        ),
        PopupMenuItem<_TabAction>(
          value: _TabAction.closeOthers,
          enabled: moreThanOne,
          child: const ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.vertical_align_center_rounded, size: 20),
            title: Text('关闭其他终端'),
          ),
        ),
        PopupMenuItem<_TabAction>(
          value: _TabAction.closeAll,
          enabled: moreThanOne,
          child: const ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.layers_clear_rounded, size: 20),
            title: Text('关闭所有终端'),
          ),
        ),
      ],
    );
    if (action == null || !mounted) return;
    switch (action) {
      case _TabAction.rename:
        widget.onRename(session);
      case _TabAction.close:
        widget.onClose(session.id);
      case _TabAction.closeOthers:
        widget.onCloseOthers(session.id);
      case _TabAction.closeAll:
        widget.onCloseAll();
    }
  }

  Widget _buildTab(TerminalSession session, TerminalPalette palette) {
    final scheme = Theme.of(context).colorScheme;
    final selected = session.id == widget.activeId;

    // The strip is painted on the canvas colour, so the regular onSurface
    // variants would be illegible against it in a light theme.
    final Color labelColor;
    if (widget.flat) {
      labelColor = selected
          ? palette.foreground
          : palette.foreground.withValues(alpha: 0.55);
    } else {
      labelColor = selected ? scheme.onSurface : scheme.onSurfaceVariant;
    }

    return Tab(
      height: kTerminalTabStripHeight,
      child: ListenableBuilder(
        listenable: session,
        builder: (context, _) {
          final status = session.attached
              ? '交互连接中 · ${session.backend.attachLabel}'
              : session.cwd;

          return Tooltip(
            message: '${session.shellLabel}\n$status\n长按打开菜单',
            child: GestureDetector(
              // Only the long press is claimed here; a tap still falls through
              // to the `TabBar` so selecting the terminal keeps working.
              onLongPressStart: (details) =>
                  _showTabMenu(session, details.globalPosition),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _StatusDot(session: session, selected: selected),
                  const SizedBox(width: 8),
                  Text(
                    session.title,
                    style: TextStyle(
                      fontSize: 13,
                      color: labelColor,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 2),
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => widget.onClose(session.id),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.close_rounded,
                        size: 15,
                        color: widget.flat
                            ? palette.foreground.withValues(alpha: 0.55)
                            : scheme.onSurfaceVariant,
                      ),
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
}

/// Small dot showing whether the terminal is running something or holding an
/// interactive connection.
class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.session, required this.selected});

  final TerminalSession session;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = session.busy
        ? scheme.primary
        : session.attached
        ? scheme.tertiary
        : selected
        ? scheme.primary.withValues(alpha: 0.5)
        : scheme.outlineVariant;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: 8,
      height: 8,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}
