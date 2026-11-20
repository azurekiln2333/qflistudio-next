import 'dart:io';

import 'package:flutter/material.dart';

import 'engine/sidecar_client.dart';
import 'screens/home_shell.dart';
import 'state/assistant_controller.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const CloudTerminalWindowsApp());
}

class CloudTerminalWindowsApp extends StatefulWidget {
  const CloudTerminalWindowsApp({super.key});

  @override
  State<CloudTerminalWindowsApp> createState() =>
      _CloudTerminalWindowsAppState();
}

class _CloudTerminalWindowsAppState extends State<CloudTerminalWindowsApp> {
  late final AssistantController _controller = AssistantController(
    sidecar: SidecarClient(
      executable: _nodeExecutable(),
      arguments: const <String>['src/agent/main.ts', '--sidecar'],
      workingDirectory: _agentDirectory(),
    ),
  );
  Color _seed = AppTheme.seeds.first.$2;
  ThemeMode _mode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _controller.start();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'CloudTerminal 助手',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light(_seed),
    darkTheme: AppTheme.dark(_seed),
    themeMode: _mode,
    home: HomeShell(
      controller: _controller,
      onSeedChanged: (s) => setState(() => _seed = s),
      onModeChanged: (m) => setState(() => _mode = m),
    ),
  );
}

/// Directory of the Node agent that this assistant drives.
///
/// The agent sits next to this assistant in the same repository:
/// `companion/windows_assistant` -> `companion/remote_agent`. It is never
/// resolved through the original CloudTerminal checkout.
///
/// Search order, first hit wins:
///   1. `CLOUDTERMINAL_AGENT_DIR` (explicit override, e.g. a packaged agent);
///   2. `<working dir>/../remote_agent` (run from this project directory);
///   3. walk up from the running executable, so a release build under
///      `windows_assistant/build/windows/x64/runner/Release` still finds
///      `companion/remote_agent`.
/// When nothing matches, the working directory is returned and the sidecar
/// reports its own start failure instead of the app inventing a path.
String _agentDirectory() {
  final override = Platform.environment['CLOUDTERMINAL_AGENT_DIR']?.trim();
  if (override != null && override.isNotEmpty) {
    return Directory(override).absolute.path;
  }
  for (final candidate in _agentCandidates()) {
    if (_hasAgentEntry(candidate)) return candidate;
  }
  return Directory.current.absolute.path;
}

/// True when [dir] contains the sidecar entrypoint `src/agent/main.ts`.
bool _hasAgentEntry(String dir) => File(
  '$dir${Platform.pathSeparator}src'
  '${Platform.pathSeparator}agent'
  '${Platform.pathSeparator}main.ts',
).existsSync();

/// Candidate agent directories, nearest first.
Iterable<String> _agentCandidates() sync* {
  final sep = Platform.pathSeparator;
  yield Directory(
    '${Directory.current.path}$sep..$sep'
    'remote_agent',
  ).absolute.path;
  var dir = File(Platform.resolvedExecutable).parent;
  for (var depth = 0; depth < 8; depth += 1) {
    yield '${dir.path}${sep}remote_agent';
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
}

/// Node executable, overridable for a packaged runtime.
String _nodeExecutable() =>
    Platform.environment['CLOUDTERMINAL_NODE']?.trim().isNotEmpty == true
    ? Platform.environment['CLOUDTERMINAL_NODE']!.trim()
    : Platform.isWindows
    ? 'node.exe'
    : 'node';
