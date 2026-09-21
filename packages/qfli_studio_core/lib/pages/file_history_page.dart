import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../services/file_backup.dart';

/// 文件历史版本时间线：列出自动保存产生的同名备份，
/// 点击直接以只读方式打开进编辑器（标签带时间），可一键恢复到当前文件。
class FileHistoryPage extends StatelessWidget {
  const FileHistoryPage({
    super.key,
    required this.originalPath,
    required this.projectName,
    required this.projectPath,
    required this.onOpenVersion,
    required this.onRestored,
  });

  final String originalPath;

  /// 备份按项目名分目录，恢复/列表都要匹配同一项目。
  final String projectName;
  final String projectPath;

  /// 点击某版本：以只读标签打开进编辑器。
  final void Function(File backupFile, String timeLabel) onOpenVersion;

  /// 恢复完成（原文件内容已更新，编辑器应重新加载）。
  final Future<void> Function() onRestored;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final original = File(originalPath);
    final relative = p.isWithin(projectPath, originalPath)
        ? p.relative(originalPath, from: projectPath)
        : p.basename(originalPath);
    final fileName = p.basename(originalPath);
    return Scaffold(
      appBar: AppBar(title: const Text('历史版本')),
      body: FutureBuilder<List<BackupVersion>>(
        future: FileBackup.listVersions(original, projectName: projectName),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final versions = snapshot.data ?? const <BackupVersion>[];
          if (versions.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _FileInfoCard(
                  fileName: fileName,
                  relativePath: relative,
                  exists: original.existsSync(),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.history,
                        size: 56,
                        color:
                            scheme.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 12),
                      Text('暂无历史版本',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 6),
                      Text(
                        '开启自动保存后，每次覆盖写入前\n会自动备份一份带时间戳的版本',
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                              color: scheme.onSurfaceVariant,
                              height: 1.6,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: versions.length + 1,
            itemBuilder: (context, i) {
              if (i == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _FileInfoCard(
                    fileName: fileName,
                    relativePath: relative,
                    exists: original.existsSync(),
                  ),
                );
              }
              final v = versions[i - 1];
              final isLatest = i - 1 == 0;
              return _TimelineTile(
                version: v,
                isFirst: i - 1 == 0,
                isLast: i - 1 == versions.length - 1,
                badge: isLatest ? '最新' : null,
                onPreview: () {
                  Navigator.of(context).pop();
                  onOpenVersion(v.file, v.timeLabel);
                },
                onRestore: () => _restore(context, v, original),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _restore(
    BuildContext context,
    BackupVersion version,
    File original,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('恢复此版本？'),
        content: Text(
          '将把 ${version.timeFull} 的内容写回当前文件。\n'
          '恢复前会先备份当前内容，不会丢失。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('恢复'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await FileBackup.restoreVersion(
      version,
      original,
      projectName: projectName,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已恢复 ${version.timeLabel} 的内容')),
    );
    await onRestored();
    if (context.mounted) Navigator.of(context).pop();
  }
}

/// 顶部文件信息卡：文件名 + 相对路径 + 当前状态。
class _FileInfoCard extends StatelessWidget {
  const _FileInfoCard({
    required this.fileName,
    required this.relativePath,
    required this.exists,
  });

  final String fileName;
  final String relativePath;
  final bool exists;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card.filled(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.history,
                size: 22,
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    relativePath,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: exists
                    ? scheme.primaryContainer.withValues(alpha: 0.7)
                    : scheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                exists ? '当前文件存在' : '文件已删除',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: exists
                      ? scheme.onPrimaryContainer
                      : scheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({
    required this.version,
    required this.isFirst,
    required this.isLast,
    this.badge,
    required this.onPreview,
    required this.onRestore,
  });

  final BackupVersion version;
  final bool isFirst;
  final bool isLast;
  final String? badge;
  final VoidCallback onPreview;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // 时间线竖轨 + 卡片；操作按钮放在第二行，窄屏不会横向溢出。
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: Container(
                      width: 2,
                      color:
                          isFirst ? Colors.transparent : scheme.outlineVariant,
                    ),
                  ),
                ),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.primary,
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Container(
                      width: 2,
                      color: isLast ? Colors.transparent : scheme.outlineVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Card.filled(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            version.timeFull,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (badge != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.primaryContainer,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                badge!,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: scheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                          ],
                          const Spacer(),
                          Text(
                            '${(version.size / 1024).toStringAsFixed(1)} KB',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                            ),
                            onPressed: onPreview,
                            icon: const Icon(Icons.visibility_outlined,
                                size: 16),
                            label: const Text('打开预览'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.tonal(
                            style: FilledButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                            ),
                            onPressed: onRestore,
                            child: const Text('恢复'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
