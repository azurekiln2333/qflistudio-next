import '../models/project.dart';
import 'saved_workspace.dart';

/// Editor-facing view of a workspace: the saved metadata (when it has been
/// saved explicitly) plus the currently resolved member projects and the tree
/// expansion that belongs to this session.
///
/// An editor can start without a saved workspace and gain one later through the
/// explorer's workspace dialog; the reverse (detaching) leaves the open tabs
/// alive but stops writing workspace metadata.
class EditorWorkspaceState {
  const EditorWorkspaceState({
    this.saved,
    required this.members,
    this.expandedDirs = const {},
    this.rootExpanded = const {},
  });

  final SavedWorkspace? saved;

  /// Ordered local member projects, primary first.
  final List<Project> members;

  /// Root path → expanded relative directories.
  final Map<String, List<String>> expandedDirs;

  /// Root path → whether the root row itself is expanded.
  final Map<String, bool> rootExpanded;

  bool get hasSavedWorkspace => saved != null;

  Project? get primary {
    if (members.isEmpty) return null;
    final savedPrimary = saved?.primaryMember;
    if (savedPrimary != null) {
      for (final project in members) {
        if (project.id == savedPrimary.projectId ||
            workspacePathKey(project.path) ==
                workspacePathKey(savedPrimary.path)) {
          return project;
        }
      }
    }
    return members.first;
  }

  EditorWorkspaceState copyWith({
    SavedWorkspace? saved,
    List<Project>? members,
    Map<String, List<String>>? expandedDirs,
    Map<String, bool>? rootExpanded,
    bool clearSaved = false,
  }) => EditorWorkspaceState(
    saved: clearSaved ? null : (saved ?? this.saved),
    members: members ?? this.members,
    expandedDirs: expandedDirs ?? this.expandedDirs,
    rootExpanded: rootExpanded ?? this.rootExpanded,
  );
}
