import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../models/project.dart';
import '../services/app_paths.dart';
import '../store/project_store.dart';
import 'saved_workspace.dart';

/// Result of writing a workspace. [error] is null on success.
typedef WorkspaceSaveResult = ({String? error, SavedWorkspace? workspace});

/// A saved workspace resolved against the current registry and filesystem.
class WorkspaceResolution {
  const WorkspaceResolution({
    required this.workspace,
    required this.projects,
    required this.missing,
    required this.primary,
    required this.primaryMissing,
  });

  final SavedWorkspace workspace;
  final List<Project> projects;
  final List<WorkspaceMember> missing;
  final Project? primary;
  final bool primaryMissing;

  bool get isEmpty => projects.isEmpty;
}

/// Explicit workspace metadata under the application's `workspaces` directory.
///
/// Calls are ordered before any asynchronous directory lookup. Transactions for
/// the same physical directory also share a lane across store instances. Each
/// mutation merges the fields it owns with the current disk document and only
/// publishes its result after the atomic replacement succeeds.
class WorkspaceStore extends ChangeNotifier {
  WorkspaceStore({Directory? root}) : _rootOverride = root;

  static final WorkspaceStore instance = WorkspaceStore();
  static final Map<String, Future<void>> _rootOperations = {};
  static final RegExp _safeId = RegExp(r'^[A-Za-z0-9_-]{1,128}$');
  static int _identitySequence = 0;

  final Directory? _rootOverride;
  final List<SavedWorkspace> _workspaces = [];
  Future<void> _pending = Future<void>.value();
  bool _loaded = false;

  bool get loaded => _loaded;

  List<SavedWorkspace> get workspaces {
    final list = [..._workspaces];
    list.sort((a, b) {
      final byTime = b.updatedAt.compareTo(a.updatedAt);
      return byTime != 0 ? byTime : a.name.compareTo(b.name);
    });
    return list;
  }

  SavedWorkspace? byId(String? id) => _find(_workspaces, id);

  static SavedWorkspace? _find(List<SavedWorkspace> workspaces, String? id) {
    for (final workspace in workspaces) {
      if (workspace.id == id) return workspace;
    }
    return null;
  }

  Future<Directory> _root() async {
    final Directory directory;
    if (_rootOverride case final override?) {
      directory = override;
    } else {
      final base = await AppPaths.storageDirectory();
      if (base == null) {
        throw const FileSystemException('未找到可写的工作区目录');
      }
      directory = Directory(p.join(base, 'workspaces'));
    }
    if (!await directory.exists()) await directory.create(recursive: true);
    return directory;
  }

  File _fileFor(Directory root, String id) {
    if (!_safeId.hasMatch(id)) {
      throw FileSystemException('工作区标识无效', id);
    }
    return File(p.join(root.path, '$id.json'));
  }

  /// Includes writes invoked before this read; refresh never replaces newer
  /// in-memory state with a read that started before those writes completed.
  Future<void> load({bool force = false}) => _serialize(() async {
    if (_loaded && !force) return;
    await _atRoot((root) async {
      final workspaces = await _readAll(root);
      _publish(workspaces);
    });
  });

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    await _atRoot((root) async => _publish(await _readAll(root)));
  }

  Future<List<SavedWorkspace>> _readAll(Directory root) async {
    final loaded = <SavedWorkspace>[];
    // A directory-read failure propagates without replacing the existing list.
    await for (final entity in root.list(followLinks: false)) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      try {
        final workspace = await _readFile(entity);
        if (workspace != null) loaded.add(workspace);
      } on FormatException {
        // One malformed document must not hide the other saved workspaces.
      } on FileSystemException {
        // An individual document may disappear during external filesystem work.
      }
    }
    return loaded;
  }

  Future<SavedWorkspace?> _readFile(File file) async {
    final fileId = p.basenameWithoutExtension(file.path);
    if (!_safeId.hasMatch(fileId)) return null;
    final workspace = SavedWorkspace.fromJson(
      jsonDecode(await file.readAsString()),
      fallbackId: fileId,
    );
    // A document may only update its own file, even if its local JSON is damaged.
    if (workspace == null || workspace.id != fileId) return null;
    return _snapshotWorkspace(workspace);
  }

  /// Creates or updates membership/name. Omitting [session] preserves the newest
  /// session, including writes made after a settings dialog received [existing].
  Future<WorkspaceSaveResult> save({
    SavedWorkspace? existing,
    required String name,
    required List<Project> members,
    required Project primary,
    WorkspaceSessionSnapshot? session,
  }) {
    final trimmed = name.trim();
    final id = existing?.id ?? _newId();
    final primaryKey = workspacePathKey(primary.path);
    final ordered = <WorkspaceMember>[];
    final seen = <String>{};
    for (final project in [primary, ...members]) {
      if (project.isCloud || !seen.add(workspacePathKey(project.path))) {
        continue;
      }
      ordered.add(
        WorkspaceMember.fromProject(
          project,
          primary: workspacePathKey(project.path) == primaryKey,
        ),
      );
    }
    final memberSnapshot = List<WorkspaceMember>.unmodifiable(ordered);
    final sessionSnapshot = session == null ? null : _snapshotSession(session);
    return _serialize(() async {
      if (trimmed.isEmpty) return (error: '请输入工作区名称', workspace: null);
      if (memberSnapshot.isEmpty) {
        return (error: '工作区至少需要一个本地项目', workspace: null);
      }
      try {
        await _ensureLoaded();
        return await _atRoot((root) async {
          final file = _fileFor(root, id);
          final currentList = await _readAll(root);
          final current = _find(currentList, id);
          if (existing != null && current == null) {
            return (error: '工作区记录已被删除，请另存为新的工作区', workspace: null);
          }
          if (currentList.any(
            (workspace) =>
                workspace.id != id &&
                workspace.name.toLowerCase() == trimmed.toLowerCase(),
          )) {
            return (error: '已存在同名工作区「$trimmed」', workspace: null);
          }
          final now = DateTime.now();
          final workspace = SavedWorkspace(
            id: id,
            name: trimmed,
            createdAt: current?.createdAt ?? now,
            updatedAt: now,
            members: memberSnapshot,
            session:
                sessionSnapshot ??
                current?.session ??
                WorkspaceSessionSnapshot.empty,
          );
          await _write(file, workspace);
          currentList.removeWhere((item) => item.id == id);
          currentList.add(workspace);
          _publish(currentList);
          return (error: null, workspace: workspace);
        });
      } catch (error) {
        return (
          error: error is FileSystemException ? error.message : '$error',
          workspace: null,
        );
      }
    });
  }

  /// Updates only the session. Stale retained editors cannot recreate a deleted
  /// workspace; disappearance is observed in the same transaction as the write.
  Future<void> saveSession(
    SavedWorkspace workspace,
    WorkspaceSessionSnapshot session,
  ) {
    final snapshot = _snapshotSession(session);
    return _serialize(() async {
      await _ensureLoaded();
      await _atRoot((root) async {
        final file = _fileFor(root, workspace.id);
        final type = await FileSystemEntity.type(file.path, followLinks: false);
        if (type == FileSystemEntityType.notFound) {
          final hadEntry = byId(workspace.id) != null;
          _workspaces.removeWhere((item) => item.id == workspace.id);
          if (hadEntry) notifyListeners();
          return;
        }
        if (type != FileSystemEntityType.file) {
          throw FileSystemException('工作区记录不是文件', file.path);
        }
        final current = await _readFile(file);
        if (current == null) {
          throw FileSystemException('工作区记录格式不正确', file.path);
        }
        final updated = current.copyWith(session: snapshot);
        await _write(file, updated);
        _replace(updated);
        notifyListeners();
      });
    });
  }

  /// Waits for previously invoked work, including transactions shared with
  /// another store for this application. Failed operations do not poison queues.
  Future<void> settle() async {
    while (true) {
      final pending = _pending;
      await pending;
      final transactions = _rootOperations.values.toList(growable: false);
      await Future.wait(transactions);
      if (identical(pending, _pending) && _rootOperations.isEmpty) return;
    }
  }

  /// Deletes metadata only. A failed delete throws and keeps the list entry so
  /// callers can show the error and retry rather than reporting false success.
  Future<void> remove(String id) => _serialize(() async {
    await _ensureLoaded();
    await _atRoot((root) async {
      final file = _fileFor(root, id);
      if (await FileSystemEntity.type(file.path, followLinks: false) !=
          FileSystemEntityType.notFound) {
        await file.delete();
      }
      _workspaces.removeWhere((workspace) => workspace.id == id);
      notifyListeners();
    });
  });

  /// Missing members are skipped; a surviving member replaces a missing primary.
  Future<WorkspaceResolution> resolve(
    SavedWorkspace workspace,
    ProjectStore store,
  ) async {
    final projects = <Project>[];
    final missing = <WorkspaceMember>[];
    final seen = <String>{};
    final registered = store.projects;
    for (final member in workspace.members) {
      Project? match;
      for (final project in registered) {
        if (project.id == member.projectId) {
          match = project;
          break;
        }
      }
      if (match == null) {
        final key = workspacePathKey(member.path);
        for (final project in registered) {
          if (workspacePathKey(project.path) == key) {
            match = project;
            break;
          }
        }
      }
      if (match == null ||
          match.isCloud ||
          !await Directory(match.path).exists()) {
        missing.add(member);
        continue;
      }
      if (seen.add(workspacePathKey(match.path))) projects.add(match);
    }
    Project? primary;
    final savedPrimary = workspace.primaryMember;
    if (savedPrimary != null) {
      final key = workspacePathKey(savedPrimary.path);
      for (final project in projects) {
        if (project.id == savedPrimary.projectId ||
            workspacePathKey(project.path) == key) {
          primary = project;
          break;
        }
      }
    }
    final primaryMissing = savedPrimary != null && primary == null;
    primary ??= projects.isEmpty ? null : projects.first;
    return WorkspaceResolution(
      workspace: workspace,
      projects: List.unmodifiable(projects),
      missing: List.unmodifiable(missing),
      primary: primary,
      primaryMissing: primaryMissing,
    );
  }

  void _publish(List<SavedWorkspace> workspaces) {
    _workspaces
      ..clear()
      ..addAll(workspaces);
    _loaded = true;
    notifyListeners();
  }

  void _replace(SavedWorkspace workspace) {
    final index = _workspaces.indexWhere((item) => item.id == workspace.id);
    if (index < 0) {
      _workspaces.add(workspace);
    } else {
      _workspaces[index] = workspace;
    }
  }

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final result = _pending.then((_) => operation());
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<T> _atRoot<T>(Future<T> Function(Directory root) operation) async {
    final root = await _root();
    final key = workspacePathKey(root.resolveSymbolicLinksSync());
    final previous = _rootOperations[key] ?? Future<void>.value();
    final result = previous.then((_) => operation(root));
    final drained = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _rootOperations[key] = drained;
    return result.whenComplete(() {
      if (identical(_rootOperations[key], drained)) _rootOperations.remove(key);
    });
  }

  Future<void> _write(File file, SavedWorkspace workspace) async {
    final encoded = const JsonEncoder.withIndent(
      '  ',
    ).convert(workspace.toJson());
    final temporaryDirectory = await file.parent.createTemp('.qfli-workspace-');
    final temporaryFile = File(
      p.join(temporaryDirectory.path, 'workspace.json'),
    );
    try {
      await temporaryFile.writeAsString(encoded, flush: true);
      await temporaryFile.rename(file.path);
    } finally {
      try {
        await temporaryFile.delete();
      } on FileSystemException {
        // A successful rename already moved it.
      }
      try {
        await temporaryDirectory.delete();
      } on FileSystemException {
        // Preserve unrelated files that appeared in the temporary directory.
      }
    }
  }

  static WorkspaceSessionSnapshot _snapshotSession(
    WorkspaceSessionSnapshot session,
  ) => WorkspaceSessionSnapshot(
    primaryPath: session.primaryPath,
    documents: List.unmodifiable(session.documents),
    expandedDirs: Map.unmodifiable({
      for (final entry in session.expandedDirs.entries)
        entry.key: List<String>.unmodifiable(entry.value),
    }),
    rootExpanded: Map.unmodifiable(session.rootExpanded),
  );

  static SavedWorkspace _snapshotWorkspace(SavedWorkspace workspace) =>
      workspace.copyWith(
        members: List.unmodifiable(workspace.members),
        session: _snapshotSession(workspace.session),
      );

  static String _newId() =>
      'ws_${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}_${_identitySequence++}';
}
