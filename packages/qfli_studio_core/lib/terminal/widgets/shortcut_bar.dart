import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'key_cap.dart';

/// Named keys the shortcut bar can emit.
enum ShortcutKey {
  escape,
  tab,
  arrowUp,
  arrowDown,
  arrowLeft,
  arrowRight,
  home,
  end,
  pageUp,
  pageDown,
  enter,
  backspace,
  delete,
  clear,
  interrupt,
  paste,
  copyAll,
  selectAll,
  toggleKeyboard,
}

/// The bottom shortcut bar: sticky modifiers, navigation keys and a large set of
/// symbols, all reachable without leaving the software keyboard.
///
/// The expanded panel lays its keys out with a [Wrap] rather than a horizontal
/// scroll view, so nothing is ever clipped at the screen edge — on a narrow
/// phone the keys simply flow onto more rows.
class ShortcutBar extends StatelessWidget {
  const ShortcutBar({
    super.key,
    required this.ctrlActive,
    required this.altActive,
    required this.expanded,
    required this.busy,
    required this.attached,
    required this.onCtrlChanged,
    required this.onAltChanged,
    required this.onExpandedChanged,
    required this.onText,
    required this.onKey,
    required this.onCtrlLetter,
    this.flat = false,
    this.maxBarHeight,
  });

  final bool ctrlActive;
  final bool altActive;
  final bool expanded;
  final bool busy;

  /// True while an interactive tool owns the input line.
  final bool attached;

  /// Terminal-mode styling: no filled bar, no rounded key boxes, no safe-area
  /// padding of its own.
  ///
  /// In this mode the row is a keyboard accessory — it is only on screen while
  /// the software keyboard is up, so it has to blend into the canvas rather
  /// than look like a toolbar bolted to the bottom of the window. The caller
  /// owns the safe area in that case.
  final bool flat;

  /// How much of the column around the bar is left for the bar itself.
  ///
  /// Set by a caller that knows its own height: the expanded panel would
  /// otherwise hold on to its own cap while the canvas above it is squeezed to
  /// nothing, which shows up as a RenderFlex overflow with a keyboard up. Null
  /// leaves the panel to its preferred height.
  final double? maxBarHeight;

  final ValueChanged<bool> onCtrlChanged;
  final ValueChanged<bool> onAltChanged;
  final ValueChanged<bool> onExpandedChanged;
  final ValueChanged<String> onText;
  final ValueChanged<ShortcutKey> onKey;
  final ValueChanged<String> onCtrlLetter;

  static const List<String> _symbols = <String>[
    '|',
    '-',
    '/',
    '~',
    '.',
    '_',
    r'$',
    '&',
    '*',
    '#',
    '@',
    '!',
    '=',
    '+',
    '<',
    '>',
    '(',
    ')',
    '[',
    ']',
    '{',
    '}',
    ':',
    ';',
    ',',
    '?',
    "'",
    '"',
    r'\',
    '`',
  ];

  static const List<({String letter, String hint})> _ctrlLetters =
      <({String letter, String hint})>[
        (letter: 'A', hint: '移动到行首'),
        (letter: 'E', hint: '移动到行尾'),
        (letter: 'U', hint: '清空当前输入'),
        (letter: 'K', hint: '删除光标之后的内容'),
        (letter: 'W', hint: '删除前一个单词'),
        (letter: 'H', hint: '退格'),
        (letter: 'C', hint: '中断正在运行的命令'),
        (letter: 'D', hint: '输入为空时关闭终端'),
        (letter: 'L', hint: '清屏'),
        (letter: 'Z', hint: '中断当前命令'),
      ];

  static const List<({String command, String hint})> _quickCommands =
      <({String command, String hint})>[
        (command: 'pwd', hint: '打印当前目录'),
        (command: 'ls', hint: '列出目录（PowerShell 别名）'),
        (command: 'dir', hint: '列出目录'),
        (command: 'cd ..', hint: '返回上级目录'),
        (command: 'history', hint: '查看命令历史'),
        (command: 'clear', hint: '清空当前终端'),
        (command: 'help', hint: '查看可用命令'),
        (command: 'git status', hint: '查看 Git 状态'),
      ];

  static const List<({String command, String hint})> _networkCommands =
      <({String command, String hint})>[
        (command: 'curl', hint: 'curl -h 查看用法'),
        (command: 'wget', hint: 'wget -h 查看用法'),
        (command: 'dig', hint: 'dig example.com MX'),
        (command: 'nslookup', hint: 'nslookup example.com'),
        (command: 'ping', hint: 'ping example.com'),
        (command: 'traceroute', hint: 'traceroute example.com'),
        (command: 'nc -z', hint: 'nc -z 主机 端口'),
        (command: 'telnet', hint: 'telnet 主机 端口'),
        (command: 'ssh', hint: 'ssh 用户@主机'),
        (command: 'sftp', hint: 'sftp 用户@主机'),
        (command: 'scp', hint: 'scp 本地 主机:/路径'),
      ];

  @override
  Widget build(BuildContext context) {
    final column = Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _buildPrimaryRow(context),
        ClipRect(
          child: AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: expanded
                ? _buildExpandedPanel(context)
                : const SizedBox(width: double.infinity),
          ),
        ),
      ],
    );

    if (flat) {
      // Painted in the *canvas* colour, not the scaffold colour: the row has to
      // look like the last band of the terminal rather than a separate surface
      // underneath it.
      return ColoredBox(
        color: AppTheme.palette(context).background,
        child: column,
      );
    }

    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        border: Border(top: BorderSide(color: scheme.outlineVariant, width: 1)),
      ),
      child: SafeArea(top: false, child: column),
    );
  }

  // --------------------------------------------------------------- primary row

  /// Height of the key row that stays on screen whether or not the panel is open.
  double get _rowHeight => flat ? 36 : 48;

  Widget _buildPrimaryRow(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fade = flat
        ? AppTheme.palette(context).background
        : scheme.surfaceContainer;

    return SizedBox(
      height: _rowHeight,
      child: Row(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(left: 8, right: 2),
            child: KeyCap(
              label: expanded ? '收起' : '更多',
              icon: expanded
                  ? Icons.keyboard_arrow_down_rounded
                  : Icons.keyboard_arrow_up_rounded,
              selected: expanded,
              onTap: () => onExpandedChanged(!expanded),
              tooltip: expanded ? '收起扩展按键' : '展开符号、常用命令与网络工具',
              minWidth: 0,
              flat: flat,
            ),
          ),
          Container(
            width: 1,
            height: 22,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            color: scheme.outlineVariant,
          ),
          Expanded(
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(0, 0, 16, 0),
                    child: Row(
                      children: <Widget>[
                        KeyCap(
                          flat: flat,
                          label: 'Esc',
                          onTap: () => onKey(ShortcutKey.escape),
                          tooltip: 'Esc：收起键盘 / 清空输入',
                        ),
                        KeyCap(
                          flat: flat,
                          label: 'Tab',
                          onTap: () => onKey(ShortcutKey.tab),
                          tooltip: 'Tab：插入制表符',
                        ),
                        _spacer(context),
                        KeyCap(
                          flat: flat,
                          label: 'Ctrl',
                          selected: ctrlActive,
                          onTap: () => onCtrlChanged(!ctrlActive),
                          tooltip: 'Ctrl 锁定：再点一次解锁',
                        ),
                        KeyCap(
                          flat: flat,
                          label: 'Alt',
                          selected: altActive,
                          onTap: () => onAltChanged(!altActive),
                          tooltip: 'Alt 锁定：与字母组合成 Alt+字母',
                        ),
                        _spacer(context),
                        KeyCap(
                          flat: flat,
                          label: '←',
                          onTap: () => onKey(ShortcutKey.arrowLeft),
                          tooltip: '光标左移',
                          minWidth: 38,
                        ),
                        KeyCap(
                          flat: flat,
                          label: '↑',
                          onTap: () => onKey(ShortcutKey.arrowUp),
                          tooltip: '上一条历史命令',
                          minWidth: 38,
                        ),
                        KeyCap(
                          flat: flat,
                          label: '↓',
                          onTap: () => onKey(ShortcutKey.arrowDown),
                          tooltip: '下一条历史命令',
                          minWidth: 38,
                        ),
                        KeyCap(
                          flat: flat,
                          label: '→',
                          onTap: () => onKey(ShortcutKey.arrowRight),
                          tooltip: '光标右移',
                          minWidth: 38,
                        ),
                        _spacer(context),
                        KeyCap(
                          flat: flat,
                          label: 'Home',
                          onTap: () => onKey(ShortcutKey.home),
                          tooltip: '移动到行首',
                        ),
                        KeyCap(
                          flat: flat,
                          label: 'End',
                          onTap: () => onKey(ShortcutKey.end),
                          tooltip: '移动到行尾',
                        ),
                        KeyCap(
                          flat: flat,
                          label: 'PgUp',
                          onTap: () => onKey(ShortcutKey.pageUp),
                          tooltip: '向上翻页',
                        ),
                        KeyCap(
                          flat: flat,
                          label: 'PgDn',
                          onTap: () => onKey(ShortcutKey.pageDown),
                          tooltip: '向下翻页',
                        ),
                        _spacer(context),
                        KeyCap(
                          flat: flat,
                          label: '^C',
                          selected: busy,
                          onTap: () => onKey(ShortcutKey.interrupt),
                          tooltip: 'Ctrl+C：中断当前命令 / 断开连接',
                          minWidth: 38,
                        ),
                        KeyCap(
                          flat: flat,
                          label: '清屏',
                          icon: Icons.cleaning_services_outlined,
                          onTap: () => onKey(ShortcutKey.clear),
                          tooltip: '清空当前终端输出',
                        ),
                        KeyCap(
                          flat: flat,
                          label: '粘贴',
                          icon: Icons.content_paste_rounded,
                          onTap: () => onKey(ShortcutKey.paste),
                          tooltip: '粘贴剪贴板内容到输入行',
                        ),
                        KeyCap(
                          flat: flat,
                          label: '键盘',
                          icon: Icons.keyboard_hide_outlined,
                          onTap: () => onKey(ShortcutKey.toggleKeyboard),
                          tooltip: '收起 / 展开软键盘',
                        ),
                      ],
                    ),
                  ),
                ),
                // Signals that the row scrolls rather than being cut off.
                Positioned(
                  top: 0,
                  bottom: 0,
                  right: 0,
                  width: 24,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: <Color>[fade.withValues(alpha: 0), fade],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- expanded area

  Widget _buildExpandedPanel(BuildContext context) {
    final showCtrlLetters = ctrlActive || altActive;

    // Shorter in flat mode: the panel rides directly above the software
    // keyboard, so it has to leave the canvas most of the screen. What the
    // caller can spare beats that preference when it is smaller — a panel
    // given less room than it wants scrolls, which is what keeps the column
    // from overflowing with a keyboard up.
    final preferred = flat ? 168.0 : 236.0;
    final cap = maxBarHeight == null
        ? preferred
        : math.max(0.0, math.min(preferred, maxBarHeight! - _rowHeight));

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: cap),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (attached) ...<Widget>[
              _banner(context, '正在交互连接中：输入的内容会直接发给对端，输入 .exit 或按 Ctrl+C 断开。'),
              const SizedBox(height: 12),
            ],
            if (showCtrlLetters) ...<Widget>[
              _label(context, altActive ? 'Alt + 字母' : 'Ctrl + 字母'),
              _wrap(<Widget>[
                for (final entry in _ctrlLetters)
                  KeyCap(
                    flat: flat,
                    label: '^${entry.letter}',
                    dense: true,
                    minWidth: 42,
                    onTap: () => onCtrlLetter(entry.letter),
                    tooltip: 'Ctrl+${entry.letter} · ${entry.hint}',
                  ),
              ]),
              const SizedBox(height: 14),
            ],
            _label(context, '网络工具'),
            _wrap(<Widget>[
              for (final entry in _networkCommands)
                KeyCap(
                  flat: flat,
                  label: entry.command,
                  dense: true,
                  minWidth: 0,
                  onTap: () => onText('${entry.command} '),
                  tooltip: '${entry.hint}（点击填入）',
                ),
            ]),
            const SizedBox(height: 14),
            _label(context, '常用命令'),
            _wrap(<Widget>[
              for (final entry in _quickCommands)
                KeyCap(
                  flat: flat,
                  label: entry.command,
                  dense: true,
                  minWidth: 0,
                  onTap: () => onText(entry.command),
                  tooltip: '${entry.hint}（点击填入）',
                ),
            ]),
            const SizedBox(height: 14),
            _label(context, '符号'),
            _wrap(<Widget>[
              for (final symbol in _symbols)
                KeyCap(
                  flat: flat,
                  label: symbol,
                  dense: true,
                  minWidth: 36,
                  onTap: () => onText(symbol),
                  tooltip: '插入 $symbol',
                ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _wrap(List<Widget> children) =>
      Wrap(spacing: 0, runSpacing: 7, children: children);

  Widget _label(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(left: 3, bottom: 8),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );

  Widget _banner(BuildContext context, String text) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          height: 1.4,
          color: scheme.onPrimaryContainer,
        ),
      ),
    );
  }

  Widget _spacer(BuildContext context) => Container(
    width: 1,
    height: 20,
    margin: const EdgeInsets.symmetric(horizontal: 7),
    color: Theme.of(
      context,
    ).colorScheme.outlineVariant.withValues(alpha: flat ? 0.55 : 1),
  );
}
