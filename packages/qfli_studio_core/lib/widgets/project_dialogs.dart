import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../models/project.dart';
import '../services/app_paths.dart';
import '../services/file_service.dart';
import '../services/project_templates.dart';
import '../services/studio_profile.dart';
import '../store/project_store.dart';

/// 创建项目对话框的返回结果：新项目 + 建议自动打开的主文件。
typedef CreateProjectResult = ({Project project, String? openFile});

/// 显示“新建项目”对话框；成功创建后返回结果，取消返回 null。
Future<CreateProjectResult?> showCreateProjectDialog(
  BuildContext context,
  ProjectStore store,
) {
  return showDialog<CreateProjectResult>(
    context: context,
    builder: (_) => _CreateProjectDialog(store: store),
  );
}

/// 显示“添加现有项目”对话框；成功后返回该项目，取消返回 null。
Future<Project?> showAddExistingDialog(
  BuildContext context,
  ProjectStore store,
) {
  return showDialog<Project>(
    context: context,
    builder: (_) => _AddExistingDialog(store: store),
  );
}

/// 删除项目的确认对话框（先压缩备份到回收站，再删除文件夹）。
Future<bool> showDeleteProjectConfirm(
  BuildContext context,
  Project project,
) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('删除项目“${project.name}”？'),
      content: Text(
        '将先把项目文件夹压缩备份到应用数据回收站（recyclebin/projects_bin），'
        '然后从磁盘删除并移出列表。',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('删除'),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// 新建文件/文件夹时输入名称。
Future<String?> showNewNameDialog(
  BuildContext context, {
  required String title,
  required String actionLabel,
  required IconData actionIcon,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _NameDialog(
      title: title,
      actionLabel: actionLabel,
      actionIcon: actionIcon,
    ),
  );
}

/// 删除文件/文件夹的确认对话框（删除前自动压缩备份到回收站）。
Future<bool> showDeleteEntryConfirm(
  BuildContext context, {
  required String name,
  required bool isFolder,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('删除“$name”？'),
      content: Text(
        isFolder
            ? '文件夹及其全部内容将先压缩备份到应用数据回收站，然后从磁盘删除。'
            : '文件将先压缩备份到应用数据回收站，然后从磁盘删除。',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('删除'),
        ),
      ],
    ),
  );
  return result ?? false;
}

class _CreateProjectDialog extends StatefulWidget {
  const _CreateProjectDialog({required this.store});

  final ProjectStore store;

  @override
  State<_CreateProjectDialog> createState() => _CreateProjectDialogState();
}

class _CreateProjectDialogState extends State<_CreateProjectDialog> {
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  String? _error;
  bool _creating = false;
  final bool _desktop = AppPaths.isDesktop;
  bool _locationResolved = false;
  ProjectTemplate _template = defaultTemplate();

  /// 语言专属 App 只列出自己那一门语言的模板。
  List<ProjectTemplate> get _availableTemplates => availableTemplates();

  @override
  void initState() {
    super.initState();
    _initDefaultLocation();
  }

  Future<void> _initDefaultLocation() async {
    // 默认在应用数据目录的 projects/ 下创建项目。
    final dir = await AppPaths.projectsRoot(create: true);
    if (!mounted) return;
    setState(() {
      _locationController.text = dir ?? '';
      _locationResolved = true;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  String get _fullPath {
    final location = _locationController.text.trim();
    final name = _nameController.text.trim();
    if (location.isEmpty && name.isEmpty) return '';
    if (location.isEmpty) return name;
    return p.join(location, name);
  }

  bool get _canSubmit {
    if (_creating) return false;
    if (_nameController.text.trim().isEmpty) return false;
    final location = _locationController.text.trim();
    return location.isNotEmpty;
  }

  Future<void> _pickLocation() async {
    String? dir;
    try {
      dir = await getDirectoryPath();
    } catch (_) {
      // 当前平台不支持目录选择器时保持输入框方式。
    }
    if (dir == null || !mounted) return;
    final picked = dir;
    setState(() => _locationController.text = picked);
  }

  Future<void> _submit() async {
    if (_creating) return;
    setState(() {
      _creating = true;
      _error = null;
    });
    final result = await widget.store.createProject(
      name: _nameController.text,
      location: _locationController.text,
      template: _template,
    );
    if (!mounted) return;
    if (result.error != null) {
      setState(() {
        _error = result.error;
        _creating = false;
      });
      return;
    }
    Navigator.of(
      context,
    ).pop((project: result.project!, openFile: _template.mainFile));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final location = _locationController.text.trim();
    final noWritableDir = !_desktop && _locationResolved && location.isEmpty;
    return AlertDialog(
      title: const Text('新建项目'),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              textInputAction: _desktop
                  ? TextInputAction.next
                  : TextInputAction.done,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) {
                if (!_desktop) _submit();
              },
              decoration: const InputDecoration(
                labelText: '项目名称',
                prefixIcon: Icon(Icons.label_outline),
              ),
            ),
            const SizedBox(height: 16),
            DropdownMenu<ProjectTemplate>(
              initialSelection: _template,
              expandedInsets: EdgeInsets.zero,
              label: const Text('项目类型'),
              onSelected: (value) {
                if (value != null) setState(() => _template = value);
              },
              dropdownMenuEntries: [
                for (final template in _availableTemplates)
                  DropdownMenuEntry(
                    value: template,
                    label: template.label,
                    leadingIcon: Icon(template.icon, size: 20),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_desktop) ...[
              TextField(
                controller: _locationController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: '位置',
                  helperText: '将在此目录下创建同名文件夹',
                  prefixIcon: const Icon(Icons.folder_open_outlined),
                  suffixIcon: IconButton(
                    tooltip: '选择目录',
                    onPressed: _pickLocation,
                    icon: const Icon(Icons.folder_outlined),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.subdirectory_arrow_right,
                    size: 16,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _fullPath.isEmpty ? '—' : _fullPath,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              Row(
                children: [
                  Icon(
                    Icons.folder_special_outlined,
                    size: 16,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      noWritableDir
                          ? '未找到可写目录'
                          : (location.isEmpty ? '正在查找可写目录…' : '将创建到：$location'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              if (noWritableDir) ...[
                const SizedBox(height: 8),
                Text(
                  '当前环境没有可写目录，无法在此设备上创建项目',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: scheme.error),
                ),
              ],
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: scheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton.icon(
          onPressed: _canSubmit ? _submit : null,
          icon: const Icon(Icons.create_new_folder_outlined),
          label: const Text('创建'),
        ),
      ],
    );
  }
}

class _AddExistingDialog extends StatefulWidget {
  const _AddExistingDialog({required this.store});

  final ProjectStore store;

  @override
  State<_AddExistingDialog> createState() => _AddExistingDialogState();
}

class _AddExistingDialogState extends State<_AddExistingDialog> {
  final _pathController = TextEditingController();
  String? _error;
  bool _adding = false;

  @override
  void dispose() {
    _pathController.dispose();
    super.dispose();
  }

  Future<void> _pickFolder() async {
    String? dir;
    try {
      dir = await getDirectoryPath();
    } catch (_) {
      // 当前平台不支持目录选择器时保持输入框方式。
    }
    if (dir == null || !mounted) return;
    final picked = dir;
    setState(() => _pathController.text = picked);
  }

  Future<void> _submit() async {
    if (_adding) return;
    setState(() {
      _adding = true;
      _error = null;
    });
    final result = await widget.store.addExisting(_pathController.text);
    if (!mounted) return;
    if (result.error != null) {
      setState(() {
        _error = result.error;
        _adding = false;
      });
      return;
    }
    Navigator.of(context).pop(result.project);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('添加现有项目'),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _pathController,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: '项目文件夹路径',
                helperText: '选择或输入一个已有的文件夹',
                prefixIcon: const Icon(Icons.folder_open_outlined),
                suffixIcon: IconButton(
                  tooltip: '选择目录',
                  onPressed: _pickFolder,
                  icon: const Icon(Icons.folder_outlined),
                ),
                errorText: _error,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton.icon(
          onPressed: _adding ? null : _submit,
          icon: const Icon(Icons.drive_file_move_outlined),
          label: const Text('添加'),
        ),
      ],
    );
  }
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({
    required this.title,
    required this.actionLabel,
    required this.actionIcon,
  });

  final String title;
  final String actionLabel;
  final IconData actionIcon;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (!FileService.isValidEntryName(name)) {
      setState(() => _error = '名称不能为空，且不能包含 \\ / : * ? " < > | 等字符');
      return;
    }
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          labelText: '名称',
          prefixIcon: const Icon(Icons.edit_outlined),
          errorText: _error,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: Icon(widget.actionIcon),
          label: Text(widget.actionLabel),
        ),
      ],
    );
  }
}
