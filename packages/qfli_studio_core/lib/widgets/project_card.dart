import 'dart:async';

import 'package:flutter/material.dart';

import '../models/project.dart';
import '../services/app_paths.dart';
import '../services/file_service.dart';

enum ProjectCardAction { open, reveal, remove, favorite }

/// 主页的项目卡片 — MD3 outlined 风格。
class ProjectCard extends StatefulWidget {
  const ProjectCard({
    super.key,
    required this.project,
    required this.onOpen,
    required this.onRemove,
    this.onToggleFavorite,
  });

  final Project project;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  /// 收藏切换回调（null 时隐藏收藏菜单项）。
  final ValueChanged<bool>? onToggleFavorite;

  @override
  State<ProjectCard> createState() => _ProjectCardState();
}

class _ProjectCardState extends State<ProjectCard> {
  bool _hovering = false;

  /// 友好的时间距离文本。
  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
    if (diff.inHours < 24) return '${diff.inHours} 小时前';
    if (diff.inDays < 30) return '${diff.inDays} 天前';
    if (diff.inDays < 365) return '${diff.inDays ~/ 30} 个月前';
    return '${diff.inDays ~/ 365} 年前';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final project = widget.project;

    // 云端项目用 tertiary 色系区分。
    final iconBg = project.isCloud
        ? scheme.tertiaryContainer
        : scheme.primaryContainer;
    final iconFg = project.isCloud
        ? scheme.onTertiaryContainer
        : scheme.onPrimaryContainer;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: _hovering ? 1 : 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: _hovering
                ? scheme.outline.withValues(alpha: 0.5)
                : scheme.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onOpen,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.only(
              left: 14,
              top: 12,
              bottom: 12,
              right: 4,
            ),
            child: Row(
              children: [
                // 项目类型图标。
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    project.isCloud
                        ? Icons.cloud_outlined
                        : Icons.folder_outlined,
                    size: 22,
                    color: iconFg,
                  ),
                ),
                const SizedBox(width: 14),

                // ── 中间信息 ──
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 第一行：名称 + 收藏 + 语言
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              project.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.1,
                              ),
                            ),
                          ),
                          if (project.favorite) ...[
                            const SizedBox(width: 4),
                            Icon(
                              Icons.star_rounded,
                              size: 15,
                              color: scheme.tertiary,
                            ),
                          ],
                          if (project.language.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.secondaryContainer,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                project.language,
                                style: textTheme.labelSmall?.copyWith(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: scheme.onSecondaryContainer,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),

                      // 第二行：路径 + 时间
                      Row(
                        children: [
                          Expanded(
                            child: Tooltip(
                              message: project.path,
                              waitDuration: const Duration(milliseconds: 500),
                              child: _LeftEllipsisText(
                                project.path,
                                style: textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant.withValues(
                                    alpha: 0.7,
                                  ),
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _timeAgo(project.lastOpenedAt),
                            style: textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant.withValues(
                                alpha: 0.5,
                              ),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ── 右侧菜单 ──
                PopupMenuButton<ProjectCardAction>(
                  tooltip: '更多操作',
                  icon: Icon(
                    Icons.more_vert,
                    size: 20,
                    color: scheme.onSurfaceVariant,
                  ),
                  padding: EdgeInsets.zero,
                  splashRadius: 20,
                  onSelected: (action) {
                    switch (action) {
                      case ProjectCardAction.open:
                        widget.onOpen();
                      case ProjectCardAction.reveal:
                        unawaited(
                          FileService.revealInFileManager(project.path),
                        );
                      case ProjectCardAction.remove:
                        widget.onRemove();
                      case ProjectCardAction.favorite:
                        widget.onToggleFavorite?.call(!project.favorite);
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: ProjectCardAction.favorite,
                      child: Row(
                        children: [
                          Icon(
                            project.favorite
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(project.favorite ? '取消收藏' : '收藏'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: ProjectCardAction.open,
                      child: Row(
                        children: [
                          Icon(Icons.open_in_new, size: 20),
                          SizedBox(width: 12),
                          Text('打开项目'),
                        ],
                      ),
                    ),
                    if (AppPaths.isDesktop)
                      const PopupMenuItem(
                        value: ProjectCardAction.reveal,
                        child: Row(
                          children: [
                            Icon(Icons.launch_outlined, size: 20),
                            SizedBox(width: 12),
                            Text('在资源管理器中显示'),
                          ],
                        ),
                      ),
                    const PopupMenuItem(
                      value: ProjectCardAction.remove,
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 20),
                          SizedBox(width: 12),
                          Text('删除'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 单行文本，宽度不足时从左侧截断（保留尾部），供路径副标题使用：
/// 路径的辨识信息在后半段，原生 [TextOverflow.ellipsis] 只会截掉尾部。
class _LeftEllipsisText extends StatelessWidget {
  const _LeftEllipsisText(this.text, {this.style});

  final String text;
  final TextStyle? style;

  static const String _ellipsis = '…';

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = style ?? DefaultTextStyle.of(context).style;
    final textDirection = Directionality.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth.isFinite &&
            _widthOf(text, effectiveStyle, textDirection) >
                constraints.maxWidth) {
          return Text(
            _truncateFromStart(text, effectiveStyle, constraints.maxWidth),
            maxLines: 1,
            style: effectiveStyle,
          );
        }
        return Text(text, maxLines: 1, style: effectiveStyle);
      },
    );
  }

  double _widthOf(String value, TextStyle style, TextDirection direction) {
    final painter = TextPainter(
      text: TextSpan(text: value, style: style),
      maxLines: 1,
      textDirection: direction,
    )..layout();
    return painter.width;
  }

  String _truncateFromStart(String value, TextStyle style, double maxWidth) {
    final direction = TextDirection.ltr;
    // 二分查找最小丢弃前缀数，使「… + 后缀」不超宽。
    var lo = 0;
    var hi = value.length;
    while (lo < hi) {
      final mid = (lo + hi) ~/ 2;
      if (_widthOf(_ellipsis + value.substring(mid), style, direction) <=
          maxWidth) {
        hi = mid;
      } else {
        lo = mid + 1;
      }
    }
    var drop = lo;
    // 截断点推进到首个分隔符之后，省略号后从完整路径段开始；
    // 多丢弃只会更窄，不会超宽。
    for (var i = drop; i < value.length; i++) {
      if (value.codeUnitAt(i) == 0x2F || value.codeUnitAt(i) == 0x5C) {
        drop = i + 1;
        break;
      }
    }
    return _ellipsis + value.substring(drop);
  }
}
