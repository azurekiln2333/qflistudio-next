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
import '../workspace/editor_workspace.dart';
import '../workspace/saved_workspace.dart';
import '../workspace/workspace_dialogs.dart';
import '../workspace/workspace_store.dart';
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
    this.outlined = true,
    this.workspace,
    this.workspaceMembers = const [],
    this.workspaceStore,
    this.onWorkspaceChanged,
    this.onProjectSelected,
  });

  /// 是否由本组件自绘 MD3 outlined 卡片外观（圆角 + 细描边）。
  ///
  /// 设为 false 时仅渲染内容，外观交给外层容器（例如抽屉里的自定义卡片）。
  final bool outlined;

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

  /// Explicitly saved workspace this editor session belongs to, if any.
  ///
  /// Null means a standalone project open: the tree shows only [project] and
  /// never restores another project's workspace membership.
  final SavedWorkspace? workspace;

  /// Resolved surviving members of [workspace], including [project].
  final List<Project> workspaceMembers;

  /// Store used when the user saves or updates a workspace from the tree.
  final WorkspaceStore? workspaceStore;

  /// Reports workspace metadata or tree-expansion changes back to the editor so
  /// the session can be persisted into the workspace document (not history).
  final ValueChanged<EditorWorkspaceState>? onWorkspaceChanged;

  /// Opens an external project in its own editor session.
  final ValueChanged<Project>? onProjectSelected;

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
      entries.sort(
        (a, b) => p
            .basename(a.path)
            .toLowerCase()
            .compareTo(p.basename(b.path).toLowerCase()),
      );
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
  int _treeGeneration = 0;
  Future<void>? _restoring;
  List<Project> _workspaceProjects = [];
  SavedWorkspace? _savedWorkspace;
  Map<String, List<String>> _workspaceExpandedDirs = {};
  Map<String, bool> _workspaceRootExpanded = {};

  WorkspaceStore get _workspaceStore =>
      widget.workspaceStore ?? WorkspaceStore.instance;

  List<Project> get _workspace => [
    if (_savedWorkspace != null) widget.project else _browsing,
    for (final project in _workspaceProjects)
      if (!p.equals(
        project.path,
        _savedWorkspace != null ? widget.project.path : _browsing.path,
      )) project,
  ];

  List<FileNode> get _roots => [
    for (final project in _workspace)
      FileNode(path: project.path, name: project.name, isDir: true),
  ];

  Project _ownerOf(String path) {
    var owner = _browsing;
    var longestRoot = -1;
    for (final project in _workspace) {
      if ((p.equals(project.path, path) || p.isWithin(project.path, path)) &&
          project.path.length > longestRoot) {
        owner = project;
        longestRoot = project.path.length;
      }
    }
    return owner;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _applyWorkspaceState();
    // 恢复上次浏览的项目（失效则回落到当前项目）。
    // 先乐观地用记住的项目建树，再用异步校验纠正：`existsSync` 会在这里
    // 阻塞首帧，而这个判断只是选择根目录，不值得卡住动画。
    final remembered = widget.workspace != null || isMainStudioRelease
        ? null
        : widget.store.projectById(widget.store.lastBrowsedProjectId);
    _browsing = remembered ?? widget.project;
    _rebuildRoot();
    if (_savedWorkspace == null && !isMainStudioRelease) {
      // Legacy language-product behavior: an offline App's multi-root
      // membership still lives in that project's history.
      unawaited(_restoreLegacyWorkspace());
    }
    if (remembered != null && remembered.path != widget.project.path) {
      unawaited(_verifyBrowsing(remembered));
    }
  }

  @override
  void didUpdateWidget(covariant FileExplorer oldWidget) {
    super.didUpdateWidget(oldWidget);
    final workspaceChanged = oldWidget.workspace?.id != widget.workspace?.id;
    final primaryChanged = !p.equals(
      oldWidget.project.path,
      widget.project.path,
    );
    final membersChanged = !_sameProjectPaths(
      oldWidget.workspaceMembers,
      widget.workspaceMembers,
    );
    if (!workspaceChanged && !membersChanged && !primaryChanged) return;
    if (!workspaceChanged) {
      // Capture the outgoing live roots before the member list/primary moves,
      // otherwise the rebuild restores an already-cleared expansion state.
      _captureWorkspaceExpansion();
    }
    if (workspaceChanged) {
      _applyWorkspaceState();
      _browsing = widget.project;
    } else {
      _savedWorkspace = widget.workspace;
      _workspaceProjects = [
        for (final project in widget.workspaceMembers)
          if (!p.equals(project.path, widget.project.path)) project,
      ];
    }
    // The browsed root must stay a member: when the old primary A disappears
    // and the effective primary becomes B, browsing must follow to B instead
    // of keeping a root that is no longer part of the workspace.
    //
    // Membership comes from the resolved widget membership only. Deriving it
    // from `_workspace`/`_workspaceMembersOrdered` would be circular: those
    // include `_browsing`, so the stale root A would always look allowed.
    final allowed = [
      widget.project,
      ..._workspaceProjects,
    ];
    if (!allowed.any((project) => p.equals(project.path, _browsing.path))) {
      _browsing = widget.project;
    }
    setState(_rebuildRoot);
  }

  static bool _sameProjectPaths(List<Project> a, List<Project> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!p.equals(a[i].path, b[i].path)) return false;
    }
    return true;
  }

  void _applyWorkspaceState() {
    _workspaceSelectionRevision++;
    _savedWorkspace = widget.workspace;
    _workspaceProjects = [
      for (final project in widget.workspaceMembers)
        if (!p.equals(project.path, widget.project.path)) project,
    ];
    final expanded =
        widget.workspace?.session.expandedDirs ??
        const <String, List<String>>{};
    _workspaceExpandedDirs = {
      for (final entry in expanded.entries)
        entry.key: List<String>.of(entry.value),
    };
    _workspaceRootExpanded = {...?widget.workspace?.session.rootExpanded};
  }

  /// 校验记住的项目目录是否还在，已失效则回落到当前项目。
  Future<void> _verifyBrowsing(Project remembered) async {
    final generation = _treeGeneration;
    final exists = await Directory(remembered.path).exists();
    if (!mounted || generation != _treeGeneration || exists) return;
    setState(() => _browsing = widget.project);
    _rebuildRoot();
  }

  /// Guards legacy `history.json` membership restoration against a dialog that
  /// applied a newer selection while the load/stat work was still in flight.
  int _workspaceSelectionRevision = 0;

  /// Restores the legacy (language-product) membership stored in this
  /// project's `history.json`. The main release uses saved workspaces instead.
  Future<void> _restoreLegacyWorkspace() async {
    final revision = _workspaceSelectionRevision;
    final session = await ProjectHistory.load(widget.project.path);
    if (!mounted || revision != _workspaceSelectionRevision) return;
    final projects = <Project>[];
    for (final project in widget.store.projects) {
      if (project.isCloud ||
          !session.workspaceRoots.any((path) => p.equals(path, project.path))) {
        continue;
      }
      final exists = await Directory(project.path).exists();
      if (!mounted || revision != _workspaceSelectionRevision) return;
      if (exists) projects.add(project);
    }
    if (!mounted || revision != _workspaceSelectionRevision) return;
    if (projects.isEmpty) return;
    setState(() {
      _workspaceProjects = [
        for (final project in projects)
          if (!p.equals(project.path, widget.project.path)) project,
      ];
    });
    _rebuildRoot();
  }

  void _rebuildRoot() {
    _treeGeneration++;
    _root = FileNode(path: _browsing.path, name: _browsing.name, isDir: true);
    _children.clear();
    _expanded
      ..clear()
      ..addAll(_roots.map((root) => root.path));
    for (final root in _roots) {
      unawaited(_loadChildren(root));
    }
    _restoring = Future.wait([
      for (final project in _workspace) _restoreExpanded(project),
    ]).then((_) {});
  }

  /// Explicitly saves or updates this editor's workspace.
  ///
  /// The dialog is available for a standalone project and for a single-project
  /// registry: a workspace can still be named and reopened from Home.
  Future<void> _manageWorkspace() async {
    if (_savedWorkspace == null && !isMainStudioRelease) {
      await _manageLegacyWorkspace();
      return;
    }
    final result = await showWorkspaceEditorDialog(
      context,
      workspaceStore: _workspaceStore,
      projectStore: widget.store,
      primary: widget.project,
      members: _workspaceMembersOrdered,
      saved: _savedWorkspace,
    );
    if (result == null || !mounted) return;
    _workspaceSelectionRevision++;
    if (result.deleted) {
      // Metadata only: project folders, history and open tabs stay untouched.
      setState(() {
        _savedWorkspace = null;
        _workspaceProjects = [];
        _workspaceExpandedDirs = {};
        _workspaceRootExpanded = {};
        _browsing = widget.project;
      });
      _rebuildRoot();
      widget.onWorkspaceChanged?.call(
        EditorWorkspaceState(saved: null, members: [widget.project]),
      );
      return;
    }
    final saved = result.workspace!;
    final members = _membersFor(saved);
    // Flush the outgoing roots before rebuilding so removing a root never
    // erases the expansion it should recover when added again.
    await _restoring;
    if (!mounted) return;
    // Merge, never replace: `_captureWorkspaceExpansion` overwrites only the
    // roots that are live right now, so an entry for a removed root survives
    // and a re-added root restores its previous expansion.
    _captureWorkspaceExpansion();
    setState(() {
      _savedWorkspace = saved;
      _workspaceProjects = [
        for (final project in members)
          if (!p.equals(project.path, widget.project.path)) project,
      ];
      _browsing = widget.project;
    });
    // Restore reads the merged map; only capture and save after it completes.
    _rebuildRoot();
    await _restoring;
    if (!mounted) return;
    _captureWorkspaceExpansion();
    _notifyWorkspace();
  }

  /// Language-product membership dialog, preserved from the pre-workspace
  /// contract: selection is applied immediately and stored in project history.
  Future<void> _manageLegacyWorkspace() async {
    final projects = widget.store.projects
        .where((project) => !project.isCloud)
        .toList(growable: false);
    final selected = {for (final project in _workspace) project.id};
    final result = await showDialog<List<Project>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          scrollable: true,
          title: const Text('工作区项目'),
          content: SizedBox(
            width: 420,
            // Let AlertDialog scroll an intrinsically measurable project list.
            child: projects.isEmpty
                ? const Text('请先在项目列表添加本地项目。')
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final project in projects)
                        CheckboxListTile(
                          key: ValueKey('workspace-project-${project.id}'),
                          contentPadding: EdgeInsets.zero,
                          title: Text(project.name),
                          subtitle: Text(project.path),
                          value: selected.contains(project.id),
                          onChanged: p.equals(project.path, _browsing.path)
                              ? null
                              : (value) => update(() {
                                  if (value == true) {
                                    selected.add(project.id);
                                  } else {
                                    selected.remove(project.id);
                                  }
                                }),
                        ),
                    ],
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, [
                for (final project in projects)
                  if (selected.contains(project.id)) project,
              ]),
              child: const Text('应用'),
            ),
          ],
        ),
      ),
    );
    if (result == null || !mounted) return;
    await _restoring;
    if (!mounted) return;
    await _persistExpanded();
    if (!mounted) return;
    _workspaceSelectionRevision++;
    setState(() {
      _workspaceProjects = [
        for (final project in result)
          if (!p.equals(project.path, widget.project.path)) project,
      ];
    });
    unawaited(
      ProjectHistory.saveWorkspaceRoots(widget.project.path, [
        for (final project in result) project.path,
      ]),
    );
    _rebuildRoot();
  }

  List<Project> _membersFor(SavedWorkspace workspace) {
    final members = <Project>[];
    for (final member in workspace.members) {
      Project? match;
      for (final project in widget.store.projects) {
        if (project.id == member.projectId) {
          match = project;
          break;
        }
      }
      if (match == null) {
        final key = workspacePathKey(member.path);
        for (final project in widget.store.projects) {
          if (workspacePathKey(project.path) == key) {
            match = project;
            break;
          }
        }
      }
      if (match == null || match.isCloud) continue;
      if (members.any((project) => p.equals(project.path, match!.path))) {
        continue;
      }
      members.add(match);
    }
    if (!members.any((project) => p.equals(project.path, widget.project.path))) {
      members.insert(0, widget.project);
    }
    return members;
  }

  /// Ordered members with the editor's primary root first.
  List<Project> get _workspaceMembersOrdered => [
    widget.project,
    for (final project in _workspace)
      if (!p.equals(project.path, widget.project.path)) project,
  ];

  /// Merges the live roots' expansion into the saved maps.
  ///
  /// Entries for roots that are not mounted right now (a member that was
  /// removed, or one that has not been restored yet) are preserved so that
  /// removing and re-adding a root recovers its previous expansion. Only the
  /// roots that are actually displayed are overwritten.
  void _captureWorkspaceExpansion() {
    final expanded = Map<String, List<String>>.of(_workspaceExpandedDirs);
    final roots = Map<String, bool>.of(_workspaceRootExpanded);
    for (final project in _workspace) {
      final expandedKey = _sessionKey(expanded, project.path) ?? project.path;
      expanded[expandedKey] = [
        for (final path in _expanded)
          if (!p.equals(project.path, path) && p.isWithin(project.path, path))
            p.relative(path, from: project.path).replaceAll(r'\', '/'),
      ];
      final rootKey = _sessionKey(roots, project.path) ?? project.path;
      roots[rootKey] = _expanded.contains(project.path);
    }
    _workspaceExpandedDirs = expanded;
    _workspaceRootExpanded = roots;
  }

  void _notifyWorkspace() {
    final saved = _savedWorkspace;
    if (saved == null) return;
    widget.onWorkspaceChanged?.call(
      EditorWorkspaceState(
        saved: saved,
        members: _workspaceMembersOrdered,
        expandedDirs: _workspaceExpandedDirs,
        rootExpanded: _workspaceRootExpanded,
      ),
    );
  }

  /// Workspace members share a stable tree; external projects own a session.
  void _switchProject(Project project) {
    if (workspacePathKey(project.path) == workspacePathKey(_browsing.path)) {
      return;
    }
    if (_savedWorkspace != null) {
      final member = _workspace.any(
        (candidate) =>
            workspacePathKey(candidate.path) == workspacePathKey(project.path),
      );
      if (member) {
        setState(() {
          _browsing = project;
          _root = FileNode(path: project.path, name: project.name, isDir: true);
        });
      } else {
        widget.onProjectSelected?.call(project);
      }
      return;
    }
    if (isMainStudioRelease && widget.onProjectSelected != null) {
      widget.onProjectSelected!(project);
      return;
    }
    setState(() {
      _browsing = project;
      _rebuildRoot();
    });
    widget.store.setBrowsedProject(project);
  }

  /// Finds the stored key for [path] in a workspace session map, tolerating
  /// Windows path casing and separator differences.
  String? _sessionKey(Map<String, Object?> map, String path) {
    final key = workspacePathKey(path);
    for (final candidate in map.keys) {
      if (workspacePathKey(candidate) == key) return candidate;
    }
    return null;
  }

  /// Restores this root's expansion.
  ///
  /// A saved workspace owns its expansion in the workspace document; a
  /// standalone project keeps using its own `history.json`.
  Future<void> _restoreExpanded(Project project) async {
    final generation = _treeGeneration;
    final projectPath = project.path;
    final saved = _savedWorkspace;
    if (saved != null) {
      final expandedKey = _sessionKey(_workspaceExpandedDirs, projectPath);
      final rootKey = _sessionKey(_workspaceRootExpanded, projectPath);
      if (rootKey != null && _workspaceRootExpanded[rootKey] == false) {
        _expanded.remove(projectPath);
      }
      for (final rel in expandedKey == null
          ? const <String>[]
          : _workspaceExpandedDirs[expandedKey]!) {
        final abs = p.normalize(
          p.isAbsolute(rel) ? rel : p.join(projectPath, rel),
        );
        if (!p.isWithin(projectPath, abs)) continue;
        final exists = await Directory(abs).exists();
        if (!mounted || generation != _treeGeneration) return;
        if (!exists) continue;
        _expanded.add(abs);
        if (!_children.containsKey(abs)) {
          unawaited(
            _loadChildren(
              FileNode(path: abs, name: p.basename(abs), isDir: true),
              generation: generation,
            ),
          );
        }
      }
      if (mounted) setState(() {});
      return;
    }
    final session = await ProjectHistory.load(projectPath);
    if (!mounted || generation != _treeGeneration) return;
    if (!session.treeRootExpanded) _expanded.remove(projectPath);
    for (final rel in session.expandedDirs) {
      final abs = p.normalize(
        p.isAbsolute(rel) ? rel : p.join(projectPath, rel),
      );
      if (!p.isWithin(projectPath, abs)) continue;
      final exists = await Directory(abs).exists();
      if (!mounted || generation != _treeGeneration) return;
      if (!exists) continue;
      _expanded.add(abs);
      if (!_children.containsKey(abs)) {
        unawaited(
          _loadChildren(
            FileNode(path: abs, name: p.basename(abs), isDir: true),
            generation: generation,
          ),
        );
      }
    }
    if (mounted) setState(() {});
  }

  /// 展开状态持久化。
  Future<void> _persistExpanded() async {
    if (_savedWorkspace != null) {
      _captureWorkspaceExpansion();
      _notifyWorkspace();
      return;
    }
    if (!isMainStudioRelease) {
      // Legacy language products keep per-root expansion in project history.
      await Future.wait([
        for (final project in _workspace)
          ProjectHistory.saveExpandedDirs(project.path, [
            for (final path in _expanded)
              if (p.isWithin(project.path, path))
                p.relative(path, from: project.path).replaceAll(r'\', '/'),
          ], treeRootExpanded: _expanded.contains(project.path)),
      ]);
      return;
    }
    await ProjectHistory.saveExpandedDirs(
      widget.project.path,
      [
        for (final path in _expanded)
          if (p.isWithin(widget.project.path, path))
            p.relative(path, from: widget.project.path).replaceAll(r'\', '/'),
      ],
      treeRootExpanded: _expanded.contains(widget.project.path),
    );
  }

  List<FileNode> _childrenOf(FileNode dir) => _children[dir.path] ?? const [];

  /// 打开搜索命中的文件（成功后收起侧栏/抽屉，与树内打开一致）。
  Future<void> _openSearchResult(String path) async {
    final owner = _ownerOf(path);
    final error = await widget.editor.openPath(
      path,
      ownerProjectName: owner.name,
      ownerProjectPath: owner.path,
      ownerProjectType: owner.type,
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

  Future<void> _loadChildren(FileNode dir, {int? generation}) async {
    final expectedGeneration = generation ?? _treeGeneration;
    List<FileNode> nodes = const [];
    try {
      // Async listing: a project directory can hold thousands of entries, and
      // the sync form blocks the isolate that is also driving the page
      // transition.
      final entities = await FileService.listSorted(dir.path);
      nodes = [
        for (final entity in entities)
          FileNode(
            path: entity.path,
            name: p.basename(entity.path),
            isDir: entity is Directory,
          ),
      ];
    } on FileSystemException {
      nodes = const [];
    }
    if (!mounted || expectedGeneration != _treeGeneration) return;
    setState(() => _children[dir.path] = nodes);
  }

  Future<void> _refresh() async {
    final generation = _treeGeneration;
    _children.clear();
    for (final root in _roots) {
      await _loadChildren(root, generation: generation);
      if (!mounted || generation != _treeGeneration) return;
    }
    for (final path in _expanded.toList()) {
      if (_roots.any((root) => p.equals(root.path, path))) continue;
      await _loadChildren(
        FileNode(path: path, name: p.basename(path), isDir: true),
        generation: generation,
      );
      if (!mounted || generation != _treeGeneration) return;
    }
  }

  Future<void> _importResources(
    FileNode directory, {
    required bool photos,
  }) async {
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

  Future<void> _toggle(FileNode node) async {
    final generation = _treeGeneration;
    // Apply a tap after restoration so it cannot be undone by a late restore,
    // or persist an incomplete set while the saved directories are loading.
    await _restoring;
    if (!mounted || generation != _treeGeneration) return;
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
    final owner = _ownerOf(node.path);
    final error = await widget.editor.openPath(
      node.path,
      ownerProjectName: owner.name,
      ownerProjectPath: owner.path,
      ownerProjectType: owner.type,
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
    final generation = _treeGeneration;
    final dirPath = dirNode?.path ?? _root.path;
    final owner = _ownerOf(dirPath);
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
        projectLanguage: owner.language,
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
    await _restoring;
    if (!mounted || generation != _treeGeneration) return;
    _expanded.add(dirPath);
    unawaited(_persistExpanded());
    await _loadChildren(
      FileNode(path: dirPath, name: p.basename(dirPath), isDir: true),
    );
    if (mounted && generation == _treeGeneration && !isDir) {
      await _openFile(FileNode(path: path, name: name, isDir: false));
    }
  }

  Future<void> _delete(FileNode node) async {
    final owner = _ownerOf(node.path);
    final confirmed = await showDeleteEntryConfirm(
      context,
      name: node.name,
      isFolder: node.isDir,
    );
    if (!confirmed || !mounted) return;
    // 先压缩备份到回收站 files_bin，失败则中止删除。
    final backupError = await RecycleBin.backupEntry(
      node.isDir ? Directory(node.path) : File(node.path),
      projectName: owner.name,
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
    // Backup/deletion may finish after the entire editor has been disposed.
    if (!mounted) return;
    widget.editor.closePathsUnder(node.path);
    if (p.isWithin(widget.project.path, node.path)) {
      widget.onEntryDeleted?.call(node.path);
    }
    final parentPath = p.dirname(node.path);
    await _loadChildren(
      FileNode(path: parentPath, name: p.basename(parentPath), isDir: true),
    );
  }

  void _showMenu(FileNode node, Offset position) {
    final isRoot = _roots.any((root) => p.equals(node.path, root.path));
    final owner = _ownerOf(node.path);
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
                projectName: owner.name,
                projectPath: owner.path,
                onOpenVersion: (backupFile, timeLabel) {
                  widget.editor
                      .openPath(
                        backupFile.path,
                        ownerProjectName: owner.name,
                        ownerProjectPath: owner.path,
                        readOnly: true,
                        timeLabel: timeLabel,
                      )
                      .then((error) {
                        if (error != null && mounted) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text(error)));
                        }
                      });
                },
                onRestored: () async {
                  // 恢复后刷新原文件内容（已打开的普通标签）。
                  final idx = widget.editor.files.indexWhere(
                    (f) => p.equals(f.path, node.path),
                  );
                  if (idx >= 0 && !widget.editor.files[idx].readOnly) {
                    widget.editor.files[idx].controller.text = await File(
                      node.path,
                    ).readAsString();
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
    final paths = <String>{};
    final results = [
      for (final project in _workspace)
        for (final node in FileExplorer.searchFiles(project.path, _searchQuery))
          if (paths.add(p.canonicalize(node.path))) node,
    ].take(200).toList(growable: false);
    if (results.isEmpty) {
      return Center(
        child: Text(
          '没有匹配的文件',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: results.length,
      itemBuilder: (context, i) {
        final node = results[i];
        final owner = _ownerOf(node.path);
        final rel = p.isWithin(owner.path, node.path)
            ? p.relative(node.path, from: owner.path).replaceAll(r'\', '/')
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
            _workspace.length > 1 ? '${owner.name}/$rel' : rel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          onTap: () => _openSearchResult(node.path),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final body = _buildBody(context, scheme);
    if (!widget.outlined) {
      return ColoredBox(color: scheme.surfaceContainerLow, child: body);
    }
    // MaterialCardView outlined：圆角表面 + outlineVariant 细描边，无阴影。
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: scheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outlineVariant, width: 1),
      ),
      child: body,
    );
  }

  Widget _buildBody(BuildContext context, ColorScheme scheme) {
    return LayoutBuilder(
      builder: (context, constraints) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            // Grows instead of clipping when large text needs more than 48px,
            // so short panels only give up space from the tree below.
            constraints: const BoxConstraints(minHeight: 48),
            child: Row(
              children: [                const SizedBox(width: 8),
                Expanded(
                  child: PopupMenuButton<Project>(
                    tooltip: '切换项目（跨项目打开文件）',
                    onSelected: _switchProject,
                    itemBuilder: (context) => [
                      for (final p in widget.store.projects)
                        PopupMenuItem(
                          value: p,
                          enabled: _savedWorkspace == null ||
                              widget.onProjectSelected != null ||
                              _workspace.any(
                                (member) => workspacePathKey(member.path) ==
                                    workspacePathKey(p.path),
                              ),
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
          // Always visible: saving a workspace must stay reachable even when
          // the panel is short and the registry has a single project.
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              child: Row(
                children: [
                  Icon(
                    _savedWorkspace == null
                        ? Icons.folder_copy_outlined
                        : Icons.workspaces_outline,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _savedWorkspace == null
                          ? '工作区 · ${_workspace.length} 个项目'
                          : '${_savedWorkspace!.name} · ${_workspace.length} 个项目',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: '工作区项目',
                    icon: const Icon(Icons.tune, size: 20),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                    onPressed: _manageWorkspace,
                  ),
                ],
              ),
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
                        for (final root in _roots)
                          KeyedSubtree(
                            key: ValueKey('workspace-root-${root.path}'),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildRow(context, root, 0),
                                if (_expanded.contains(root.path))
                                  for (final node in _childrenOf(root))
                                    _buildNode(context, node, 1),
                              ],
                            ),
                          ),
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
          child: ConstrainedBox(
            // Tree rows grow with the text scale; a fixed 34px row overflowed
            // by a couple of pixels at 2.0x on short panels.
            constraints: const BoxConstraints(minHeight: 34),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
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
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: row,
    );
  }
}
