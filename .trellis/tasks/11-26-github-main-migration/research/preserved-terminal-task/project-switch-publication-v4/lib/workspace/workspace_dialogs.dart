import 'dart:io';

import 'package:flutter/material.dart';

import '../models/project.dart';
import '../store/project_store.dart';
import 'saved_workspace.dart';
import 'workspace_store.dart';

/// Result of the workspace editor dialog.
class WorkspaceDialogResult {
  const WorkspaceDialogResult.saved(SavedWorkspace this.workspace)
    : deleted = false;

  const WorkspaceDialogResult.deleted() : workspace = null, deleted = true;

  final SavedWorkspace? workspace;
  final bool deleted;
}

/// Opens the explicit workspace management/save dialog.
///
/// Works even when the project registry currently holds a single project: the
/// workspace can still be named and saved so it can be reopened from Home.
Future<WorkspaceDialogResult?> showWorkspaceEditorDialog(
  BuildContext context, {
  required WorkspaceStore workspaceStore,
  required ProjectStore projectStore,
  required Project primary,
  required List<Project> members,
  SavedWorkspace? saved,
}) async {
  await workspaceStore.load();
  if (!context.mounted) return null;
  return showDialog<WorkspaceDialogResult>(
    context: context,
    builder: (_) => _WorkspaceEditorDialog(
      workspaceStore: workspaceStore,
      projectStore: projectStore,
      primary: primary,
      members: members,
      saved: saved,
    ),
  );
}

Future<bool> confirmWorkspaceDelete(
  BuildContext context,
  SavedWorkspace workspace,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('删除工作区记录'),
      content: Text(
        '将从列表中删除工作区「${workspace.name}」。\n\n'
        '只会删除工作区记录，不会删除其中任何项目文件夹或项目内的文件。',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('删除记录'),
        ),
      ],
    ),
  );
  return confirmed == true;
}

class _WorkspaceEditorDialog extends StatefulWidget {
  const _WorkspaceEditorDialog({
    required this.workspaceStore,
    required this.projectStore,
    required this.primary,
    required this.members,
    required this.saved,
  });

  final WorkspaceStore workspaceStore;
  final ProjectStore projectStore;
  final Project primary;
  final List<Project> members;
  final SavedWorkspace? saved;

  @override
  State<_WorkspaceEditorDialog> createState() => _WorkspaceEditorDialogState();
}

class _WorkspaceEditorDialogState extends State<_WorkspaceEditorDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.saved?.name ?? '${widget.primary.name} 工作区',
  );
  late final Set<String> _selected = {
    workspacePathKey(widget.primary.path),
    for (final project in widget.members)
      if (!project.isCloud) workspacePathKey(project.path),
  };
  bool _saving = false;
  String? _error;

  List<Project> get _localProjects {
    final projects = <Project>[
      for (final project in widget.projectStore.projects)
        if (!project.isCloud) project,
    ];
    if (!projects.any(
      (project) =>
          workspacePathKey(project.path) == workspacePathKey(widget.primary.path),
    )) {
      projects.insert(0, widget.primary);
    }
    return projects;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = '请输入工作区名称');
      return;
    }
    final primaryKey = workspacePathKey(widget.primary.path);
    final selectedProjects = [
      widget.primary,
      for (final project in _localProjects)
        if (workspacePathKey(project.path) != primaryKey &&
            _selected.contains(workspacePathKey(project.path)))
          project,
    ];
    // Deduplicate while keeping the primary first.
    final seen = <String>{};
    final ordered = <Project>[];
    for (final project in selectedProjects) {
      if (seen.add(workspacePathKey(project.path))) ordered.add(project);
    }
    if (ordered.isEmpty) {
      setState(() => _error = '至少选择一个项目');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final result = await widget.workspaceStore.save(
      existing: widget.saved,
      name: name,
      members: ordered,
      primary: widget.primary,
    );
    if (!mounted) return;
    if (result.error != null || result.workspace == null) {
      setState(() {
        _saving = false;
        _error = result.error ?? '保存工作区失败';
      });
      return;
    }
    Navigator.pop(context, WorkspaceDialogResult.saved(result.workspace!));
  }

  Future<void> _delete() async {
    final saved = widget.saved;
    if (saved == null || _saving) return;
    if (!await confirmWorkspaceDelete(context, saved)) return;
    if (!mounted) return;
    try {
      await widget.workspaceStore.remove(saved.id);
    } on Object catch (error) {
      if (!mounted) return;
      final message = error is FileSystemException
          ? error.message
          : '$error';
      // Keep the dialog open and retryable; the workspace record still exists.
      setState(() => _error = '删除工作区记录失败：$message（可重试）');
      return;
    }
    if (!mounted) return;
    Navigator.pop(context, const WorkspaceDialogResult.deleted());
  }

  @override
  Widget build(BuildContext context) {
    final primaryKey = workspacePathKey(widget.primary.path);
    return AlertDialog(
      scrollable: true,
      title: Text(widget.saved == null ? '保存工作区' : '工作区设置'),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const ValueKey('workspace-name-field'),
              controller: _name,
              autofocus: true,
              maxLength: 60,
              decoration: const InputDecoration(
                labelText: '工作区名称',
                hintText: '例如：桌面工具集',
              ),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 4),
            Text(
              '选择此工作区包含的本地项目。工作区只会记录项目引用，'
              '不会移动或删除项目文件。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            // AlertDialog owns scrolling, including when the keyboard opens.
            // Its OHOS intrinsic measurement cannot query a ListView viewport.
            for (final project in _localProjects)
              CheckboxListTile(
                key: ValueKey('workspace-project-${project.id}'),
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(
                  project.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  project.path,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                value:
                    workspacePathKey(project.path) == primaryKey ||
                    _selected.contains(workspacePathKey(project.path)),
                onChanged: workspacePathKey(project.path) == primaryKey
                    ? null
                    : (value) => setState(() {
                        final key = workspacePathKey(project.path);
                        if (value == true) {
                          _selected.add(key);
                        } else {
                          _selected.remove(key);
                        }
                      }),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
      actions: [
        if (widget.saved != null)
          TextButton(
            onPressed: _saving ? null : _delete,
            child: const Text('删除工作区记录'),
          ),
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.saved == null ? '保存' : '应用'),
        ),
      ],
    );
  }
}
