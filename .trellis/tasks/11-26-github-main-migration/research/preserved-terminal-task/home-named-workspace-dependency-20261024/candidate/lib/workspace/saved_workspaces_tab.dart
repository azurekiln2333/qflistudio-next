import 'dart:io';

import 'package:flutter/material.dart';

import '../editor/retained_editor_host.dart';
import '../store/auth_store.dart';
import '../store/project_store.dart';
import '../store/settings_store.dart';
import 'saved_workspace.dart';
import 'workspace_dialogs.dart';
import 'workspace_store.dart';

/// Home tab listing explicitly saved workspaces.
///
/// Opening a workspace validates every member against the current project
/// registry and the filesystem. Missing members are reported and skipped, a
/// missing primary falls back to a surviving member, and an all-missing
/// workspace offers an actionable way to remove only its metadata.
class SavedWorkspacesTab extends StatefulWidget {
  const SavedWorkspacesTab({
    super.key,
    required this.store,
    required this.auth,
    required this.settings,
    this.workspaceStore,
  });

  final ProjectStore store;
  final AuthStore auth;
  final SettingsStore settings;
  final WorkspaceStore? workspaceStore;

  @override
  State<SavedWorkspacesTab> createState() => _SavedWorkspacesTabState();
}

class _SavedWorkspacesTabState extends State<SavedWorkspacesTab> {
  WorkspaceStore get _workspaces => widget.workspaceStore ?? WorkspaceStore.instance;

  @override
  void initState() {
    super.initState();
    _workspaces.load();
  }

  Future<void> _refresh() => _workspaces.load(force: true);

  Future<void> _open(SavedWorkspace workspace) async {
    // The card can hold a snapshot taken before a later session write (or
    // before the record was deleted). Always resolve the latest by id.
    if (!_workspaces.loaded) await _workspaces.load();
    if (!mounted) return;
    final latest = _workspaces.byId(workspace.id);
    if (latest == null) {
      // Deleted between build and tap: refresh and tell the user instead of
      // reopening a workspace whose record no longer exists (its session
      // writes would be a no-op).
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('该工作区记录已被删除，列表已刷新')),
      );
      return;
    }
    final resolution = await _workspaces.resolve(latest, widget.store);
    if (!mounted) return;
    if (resolution.isEmpty) {
      await _showAllMissing(resolution);
      return;
    }
    if (resolution.missing.isNotEmpty) {
      final proceed = await _confirmMissing(resolution);
      if (proceed != true || !mounted) return;
    }
    final primary = resolution.primary;
    if (primary == null) return;
    // Re-check after the dialogs: a delete can land while they are open.
    final current = _workspaces.byId(workspace.id);
    if (current == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('该工作区记录已被删除，未打开')),
      );
      return;
    }
    widget.store.touch(primary);
    await openEditorPage(
      context,
      project: primary,
      auth: widget.auth,
      store: widget.store,
      settings: widget.settings,
      // Hand the freshest document to the host, not the card's snapshot.
      workspace: current,
      workspaceProjects: resolution.projects,
      workspaceStore: widget.workspaceStore,
    );
  }

  Future<bool?> _confirmMissing(WorkspaceResolution resolution) {
    final names = resolution.missing
        .map((member) => '· ${member.name}\n  ${member.path}')
        .join('\n');
    final primary = resolution.primary;
    final fallback = resolution.primaryMissing && primary != null
        ? '\n\n主项目已缺失，将改用「${primary.name}」作为主项目打开。'
        : '';
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('部分项目不可用'),
        content: SingleChildScrollView(
          child: Text(
            '以下项目已被移除、删除或无法访问，打开工作区时会跳过：\n$names$fallback',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('继续打开'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAllMissing(WorkspaceResolution resolution) async {
    final names = resolution.missing
        .map((member) => '· ${member.name}\n  ${member.path}')
        .join('\n');
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('无法打开工作区'),
        content: SingleChildScrollView(
          child: Text(
            '工作区「${resolution.workspace.name}」中的项目都不可用：\n\n$names\n\n'
            '请重新添加这些项目，或删除这条工作区记录（不会删除任何项目文件夹）。',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'delete'),
            child: const Text('删除工作区记录'),
          ),
        ],
      ),
    );
    if (action != 'delete' || !mounted) return;
    if (!await confirmWorkspaceDelete(context, resolution.workspace)) return;
    await _removeWithRetry(resolution.workspace);
  }

  Future<void> _delete(SavedWorkspace workspace) async {
    if (!await confirmWorkspaceDelete(context, workspace)) return;
    await _removeWithRetry(workspace);
  }

  /// Metadata deletion can fail while the entry is retained. Surface the error
  /// with a retry action instead of pretending the workspace is gone.
  Future<void> _removeWithRetry(SavedWorkspace workspace) async {
    try {
      await _workspaces.remove(workspace.id);
    } on Object catch (error) {
      if (!mounted) return;
      final message = error is FileSystemException
          ? error.message
          : '$error';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('删除工作区记录失败：$message'),
          action: SnackBarAction(
            label: '重试',
            onPressed: () => _removeWithRetry(workspace),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _workspaces,
      builder: (context, _) {
        if (!_workspaces.loaded) {
          return const Center(child: CircularProgressIndicator());
        }
        final workspaces = _workspaces.workspaces;
        if (workspaces.isEmpty) {
          return RefreshIndicator(
            onRefresh: _refresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: const [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyWorkspaces(),
                ),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
            itemCount: workspaces.length,
            itemBuilder: (context, index) {
              final workspace = workspaces[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _WorkspaceCard(
                  workspace: workspace,
                  onOpen: () => _open(workspace),
                  onDelete: () => _delete(workspace),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _WorkspaceCard extends StatelessWidget {
  const _WorkspaceCard({
    required this.workspace,
    required this.onOpen,
    required this.onDelete,
  });

  final SavedWorkspace workspace;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: scheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          child: Row(
            children: [
              Icon(Icons.workspaces_outline, color: scheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      workspace.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${workspace.members.length} 个项目 · '
                      '更新于 ${_formatTime(workspace.updatedAt)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      workspace.members.map((member) => member.name).join('、'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: '工作区操作',
                icon: const Icon(Icons.more_vert),
                onSelected: (value) {
                  switch (value) {
                    case 'open':
                      onOpen();
                    case 'delete':
                      onDelete();
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'open',
                    child: Row(
                      children: [
                        Icon(Icons.open_in_new, size: 20),
                        SizedBox(width: 12),
                        Text('打开'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 20),
                        SizedBox(width: 12),
                        Text('删除工作区记录'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyWorkspaces extends StatelessWidget {
  const _EmptyWorkspaces();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.workspaces_outline,
              size: 64,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 16),
            Text('还没有保存的工作区', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              '打开任意项目，在编辑器的文件树中点击工作区按钮，即可把多个项目保存为一个工作区。',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatTime(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${local.year}/${local.month}/${local.day} '
      '${two(local.hour)}:${two(local.minute)}';
}
