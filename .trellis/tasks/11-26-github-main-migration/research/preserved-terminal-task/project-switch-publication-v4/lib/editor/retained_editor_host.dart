import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../models/project.dart';
import '../store/auth_store.dart';
import '../store/project_store.dart';
import '../store/settings_store.dart';
import '../workspace/saved_workspace.dart';
import '../workspace/workspace_store.dart';
import 'editor_page.dart';
import 'retained_editor_restore_control.dart';

/// Opens a live project, or resumes its existing editor. Hosted opens finish
/// immediately; standalone callers keep the ordinary Navigator route lifetime.
///
/// Passing [workspace] opens a saved workspace session; it is keyed separately
/// from a standalone open of the same project so the two never share tabs.
Future<void> openEditorPage(
  BuildContext context, {
  required Project project,
  required AuthStore auth,
  required ProjectStore store,
  required SettingsStore settings,
  String? initialOpenPath,
  SavedWorkspace? workspace,
  List<Project>? workspaceProjects,
  WorkspaceStore? workspaceStore,
}) async {
  final controller = RetainedEditorScope.maybeOf(context);
  if (controller != null) {
    controller.open(
      project: project,
      auth: auth,
      store: store,
      settings: settings,
      initialOpenPath: initialOpenPath,
      workspace: workspace,
      workspaceProjects: workspaceProjects,
      workspaceStore: workspaceStore,
    );
    return;
  }
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => EditorPage(
        project: project,
        auth: auth,
        store: store,
        settings: settings,
        initialOpenPath: initialOpenPath,
        workspace: workspace,
        workspaceMembers: workspaceProjects ?? const [],
        workspaceStore: workspaceStore,
      ),
    ),
  );
}

class RetainedEditorScope extends InheritedNotifier<RetainedEditorController> {
  const RetainedEditorScope({
    super.key,
    required RetainedEditorController controller,
    required super.child,
  }) : super(notifier: controller);

  static RetainedEditorController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<RetainedEditorScope>()
      ?.notifier;
}

/// Owns mounted editor lifetimes, independently of the Home route stack.
class RetainedEditorController extends ChangeNotifier {
  RetainedEditorController() {
    _rootObserver = _RootEditorObserver(this);
  }

  late final _RootEditorObserver _rootObserver;
  NavigatorObserver get navigatorObserver => _rootObserver;
  final _sessions = <String, _EditorSession>{};
  String? _active;
  String? _lastActive;
  bool _handlingBack = false;
  bool _selectingProject = false;
  bool _rootRouteUpdateScheduled = false;
  bool _disposed = false;

  bool get isVisible => _active != null;
  Project? get activeProject => _sessions[_active]?.project;
  List<Project> get projects =>
      List.unmodifiable(_sessions.values.map((session) => session.project));

  /// Read-only view of the live sessions (key, project and saved workspace).
  /// Used by shell chrome and regression tests; mutations stay internal.
  List<({String key, Project project, SavedWorkspace? workspace})>
  get sessionInfos => [
    for (final entry in _sessions.entries)
      (
        key: entry.key,
        project: entry.value.project,
        workspace: entry.value.workspace,
      ),
  ];

  String _projectKey(String path) {
    final normalized = p.normalize(p.absolute(path));
    return Platform.isWindows ? normalized.toLowerCase() : normalized;
  }

  /// Session identity is the workspace id, not its primary project path: if
  /// the primary member disappears, Home reopens the same workspace with a
  /// surviving primary and must resume the same live session (and its dirty
  /// buffers), not create a second session writing the same workspace file.
  String _resolveOpenKey(Project project, SavedWorkspace? workspace) {
    final projectKey = _projectKey(project.path);
    if (workspace != null) {
      for (final entry in _sessions.entries) {
        if (entry.value.workspace?.id == workspace.id) return entry.key;
      }
      return 'workspace:${workspace.id}:$projectKey';
    }
    final base = 'standalone:$projectKey';
    // Reuse an existing standalone session for this project. A session promoted
    // to a saved workspace is excluded so a standalone open never resumes its
    // extra members.
    final existing = _sessions[base];
    if (existing == null || existing.workspace == null) return base;
    for (final entry in _sessions.entries) {
      final session = entry.value;
      if (session.workspace == null &&
          _projectKey(session.project.path) == projectKey) {
        return entry.key;
      }
    }
    var index = 2;
    while (_sessions.containsKey('$base#$index')) {
      index++;
    }
    return '$base#$index';
  }

  void open({
    required Project project,
    required AuthStore auth,
    required ProjectStore store,
    required SettingsStore settings,
    String? initialOpenPath,
    SavedWorkspace? workspace,
    List<Project>? workspaceProjects,
    WorkspaceStore? workspaceStore,
  }) {
    final key = _resolveOpenKey(project, workspace);
    final session = _sessions.putIfAbsent(
      key,
      () => _EditorSession(
        project,
        auth,
        store,
        settings,
        workspace: workspace,
        workspaceProjects: workspaceProjects ?? const [],
        workspaceStore: workspaceStore,
      ),
    );
    if (workspace != null) {
      // Re-opening a saved workspace re-resolves its members. The effective
      // primary may have changed (missing primary → survivor); keep the live
      // editor and its tabs, including untouched dirty buffers of survivors.
      final members = workspaceProjects ?? const <Project>[];
      var changed = false;
      if (!p.equals(session.project.path, project.path)) {
        session.project = project;
        session.workspaceRevision++;
        changed = true;
      }
      if (session.workspace?.updatedAt != workspace.updatedAt ||
          !_samePaths(session.workspaceProjects, members)) {
        session.workspace = workspace;
        session.workspaceProjects = members;
        session.workspaceRevision++;
        changed = true;
      }
      if (workspaceStore != null && !identical(session.workspaceStore, workspaceStore)) {
        session.workspaceStore = workspaceStore;
        changed = true;
      }
      if (initialOpenPath != null) {
        session.initialOpenPath = initialOpenPath;
        session.openRequest++;
        changed = true;
      }
      _activate(key);
      // ListenableBuilder only rebuilds on notifications; a re-resolved
      // workspace must reach EditorPage even when the session is active.
      if (changed) notifyListeners();
      return;
    }
    if (workspaceStore != null) session.workspaceStore = workspaceStore;
    if (initialOpenPath != null) {
      session.initialOpenPath = initialOpenPath;
      session.openRequest++;
    }
    _activate(key);
  }

  /// Keeps a live session's identity in step with a workspace it just saved.
  ///
  /// The session key is intentionally stable so open tabs and dirty buffers
  /// survive the promotion; future standalone opens get a separate session.
  void attachWorkspace(
    String key,
    SavedWorkspace workspace,
    List<Project> members,
  ) {
    final session = _sessions[key];
    if (session == null) return;
    if (session.workspace?.id == workspace.id &&
        _samePaths(session.workspaceProjects, members)) {
      return;
    }
    session.workspace = workspace;
    session.workspaceProjects = members;
    session.workspaceRevision++;
    notifyListeners();
  }

  /// Attaches a newly saved workspace to the active session (test/UI helper).
  void attachActiveWorkspace(
    SavedWorkspace workspace,
    List<Project> members,
  ) {
    final key = _active;
    if (key == null) return;
    attachWorkspace(key, workspace, members);
  }

  static bool _samePaths(List<Project> a, List<Project> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!p.equals(a[i].path, b[i].path)) return false;
    }
    return true;
  }

  void resume(Project project, {SavedWorkspace? workspace}) {
    final key = _resolveOpenKey(project, workspace);
    if (_sessions.containsKey(key)) _activate(key);
  }

  void _activate(String key) {
    if (_active != key) _sessions[_active]?.visible.value = false;
    FocusManager.instance.primaryFocus?.unfocus();
    _active = _lastActive = key;
    _sessions[key]!.visible.value = true;
    _rootObserver.setEditorVisible(true);
    notifyListeners();
  }

  void minimize() {
    if (!isVisible) return;
    // Capture live view state before mobile re_editor handles focus loss.
    _sessions[_active]!.visible.value = false;
    FocusManager.instance.primaryFocus?.unfocus();
    _active = null;
    _rootObserver.setEditorVisible(false);
    notifyListeners();
  }

  void _setSelectingProject(bool selecting) {
    _selectingProject = selecting;
    notifyListeners();
  }

  void _rootRouteChanged() {
    if (_disposed || _rootRouteUpdateScheduled) return;
    _rootRouteUpdateScheduled = true;
    // Navigator can report its top route while its overlay is building.
    // Rebuild the sibling host after that frame, coalescing nested popups.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _rootRouteUpdateScheduled = false;
      if (!_disposed) notifyListeners();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  // Only EditorPage's explicit close action calls this, after dirty-file
  // confirmation. Minimize and project switching never remove a session.
  void _close(String key) {
    FocusManager.instance.primaryFocus?.unfocus();
    _sessions.remove(key)?.visible.dispose();
    if (_active == key) _active = null;
    if (_lastActive == key) {
      _lastActive = _sessions.isEmpty ? null : _sessions.keys.last;
    }
    _rootObserver.setEditorVisible(isVisible);
    notifyListeners();
  }

  Future<void> _back() async {
    if (_handlingBack || !isVisible) return;
    _handlingBack = true;
    final key = _active;
    try {
      final navigator = _sessions[key]?.navigatorKey.currentState;
      final handled = await navigator?.maybePop() ?? false;
      if (!handled && _active == key) minimize();
    } finally {
      _handlingBack = false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _rootObserver.detach();
    for (final session in _sessions.values) {
      session.visible.dispose();
    }
    super.dispose();
  }
}

class _EditorSession {
  _EditorSession(
    this.project,
    this.auth,
    this.store,
    this.settings, {
    this.workspace,
    this.workspaceProjects = const [],
    this.workspaceStore,
  });

  Project project;
  final AuthStore auth;
  final ProjectStore store;
  final SettingsStore settings;
  SavedWorkspace? workspace;
  List<Project> workspaceProjects;
  WorkspaceStore? workspaceStore;
  int workspaceRevision = 0;
  final navigatorKey = GlobalKey<NavigatorState>();
  final visible = ValueNotifier<bool>(false);
  String? initialOpenPath;
  int openRequest = 0;

  String get label => workspace?.name ?? project.name;
}

/// Place in MaterialApp.builder, above and alongside the root Navigator.
/// Each editor's Navigator is therefore its own root for dialogs and menus.
class RetainedEditorHost extends StatefulWidget {
  const RetainedEditorHost({
    super.key,
    required this.controller,
    required this.child,
  });

  final RetainedEditorController controller;
  final Widget child;

  @override
  State<RetainedEditorHost> createState() => _RetainedEditorHostState();
}

class _RetainedEditorHostState extends State<RetainedEditorHost>
    with TickerProviderStateMixin {
  final _motions = <String, AnimationController>{};
  final _targets = <String, bool>{};
  final _editorChildren = <String, Widget>{};
  bool _reduceMotion = false;

  RetainedEditorController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    controller.addListener(_syncSessions);
    _syncSessions();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion) {
      for (final entry in _motions.entries) {
        entry.value.value = _targets[entry.key] == true ? 1 : 0;
      }
    }
  }

  @override
  void didUpdateWidget(covariant RetainedEditorHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != controller) {
      oldWidget.controller.removeListener(_syncSessions);
      _disposeMotions();
      controller.addListener(_syncSessions);
      _syncSessions();
    }
  }

  void _syncSessions() {
    for (final key in _motions.keys.toList()) {
      if (controller._sessions.containsKey(key)) continue;
      _motions.remove(key)!.dispose();
      _targets.remove(key);
      _editorChildren.remove(key);
    }
    for (final entry in controller._sessions.entries) {
      final motion = _motions.putIfAbsent(
        entry.key,
        () => AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 180),
          reverseDuration: const Duration(milliseconds: 140),
        ),
      );
      _editorChildren.putIfAbsent(
        entry.key,
        () => _editorChild(entry.key, entry.value),
      );
      final visible = controller._active == entry.key;
      if (_targets[entry.key] == visible) continue;
      _targets[entry.key] = visible;
      if (_reduceMotion) {
        motion.value = visible ? 1 : 0;
      } else if (visible) {
        motion.forward();
      } else {
        motion.reverse();
      }
    }
    setState(() {});
  }

  Widget _editorChild(String key, _EditorSession session) =>
      HeroControllerScope.none(
        child: NotificationListener<NavigationNotification>(
          onNotification: (_) => true,
          child: ScaffoldMessenger(
            child: Navigator(
              key: session.navigatorKey,
              onGenerateRoute: (_) => MaterialPageRoute<void>(
                builder: (_) => _SessionEditor(
                  controller: controller,
                  sessionKey: key,
                  session: session,
                ),
              ),
            ),
          ),
        ),
      );

  void _disposeMotions() {
    for (final motion in _motions.values) {
      motion.dispose();
    }
    _motions.clear();
    _targets.clear();
    _editorChildren.clear();
  }

  @override
  void dispose() {
    controller.removeListener(_syncSessions);
    _disposeMotions();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RetainedEditorScope(
    controller: controller,
    child: AnimatedBuilder(
      animation: Listenable.merge(_motions.values.toList()),
      builder: (context, _) => Overlay.wrap(
        child: Stack(
          fit: StackFit.expand,
          children: [
            _retained(
              visible:
                  !controller.isVisible ||
                  _motions.values.any((motion) => motion.isAnimating),
              interactive: !controller.isVisible,
              child: widget.child,
            ),
            // Keep the active editor above an exiting project. The keyed
            // layers and cached Navigator children keep their live identity
            // when the paint order changes.
            for (final entry in [
              ...controller._sessions.entries.where(
                (entry) => entry.key != controller._active,
              ),
              ...controller._sessions.entries.where(
                (entry) => entry.key == controller._active,
              ),
            ])
              _animatedEditor(
                key: ValueKey(entry.key),
                visible: controller._active == entry.key,
                motion: _motions[entry.key]!,
                child: _editorChildren[entry.key]!,
              ),
            // Always mounted in a fixed keyed slot, even with no session and
            // while a root modal is open: visibility is a property of the
            // control, not of whether its slot exists. Unmounting it here is
            // what used to discard the dragged position and collapsed mode.
            SafeArea(
              child: RetainedEditorRestoreControl(
                key: const ValueKey('retained-editor-restore-control'),
                visible:
                    !controller.isVisible &&
                    !_motions.values.any((motion) => motion.isAnimating) &&
                    !controller._rootObserver.hasPopupRoute &&
                    controller._sessions.isNotEmpty,
                // A root popup already covers the control; freezing input (but
                // keeping the widget mounted) prevents barrier interception
                // while preserving state across the modal.
                interactive: !controller._selectingProject,
                projectName: controller._lastActive == null
                    ? null
                    : controller._sessions[controller._lastActive!]?.label,
                hasMultipleSessions: controller._sessions.length > 1,
                reserveBottom: _restoreControlBottomReservation(context),
                onRestore: () => controller._activate(controller._lastActive!),
                onSelect: (anchorContext) =>
                    unawaited(_showSessionMenu(anchorContext)),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  /// Space Home reserves below the control: navigation bar (below 900dp),
  /// then the Scaffold FAB margin and FAB height, plus a visible gap, and the
  /// on-screen keyboard when it is open.
  ///
  /// `SafeArea` above this only applies `padding` (system bars/cutouts); it
  /// ignores `viewInsets`, so the keyboard height has to be reserved here or
  /// the restore control would sit behind the keyboard with no way to reach it.
  /// The keyboard replaces the bottom bar visually, so only the larger of the
  /// two is reserved rather than summing them.
  double _restoreControlBottomReservation(BuildContext context) {
    final theme = Theme.of(context);
    final navigationHeight = MediaQuery.sizeOf(context).width < 900
        ? NavigationBarTheme.of(context).height ?? 80.0
        : 0.0;
    final defaultFabHeight = theme.useMaterial3 ? 56.0 : 48.0;
    final fabHeight =
        theme.floatingActionButtonTheme.extendedSizeConstraints
            ?.constrainHeight(defaultFabHeight) ??
        defaultFabHeight;
    const gap = 12.0;
    final homeTier =
        navigationHeight + kFloatingActionButtonMargin + fabHeight + gap;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return keyboard > homeTier ? keyboard + gap : homeTier;
  }

  Future<void> _showSessionMenu(BuildContext anchorContext) async {
    // The restore control is a sibling of the root Navigator, so its context
    // cannot be used with showMenu. Use the observed Navigator's own Overlay.
    final navigator = controller.navigatorObserver.navigator;
    final overlay = navigator?.overlay;
    if (navigator == null || overlay == null) return;
    final anchor = anchorContext.findRenderObject();
    final overlayBox = overlay.context.findRenderObject();
    if (anchor is! RenderBox || overlayBox is! RenderBox) return;
    if (!anchor.hasSize || !overlayBox.hasSize) return;
    // These render boxes are siblings. Convert through global coordinates;
    // passing overlayBox as localToGlobal's ancestor would be invalid.
    final rect = Rect.fromPoints(
      overlayBox.globalToLocal(anchor.localToGlobal(Offset.zero)),
      overlayBox.globalToLocal(
        anchor.localToGlobal(anchor.size.bottomRight(Offset.zero)),
      ),
    );
    // The host paints above the root Overlay. Hide its restore control while
    // the modal menu is open so it cannot cover items or intercept the barrier.
    controller._setSelectingProject(true);
    String? selected;
    try {
      selected = await showMenu<String>(
        context: overlay.context,
        position: RelativeRect.fromRect(rect, Offset.zero & overlayBox.size),
        items: [
          for (final entry in controller._sessions.entries)
            PopupMenuItem(
              value: entry.key,
              child: Text(entry.value.label),
            ),
        ],
      );
    } finally {
      if (navigator.mounted) controller._setSelectingProject(false);
    }
    if (selected != null &&
        navigator.mounted &&
        controller._sessions.containsKey(selected)) {
      controller._activate(selected);
    }
  }

  Widget _animatedEditor({
    required Key key,
    required bool visible,
    required AnimationController motion,
    required Widget child,
  }) {
    final eased = motion.drive(CurveTween(curve: Curves.easeOutCubic));
    return _retained(
      key: key,
      visible: visible || !motion.isDismissed,
      interactive: visible,
      child: FadeTransition(
        opacity: eased,
        child: SlideTransition(
          position: eased.drive(
            Tween<Offset>(begin: const Offset(0, 0.035), end: Offset.zero),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _retained({
    Key? key,
    required bool visible,
    required bool interactive,
    required Widget child,
  }) => Offstage(
    key: key,
    offstage: !visible,
    child: TickerMode(
      enabled: interactive,
      child: ExcludeFocus(
        excluding: !interactive,
        child: ExcludeSemantics(
          excluding: !interactive,
          child: IgnorePointer(ignoring: !interactive, child: child),
        ),
      ),
    ),
  );
}

// The route's builder keeps the same EditorPage state while requests change.
class _SessionEditor extends StatelessWidget {
  const _SessionEditor({
    required this.controller,
    required this.sessionKey,
    required this.session,
  });

  final RetainedEditorController controller;
  final String sessionKey;
  final _EditorSession session;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, child) => EditorPage(
      project: session.project,
      auth: session.auth,
      store: session.store,
      settings: session.settings,
      initialOpenPath: session.initialOpenPath,
      openRequest: session.openRequest,
      retainedVisibility: session.visible,
      workspace: session.workspace,
      workspaceMembers: session.workspaceProjects,
      workspaceStore: session.workspaceStore,
      onWorkspaceSaved: (workspace, members) =>
          controller.attachWorkspace(sessionKey, workspace, members),
      onProjectSelected: (project) => controller.open(
        project: project,
        auth: session.auth,
        store: session.store,
        settings: session.settings,
        workspaceStore: session.workspaceStore,
      ),
      onMinimize: controller.minimize,
      onClose: () => controller._close(sessionKey),
    ),
  );
}

class _EditorPopEntry extends PopEntry<Object?> {
  _EditorPopEntry(this.controller);

  final RetainedEditorController controller;
  @override
  final ValueNotifier<bool> canPopNotifier = ValueNotifier(true);

  @override
  void onPopInvokedWithResult(bool didPop, Object? result) {
    if (!didPop && controller.isVisible) unawaited(controller._back());
  }
}

// A PopScope in MaterialApp.builder has no enclosing route. Register its
// equivalent on the actual top Home/content route to receive platform Back
// before that Navigator can pop a route hidden behind the active editor.
class _RootEditorObserver extends NavigatorObserver {
  _RootEditorObserver(RetainedEditorController controller)
    : _controller = controller,
      _entry = _EditorPopEntry(controller);

  final RetainedEditorController _controller;
  final _EditorPopEntry _entry;
  final _popupRoutes = <PopupRoute<dynamic>>{};
  ModalRoute<dynamic>? _route;
  bool _detached = false;

  bool get hasPopupRoute => _popupRoutes.isNotEmpty;

  void setEditorVisible(bool visible) {
    _entry.canPopNotifier.value = !visible;
  }

  @override
  void didChangeTop(Route<dynamic> topRoute, Route<dynamic>? previousTopRoute) {
    if (_detached) return;
    _route?.unregisterPopEntry(_entry);
    _route = topRoute is ModalRoute<dynamic> ? topRoute : null;
    _route?.registerPopEntry(_entry);
    if (topRoute is PopupRoute<dynamic> && _popupRoutes.add(topRoute)) {
      if (_popupRoutes.length == 1) _controller._rootRouteChanged();
      // A popped dialog/menu still paints and intercepts input during its exit.
      // Restore the control only after its overlay entries have been removed.
      unawaited(
        topRoute.completed.then((_) {
          if (_detached) return;
          if (_popupRoutes.remove(topRoute) && _popupRoutes.isEmpty) {
            _controller._rootRouteChanged();
          }
        }),
      );
    }
  }

  void detach() {
    _detached = true;
    _route?.unregisterPopEntry(_entry);
    _route = null;
    _popupRoutes.clear();
    _entry.canPopNotifier.dispose();
  }
}
