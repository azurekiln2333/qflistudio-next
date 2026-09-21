import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../models/project.dart';
import '../store/project_store.dart';
import '../services/file_service.dart';
import '../editor/new_file_dialog.dart';
import '../store/settings_store.dart';
import '../editor/project_history.dart';
import '../pages/file_history_page.dart';
import '../services/recycle_bin.dart';
import '../services/picker_service.dart';
import '../services/resource_import_service.dart';
import '../i18n/studio_localizations.dart';
import '../widgets/project_dialogs.dart';
import 'editor_controller.dart';

class FileNode {
  const FileNode({required this.path, required this.name, required this.isDir});

  final String path;
  final String name;
  final bool isDir;
}

/// 编辑器左侧的文件树面板（宽度由外层容器约束）。
class FileExplorer extends StatefulWidget {
  const FileExplorer({
    super.key,
    required this.project,
    required this.editor,
    required this.store,
    required this.settings,
    this.onFileOpened,
    this.onEntryDeleted,
  });

  final Project project;
  final EditorController editor;

  /// 项目设置（新建文件的自定义后缀）。
  final SettingsStore settings;

  /// 全部项目列表（跨项目浏览用）。
  final ProjectStore store;

  /// 文件/文件夹被删除后的回调（云端项目推送删除）。
  final ValueChanged<String>? onEntryDeleted;

  /// 文件成功打开后的回调（抽屉模式下用于自动关闭抽屉）。
  final VoidCallback? onFileOpened;

  /// 项目内按名称递归搜索文件（跳过 .git/node_modules/build 等重目录）。
  static List<FileNode> searchFiles(String rootPath, String query) {
    final results = <FileNode>[];
    final keyword = query.trim().toLowerCase();
    if (keyword.isEmpty) return results;
    const skipDirs = {'.git', 'node_modules', 'build', '.dart_tool', '.idea'};
    void walk(Directory dir) {
      if (results.length >= 200) return;
      List<FileSystemEntity> entries;
      try {
        entries = dir.listSync(followLinks: false);
      } on FileSystemException {
        return;
      }
      entries.sort((a, b) => p
          .basename(a.path)
          .toLowerCase()
          .compareTo(p.basename(b.path).toLowerCase()));
      for (final e in entries) {
        final name = p.basename(e.path);
        if (e is Directory) {
          if (skipDirs.contains(name) || name.startsWith('.')) continue;
          walk(e);
        } else if (name.toLowerCase().contains(keyword)) {
          results.add(FileNode(path: e.path, name: name, isDir: false));
          if (results.length >= 200) return;
        }
      }
    }

    walk(Directory(rootPath));
    return results;
  }


    @override
  State<FileExplorer> createState() => _FileExplorerState();
}

class _FileExplorerState extends State<FileExplorer> {
  final Map<String, List<FileNode>> _children = {};
  final Set<String> _expanded = {};
  final TextEditingController _searchController = TextEditingController();
  bool _searchOpen = false;
  String _searchQuery = '';
  late Project _browsing;
  late FileNode _root;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // 恢复上次浏览的项目（失效则回落到当前项目）。
    final remembered = widget.store.projectById(
      widget.store.lastBrowsedProjectId,
    );
    _browsing = (remembered != null && Directory(remembered.path).existsSync())
        ? remembered
        : widget.project;
    _rebuildRoot();
  }

  void _rebuildRoot() {
    _root = FileNode(path: _browsing.path, name: _browsing.name, isDir: true);
    _children.clear();
    _expanded
      ..clear()
      ..add(_root.path);
    _loadChildren(_root);
  }

  /// 跨项目浏览：切换文件树根目录。
  void _switchProject(Project project) {
    if (identical(project, _browsing) || project.path == _browsing.path) {
      return;
    }
    setState(() => _browsing = project);
    widget.store.setBrowsedProject(project);
    _rebuildRoot();
    _restoreExpanded();
  }

  /// 恢复上次展开的目录（来自项目内 history.json）。
  Future<void> _restoreExpanded() async {
    final session = await ProjectHistory.load(_browsing.path);
    if (!mounted) return;
    for (final rel in session.expandedDirs) {
      final abs = p.isAbsolute(rel) ? rel : p.join(_browsing.path, rel);
      if (!Directory(abs).existsSync()) continue;
      _expanded.add(abs);
      if (!_children.containsKey(abs)) {
        unawaited(_loadChildren(FileNode(
          path: abs,
          name: p.basename(abs),
          isDir: true,
        )));
      }
    }
    if (mounted) setState(() {});
  }

  /// 展开状态持久化（相对浏览项目根目录）。
  Future<void> _persistExpanded() async {
    final dirs = _expanded
        .where((path) => p.isWithin(_browsing.path, path))
        .map(
          (path) =>
              p.relative(path, from: _browsing.path).replaceAll(r'\', '/'),
        )
        .toList();
    await ProjectHistory.saveExpandedDirs(_browsing.path, dirs);
  }

  List<FileNode> _childrenOf(FileNode dir) => _children[dir.path] ?? const [];

  /// 打开搜索命中的文件（成功后收起侧栏/抽屉，与树内打开一致）。
  Future<void> _openSearchResult(String path) async {
    final error = await widget.editor.openPath(
      path,
      ownerProjectName: _browsing.name,
      ownerProjectPath: _browsing.path,
    );
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    widget.onFileOpened?.call();
  }

  Future<void> _loadChildren(FileNode dir) async {
    List<FileNode> nodes = const [];
    try {
      nodes = [
        for (final entity in FileService.listSortedSync(dir.path))
          FileNode(
            path: entity.path,
            name: p.basename(entity.path),
            isDir: entity is Directory,
          ),
      ];
    } on FileSystemException {
      nodes = const [];
    }
    if (!mounted) return;
    setState(() => _children[dir.path] = nodes);
  }

  Future<void> _refresh() async {
    _children.clear();
    await _loadChildren(_root);
    for (final path in _expanded.toList()) {
      if (path == _root.path) continue;
      await _loadChildren(
        FileNode(path: path, name: p.basename(path), isDir: true),
      );
    }
  }

  Future<void> _importResources(FileNode directory, {required bool photos}) async {
    final documents = <PickedDocument>[];
    if (photos) {
      documents.addAll(await PickerService.pickPhotos());
    } else {
      final document = await PickerService.pickDocument(extensions: const []);
      if (document != null) documents.add(document);
    }
    if (documents.isEmpty || !mounted) return;
    final l = StudioLocalizations.of(context);
    final result = await ResourceImportService.importDocuments(
      documents: documents,
      destinationDirectory: directory.path,
      resolveConflict: (name) async =>
          await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(l.replaceExistingResource),
              content: Text(l.replaceResourceMessage(name)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(l.cancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(l.replaceResource),
                ),
              ],
            ),
          ) ??
          false,
    );
    if (!mounted) return;
    await _refresh();
    if (!mounted) return;
    if (result.imported > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.importFinished(result.imported))),
      );
    }
    if (result.errors.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l.importFailed}${result.errors.join('; ')}')),
      );
    }
  }

  void _toggle(FileNode node) {
    if (_expanded.remove(node.path)) {
      setState(() {});
      unawaited(_persistExpanded());
      return;
    }
    _expanded.add(node.path);
    if (!_children.containsKey(node.path)) _loadChildren(node);
    setState(() {});
    unawaited(_persistExpanded());
  }

  Future<void> _openFile(FileNode node) async {
    final error = await widget.editor.openPath(
      node.path,
      ownerProjectName: _browsing.name,
      ownerProjectPath: _browsing.path,
    );
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    widget.onFileOpened?.call();
  }

  Future<void> _create(FileNode? dirNode, bool isDir) async {
    final dirPath = dirNode?.path ?? _root.path;
    final String? name;
    if (isDir) {
      name = await showNewNameDialog(
        context,
        title: '新建文件夹',
        actionLabel: '创建',
        actionIcon: Icons.create_new_folder_outlined,
      );
    } else {
      name = await showNewFileDialog(
        context,
        settings: widget.settings,
        projectLanguage: widget.project.language,
      );
    }
    if (name == null || !mounted) return;
    final path = p.join(dirPath, name);
    if (Directory(path).existsSync() || File(path).existsSync()) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('“$name”已存在')));
      return;
    }
    try {
      if (isDir) {
        await Directory(path).create();
      } else {
        await File(path).writeAsString('');
      }
    } on FileSystemException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('创建失败：${e.message}')));
      }
      return;
    }
    _expanded.add(dirPath);
    await _loadChildren(
      FileNode(path: dirPath, name: p.basename(dirPath), isDir: true),
    );
    if (!isDir) {
      _openFile(FileNode(path: path, name: name, isDir: false));
    }
  }

  Future<void> _delete(FileNode node) async {
    final confirmed = await showDeleteEntryConfirm(
      context,
      name: node.name,
      isFolder: node.isDir,
    );
    if (!confirmed || !mounted) return;
    // 先压缩备份到回收站 files_bin，失败则中止删除。
    final backupError = await RecycleBin.backupEntry(
      node.isDir ? Directory(node.path) : File(node.path),
      projectName: _browsing.name,
    );
    if (backupError != null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('已取消删除：$backupError')));
      }
      return;
    }
    try {
      final entity = node.isDir
          ? Directory(node.path)
          : File(node.path) as FileSystemEntity;
      await entity.delete(recursive: true);
    } on FileSystemException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('删除失败：${e.message}')));
      }
      return;
    }
    widget.editor.closePathsUnder(node.path);
    widget.onEntryDeleted?.call(node.path);
    final parentPath = p.dirname(node.path);
    await _loadChildren(
      FileNode(path: parentPath, name: p.basename(parentPath), isDir: true),
    );
  }

  void _showMenu(FileNode node, Offset position) {
    final isRoot = node.path == _root.path;
    final l = StudioLocalizations.of(context);
    final items = <PopupMenuEntry<String>>[
      if (!node.isDir)
        const PopupMenuItem(
          value: 'open',
          child: Row(
            children: [
              Icon(Icons.open_in_new, size: 18),
              SizedBox(width: 10),
              Text('打开'),
            ],
          ),
        ),
      if (node.isDir) ...[
        PopupMenuItem(
          value: 'import_resource',
          child: Row(
            children: [
              const Icon(Icons.file_upload_outlined, size: 18),
              const SizedBox(width: 10),
              Text(l.importResource),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'import_photo',
          child: Row(
            children: [
              const Icon(Icons.photo_library_outlined, size: 18),
              const SizedBox(width: 10),
              Text(l.importPhoto),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'new_file',
          child: Row(
            children: [
              Icon(Icons.note_add_outlined, size: 18),
              SizedBox(width: 10),
              Text('新建文件'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'new_folder',
          child: Row(
            children: [
              Icon(Icons.create_new_folder_outlined, size: 18),
              SizedBox(width: 10),
              Text('新建文件夹'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'refresh',
          child: Row(
            children: [
              Icon(Icons.refresh, size: 18),
              SizedBox(width: 10),
              Text('刷新'),
            ],
          ),
        ),
      ],
      if (!node.isDir)
        const PopupMenuItem(
          value: 'history',
          child: Row(
            children: [
              Icon(Icons.history, size: 18),
              SizedBox(width: 10),
              Text('历史版本'),
            ],
          ),
        ),
      if (!isRoot)
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 18),
              SizedBox(width: 10),
              Text('删除'),
            ],
          ),
        ),
    ];
    if (items.isEmpty) return;
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1,
        position.dy + 1,
      ),
      items: items,
    ).then((value) {
      if (value == null || !mounted) return;
      switch (value) {
        case 'open':
          _openFile(node);
        case 'new_file':
          _create(node, false);
        case 'new_folder':
          _create(node, true);
        case 'import_resource':
          _importResources(node, photos: false);
        case 'import_photo':
          _importResources(node, photos: true);
        case 'refresh':
          _loadChildren(node);
        case 'delete':
          _delete(node);
        case 'history':
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => FileHistoryPage(
                originalPath: node.path,
                projectName: widget.project.name,
                projectPath: widget.project.path,
                onOpenVersion: (backupFile, timeLabel) {
                  widget.editor
                      .openPath(
                        backupFile.path,
                        ownerProjectName: widget.project.name,
                        ownerProjectPath: widget.project.path,
                        readOnly: true,
                        timeLabel: timeLabel,
                      )
                      .then((error) {
                    if (error != null && mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text(error)));
                    }
                  });
                },
                onRestored: () async {
                  // 恢复后刷新原文件内容（已打开的普通标签）。
                  final idx = widget.editor.files
                      .indexWhere((f) => p.equals(f.path, node.path));
                  if (idx >= 0 && !widget.editor.files[idx].readOnly) {
                    widget.editor.files[idx].controller.text =
                        await File(node.path).readAsString();
                  }
                },
              ),
            ),
          );
      }
    });
  }

  Widget _buildSearchResults(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final results =
        FileExplorer.searchFiles(_browsing.path, _searchQuery);
    if (results.isEmpty) {
      return Center(
        child: Text(
          '没有匹配的文件',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: results.length,
      itemBuilder: (context, i) {
        final node = results[i];
        final rel = p.isWithin(_browsing.path, node.path)
            ? p.relative(node.path, from: _browsing.path)
            : node.path;
        return ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          leading: Icon(
            FileService.iconForFile(node.name),
            size: 18,
            color: scheme.onSurfaceVariant,
          ),
          title: Text(
            node.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          subtitle: Text(
            rel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          onTap: () => _openSearchResult(node.path),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: scheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 48,
            child: Row(
              children: [
                const SizedBox(width: 8),
                Expanded(
                  child: PopupMenuButton<Project>(
                  tooltip: '切换项目（跨项目打开文件）',
                  onSelected: _switchProject,
                  itemBuilder: (context) => [
                    for (final p in widget.store.projects)
                      PopupMenuItem(
                        value: p,
                        child: Row(
                          children: [
                            Icon(
                              p.isCloud
                                  ? Icons.cloud_outlined
                                  : Icons.folder_outlined,
                              size: 18,
                              color: p.path == _browsing.path
                                  ? scheme.primary
                                  : scheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                p.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (p.path == _browsing.path)
                              Icon(
                                Icons.check,
                                size: 16,
                                color: scheme.primary,
                              ),
                          ],
                        ),
                      ),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest.withValues(
                        alpha: 0.5,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            _browsing.name,
                            style: Theme.of(context).textTheme.labelLarge,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down, size: 18),
                      ],
                    ),
                  ),
                ),
                ),
                IconButton(
                  tooltip: '新建文件',
                  icon: const Icon(Icons.note_add_outlined, size: 20),
                  onPressed: () => _create(null, false),
                ),
                IconButton(
                  tooltip: '新建文件夹',
                  icon: const Icon(Icons.create_new_folder_outlined, size: 20),
                  onPressed: () => _create(null, true),
                ),
                IconButton(
                  tooltip: _searchOpen ? '退出搜索' : '搜索文件',
                  icon: Icon(_searchOpen ? Icons.close : Icons.search),
                  onPressed: () {
                    setState(() {
                      _searchOpen = !_searchOpen;
                      _searchQuery = '';
                      _searchController.clear();
                    });
                  },
                ),
                IconButton(
                  tooltip: '刷新',
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: _refresh,
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: scheme.outlineVariant),
          if (_searchOpen)
            Padding(
              padding: const EdgeInsets.all(8),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                style: Theme.of(context).textTheme.bodyMedium,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: '按文件名搜索（含子目录）',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
            ),
          Expanded(
            child: _searchOpen && _searchQuery.trim().isNotEmpty
                ? _buildSearchResults(context)
                : GestureDetector(
              behavior: HitTestBehavior.translucent,
              onSecondaryTapUp: (details) =>
                  _showMenu(_root, details.globalPosition),
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _buildRow(context, _root, 0),
                  if (_expanded.contains(_root.path))
                    for (final node in _childrenOf(_root))
                      _buildNode(context, node, 1),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNode(BuildContext context, FileNode node, int depth) {
    final expanded = node.isDir && _expanded.contains(node.path);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildRow(context, node, depth),
        if (expanded)
          for (final child in _childrenOf(node))
            _buildNode(context, child, depth + 1),
      ],
    );
  }

  Widget _buildRow(BuildContext context, FileNode node, int depth) {
    final scheme = Theme.of(context).colorScheme;
    final selected = !node.isDir && widget.editor.current?.path == node.path;
    final dirty = !node.isDir && widget.editor.isDirty(node.path);
    final row = GestureDetector(
      onLongPressStart: (details) => _showMenu(node, details.globalPosition),
      child: Ink(
        decoration: BoxDecoration(
          color: selected
              ? scheme.surfaceContainerHighest.withValues(alpha: 0.6)
              : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: InkWell(
          onTap: () {
            if (node.isDir) {
              _toggle(node);
            } else {
              _openFile(node);
            }
          },
          onSecondaryTapUp: (details) =>
              _showMenu(node, details.globalPosition),
          child: SizedBox(
            height: 34,
            child: Row(
              children: [
                SizedBox(width: 8.0 + depth * 18.0),
                if (node.isDir)
                  Icon(
                    _expanded.contains(node.path)
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_right,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  )
                else
                  const SizedBox(width: 18),
                const SizedBox(width: 2),
                Icon(
                  node.isDir
                      ? (_expanded.contains(node.path)
                            ? Icons.folder_open
                            : Icons.folder_outlined)
                      : FileService.iconForFile(node.name),
                  size: 18,
                  color: node.isDir ? scheme.primary : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    node.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: depth == 0 ? FontWeight.w600 : null,
                      color: node.isDir
                          ? scheme.onSurface
                          : (selected
                                ? scheme.onSurface
                                : scheme.onSurfaceVariant),
                    ),
                  ),
                ),
                if (dirty)
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: scheme.primary,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: row,
    );
  }
}
