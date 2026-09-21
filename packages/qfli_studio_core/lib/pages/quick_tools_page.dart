import 'dart:io';

import 'package:flutter/material.dart';

import '../editor/terminal_pane.dart';
import '../i18n/studio_localizations.dart';
import '../services/app_paths.dart';
import '../store/project_store.dart';

/// 主页第二页的快捷功能入口。
class QuickToolsTab extends StatelessWidget {
  const QuickToolsTab({
    super.key,
    required this.onOpenTerminal,
    required this.onOpenTutorial,
  });

  final VoidCallback onOpenTerminal;
  final VoidCallback onOpenTutorial;

  @override
  Widget build(BuildContext context) {
    final l10n = StudioLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.quickTools)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _QuickToolTile(
            icon: Icons.terminal,
            title: l10n.terminal,
            subtitle: l10n.terminalSubtitle,
            onTap: onOpenTerminal,
          ),
          const SizedBox(height: 12),
          _QuickToolTile(
            icon: Icons.menu_book_outlined,
            title: l10n.tutorial,
            subtitle: l10n.tutorialSubtitle,
            onTap: onOpenTutorial,
          ),
        ],
      ),
    );
  }
}

class _QuickToolTile extends StatelessWidget {
  const _QuickToolTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

/// 独立的本地终端页，复用编辑器中的终端执行和输出组件。
class LocalTerminalPage extends StatefulWidget {
  const LocalTerminalPage({super.key, required this.store});

  final ProjectStore store;

  @override
  State<LocalTerminalPage> createState() => _LocalTerminalPageState();
}

class _LocalTerminalPageState extends State<LocalTerminalPage> {
  late final Future<String?> _workingDirectory = _resolveWorkingDirectory();

  Future<String?> _resolveWorkingDirectory() async {
    for (final project in widget.store.projects) {
      if (!project.isCloud && Directory(project.path).existsSync()) {
        return project.path;
      }
    }
    final root = await AppPaths.projectsRoot(create: true);
    return root ?? AppPaths.writableDirectory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(StudioLocalizations.of(context).terminal),
        actions: [
          IconButton(
            tooltip: StudioLocalizations.of(context).close,
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.close),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<String?>(
        future: _workingDirectory,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return Center(
              child: Semantics(
                label: StudioLocalizations.of(context).loading,
                child: const CircularProgressIndicator(),
              ),
            );
          }
          final path = snapshot.data;
          if (path == null || path.isEmpty) {
            return Center(
              child: Text(StudioLocalizations.of(context).noWorkingDirectory),
            );
          }
          return TerminalPane(
            workingDirectory: path,
            onClose: () => Navigator.of(context).maybePop(),
          );
        },
      ),
    );
  }
}
