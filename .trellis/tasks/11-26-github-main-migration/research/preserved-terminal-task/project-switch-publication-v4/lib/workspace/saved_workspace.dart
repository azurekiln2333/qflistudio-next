import 'dart:io';

import 'package:path/path.dart' as p;

import '../editor/project_history.dart';
import '../models/project.dart';
import '../services/studio_profile.dart';

/// True for the release main product.
///
/// A null profile is the shared default (the main App), so an unset profile
/// behaves like `qflistudio`. Language products set their own product key and
/// keep their existing multi-root history behavior.
bool get isMainStudioRelease {
  final profile = StudioProfile.current;
  return profile == null ||
      profile.productKey == StudioProductCatalog.qfliStudioKey;
}

/// Comparison key for a project root path.
///
/// Windows paths are case-insensitive, and a workspace may be reopened after a
/// project was re-registered through a different casing or a trailing slash.
String workspacePathKey(String path) {
  final normalized = p.normalize(p.absolute(path));
  return Platform.isWindows ? normalized.toLowerCase() : normalized;
}

/// One project a saved workspace refers to.
///
/// Membership is stored independently of [Project] instances: the workspace
/// keeps both the registry identity and the last known path so a renamed or
/// re-registered project can still be found, and a missing one can be reported
/// without touching its source folder.
class WorkspaceMember {
  const WorkspaceMember({
    required this.projectId,
    required this.path,
    required this.name,
    this.primary = false,
  });

  final String projectId;
  final String path;
  final String name;
  final bool primary;

  factory WorkspaceMember.fromProject(
    Project project, {
    bool primary = false,
  }) => WorkspaceMember(
    projectId: project.id,
    path: p.normalize(p.absolute(project.path)),
    name: project.name,
    primary: primary,
  );

  WorkspaceMember copyWith({bool? primary, String? name, String? path}) =>
      WorkspaceMember(
        projectId: projectId,
        path: path ?? this.path,
        name: name ?? this.name,
        primary: primary ?? this.primary,
      );

  Map<String, dynamic> toJson() => {
    'projectId': projectId,
    'path': path,
    'name': name,
    if (primary) 'primary': true,
  };

  static WorkspaceMember? fromJson(Object? value) {
    if (value is! Map) return null;
    final id = value['projectId'];
    final path = value['path'];
    if (id is! String || id.isEmpty || path is! String || path.isEmpty) {
      return null;
    }
    return WorkspaceMember(
      projectId: id,
      path: path,
      name: value['name'] is String ? value['name'] as String : p.basename(path),
      primary: value['primary'] == true,
    );
  }
}

/// Editor state saved with a workspace: open tabs, cursors and tree expansion.
///
/// This is deliberately separate from [ProjectHistory]: a workspace session is
/// its own identity, so opening a standalone project never restores another
/// project's workspace tabs.
class WorkspaceSessionSnapshot {
  const WorkspaceSessionSnapshot({
    this.primaryPath,
    this.documents = const [],
    this.expandedDirs = const {},
    this.rootExpanded = const {},
  });

  static const empty = WorkspaceSessionSnapshot();

  /// Last opened primary root. Only a hint: opening validates membership first
  /// and falls back to a surviving member when this root is gone.
  final String? primaryPath;

  /// Ordered open tabs, each relative to its registered owner project.
  final List<ProjectDocumentSession> documents;

  /// Tree expansion per project root (absolute root key → relative directories).
  final Map<String, List<String>> expandedDirs;

  /// Whether each root itself is expanded (absolute root key).
  final Map<String, bool> rootExpanded;

  bool get isEmpty =>
      documents.isEmpty && expandedDirs.isEmpty && rootExpanded.isEmpty;

  Map<String, dynamic> toJson() => {
    if (primaryPath != null) 'primaryPath': primaryPath,
    'documents': [for (final document in documents) document.toJson()],
    'expandedDirs': {
      for (final entry in expandedDirs.entries) entry.key: entry.value,
    },
    'rootExpanded': {...rootExpanded},
  };

  static WorkspaceSessionSnapshot fromJson(Object? value) {
    if (value is! Map) return empty;
    final documents = <ProjectDocumentSession>[];
    for (final raw in (value['documents'] is List
            ? value['documents'] as List
            : const [])
        .take(512)) {
      final document = ProjectDocumentSession.fromJson(raw);
      if (document != null) documents.add(document);
    }
    final expanded = <String, List<String>>{};
    final rawExpanded = value['expandedDirs'];
    if (rawExpanded is Map) {
      for (final entry in rawExpanded.entries) {
        if (entry.key is! String || entry.value is! List) continue;
        expanded[entry.key as String] = [
          for (final dir in entry.value as List)
            if (dir is String) dir,
        ];
      }
    }
    final roots = <String, bool>{};
    final rawRoots = value['rootExpanded'];
    if (rawRoots is Map) {
      for (final entry in rawRoots.entries) {
        if (entry.key is! String || entry.value is! bool) continue;
        roots[entry.key as String] = entry.value as bool;
      }
    }
    return WorkspaceSessionSnapshot(
      primaryPath: value['primaryPath'] is String
          ? value['primaryPath'] as String
          : null,
      documents: documents,
      expandedDirs: expanded,
      rootExpanded: roots,
    );
  }
}

/// A named, explicitly saved multi-root workspace.
class SavedWorkspace {
  const SavedWorkspace({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    required this.members,
    this.session = WorkspaceSessionSnapshot.empty,
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<WorkspaceMember> members;
  final WorkspaceSessionSnapshot session;

  WorkspaceMember? get primaryMember {
    for (final member in members) {
      if (member.primary) return member;
    }
    return members.isEmpty ? null : members.first;
  }

  List<String> get memberPaths => [for (final member in members) member.path];

  SavedWorkspace copyWith({
    String? name,
    DateTime? updatedAt,
    List<WorkspaceMember>? members,
    WorkspaceSessionSnapshot? session,
  }) => SavedWorkspace(
    id: id,
    name: name ?? this.name,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    members: members ?? this.members,
    session: session ?? this.session,
  );

  Map<String, dynamic> toJson() => {
    'version': 1,
    'id': id,
    'name': name,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'members': [for (final member in members) member.toJson()],
    'session': session.toJson(),
  };

  /// Parses a workspace file. [fallbackId] comes from the file name so a
  /// partially damaged document can still be identified and repaired.
  static SavedWorkspace? fromJson(Object? value, {String? fallbackId}) {
    if (value is! Map) return null;
    final id = value['id'] is String && (value['id'] as String).isNotEmpty
        ? value['id'] as String
        : fallbackId;
    if (id == null || id.isEmpty) return null;
    final name = value['name'];
    if (name is! String || name.trim().isEmpty) return null;
    final members = <WorkspaceMember>[];
    final seen = <String>{};
    for (final raw in (value['members'] is List
        ? value['members'] as List
        : const [])) {
      final member = WorkspaceMember.fromJson(raw);
      if (member == null) continue;
      if (!seen.add(workspacePathKey(member.path))) continue;
      members.add(member);
    }
    if (members.isEmpty) return null;
    return SavedWorkspace(
      id: id,
      name: name.trim(),
      createdAt:
          DateTime.tryParse(value['createdAt'] is String
              ? value['createdAt'] as String
              : '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(value['updatedAt'] is String
              ? value['updatedAt'] as String
              : '') ??
          DateTime.now(),
      members: members,
      session: WorkspaceSessionSnapshot.fromJson(value['session']),
    );
  }
}
