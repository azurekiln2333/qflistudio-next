import 'package:flutter/foundation.dart';

import '../models/terminal_session.dart';
import '../shell/local_shell.dart';

/// Owns every open QFLI terminal session.
class TerminalManager extends ChangeNotifier {
  final List<TerminalSession> _sessions = <TerminalSession>[];

  String? _activeId;
  int _counter = 0;

  List<TerminalSession> get sessions => List<TerminalSession>.unmodifiable(_sessions);

  int get sessionCount => _sessions.length;

  TerminalSession? get active {
    if (_sessions.isEmpty) return null;
    final index = _sessions.indexWhere((session) => session.id == _activeId);
    return index < 0 ? _sessions.first : _sessions[index];
  }

  /// Index of the active session, or -1 when none are open. Used to keep the
  /// [PageView] in sync with the tab strip.
  int get activeIndex {
    if (_sessions.isEmpty) return -1;
    final index = _sessions.indexWhere((session) => session.id == _activeId);
    return index < 0 ? 0 : index;
  }

  /// Creates and focuses a new terminal. Returns null when the requested
  /// backend cannot be started.
  TerminalSession create({String? workingDirectory}) {
    _counter++;
    final backend = createLocalShell(workingDirectory: workingDirectory);

    final session = TerminalSession(
      id: 'session-$_counter',
      title: '终端 $_counter',
      backend: backend,
    );
    session.onExitRequested = (target) => close(target.id);

    _sessions.add(session);
    _activeId = session.id;
    notifyListeners();
    return session;
  }

  void select(String id) {
    if (_activeId == id) return;
    _activeId = id;
    notifyListeners();
  }

  void selectIndex(int index) {
    if (index < 0 || index >= _sessions.length) return;
    select(_sessions[index].id);
  }

  void close(String id) {
    final index = _sessions.indexWhere((session) => session.id == id);
    if (index < 0) return;

    final session = _sessions.removeAt(index);
    session.dispose();

    if (_activeId == id) {
      if (_sessions.isEmpty) {
        _activeId = null;
      } else {
        final next = index >= _sessions.length ? _sessions.length - 1 : index;
        _activeId = _sessions[next].id;
      }
    }
    notifyListeners();
  }

  void closeActive() {
    final current = active;
    if (current != null) close(current.id);
  }

  /// Closes every terminal except [id], which becomes the active one.
  ///
  /// Unlike [close] this never empties the list, so it does not trip the
  /// screen's auto-recreate: closing the others leaves exactly this one.
  void closeOthers(String id) {
    if (!_sessions.any((session) => session.id == id)) return;
    for (final session in _sessions) {
      if (session.id != id) session.dispose();
    }
    _sessions.removeWhere((session) => session.id != id);
    _activeId = id;
    notifyListeners();
  }

  void closeAll() {
    for (final session in _sessions) {
      session.dispose();
    }
    _sessions.clear();
    _activeId = null;
    notifyListeners();
  }

  void rename(String id, String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    final index = _sessions.indexWhere((session) => session.id == id);
    if (index < 0) return;
    _sessions[index].title = trimmed;
    notifyListeners();
  }

  /// Switches to the next session, wrapping around.
  void cycle([int delta = 1]) {
    if (_sessions.length < 2) return;
    final current = _sessions.indexWhere((session) => session.id == _activeId);
    final next = ((current < 0 ? 0 : current) + delta) % _sessions.length;
    select(_sessions[next < 0 ? next + _sessions.length : next].id);
  }

  @override
  void dispose() {
    for (final session in _sessions) {
      session.dispose();
    }
    _sessions.clear();
    super.dispose();
  }
}
