import 'package:flutter/material.dart';

/// A focus node that never takes focus, so tapping a key cap does not dismiss
/// the software keyboard.
final FocusNode _passiveFocusNode = FocusNode(
  canRequestFocus: false,
  skipTraversal: true,
  debugLabel: 'terminax-keycap',
);

/// A compact, non-focus-stealing key cap used by the shortcut bar.
class KeyCap extends StatelessWidget {
  const KeyCap({
    super.key,
    required this.label,
    this.onTap,
    this.onLongPress,
    this.selected = false,
    this.icon,
    this.tooltip,
    this.minWidth = 40,
    this.dense = false,
    this.flat = false,
  });

  final String label;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool selected;
  final IconData? icon;
  final String? tooltip;
  final double minWidth;
  final bool dense;

  /// Draws the cap as plain text on the canvas instead of a filled rounded
  /// box.
  ///
  /// A row of filled rounded boxes reads as a row of form fields rather than
  /// as part of the terminal, which is the whole complaint about the key bar
  /// looking like "one input box after another". Flat caps keep the keys
  /// available without introducing chrome; the locked state (Ctrl / Alt) is
  /// shown with a tint and the primary colour instead of a filled surface.
  final bool flat;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = flat
        ? (selected ? scheme.primary.withValues(alpha: 0.14) : Colors.transparent)
        : (selected ? scheme.secondaryContainer : scheme.surfaceContainerHigh);
    final foreground = flat
        ? (selected ? scheme.primary : scheme.onSurfaceVariant)
        : (selected ? scheme.onSecondaryContainer : scheme.onSurfaceVariant);
    final radius = BorderRadius.circular(flat ? 0 : (dense ? 8 : 9));

    Widget cap = Material(
      color: background,
      borderRadius: radius,
      child: InkWell(
        focusNode: _passiveFocusNode,
        canRequestFocus: false,
        borderRadius: radius,
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          constraints: BoxConstraints(
            minWidth: minWidth,
            minHeight: flat ? (dense ? 26 : 30) : (dense ? 30 : 34),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: flat ? (dense ? 7 : 8) : (dense ? 9 : 11),
          ),
          // `widthFactor`/`heightFactor` of 1 matter: a bare `alignment:` would
          // wrap the child in an `Align`, which expands to the *maximum* width
          // it is offered. In the primary row that is harmless (a Row hands out
          // unbounded width, so the cap shrink-wraps), but inside the expanded
          // panel's `Wrap` the width is bounded, so every cap would stretch to
          // the full panel width and occupy a row of its own. Centring with a
          // factor of 1 keeps the content centred while still shrink-wrapping.
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (icon != null) ...<Widget>[
                  Icon(icon, size: dense ? 14 : 16, color: foreground),
                  if (label.isNotEmpty) const SizedBox(width: 5),
                ],
                if (label.isNotEmpty)
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: dense ? 11.5 : 12.5,
                      height: 1.1,
                      fontWeight: selected
                          ? FontWeight.w700
                          : (flat ? FontWeight.w500 : FontWeight.w600),
                      color: foreground,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    if (tooltip != null) {
      cap = Tooltip(message: tooltip!, child: cap);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: cap,
    );
  }
}
