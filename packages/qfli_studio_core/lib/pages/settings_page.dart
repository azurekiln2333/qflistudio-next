import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../editor/ai_panel.dart';
import '../services/app_paths.dart';
import '../services/file_backup.dart';
import '../store/auth_store.dart';
import '../store/settings_store.dart';
import '../store/project_store.dart';
import '../models/project.dart';
import '../services/project_archive_service.dart';
import '../widgets/settings_section.dart';
import 'highlight_settings_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.settings,
    this.auth,
    this.store,
    this.showAi = true,
  });

  final SettingsStore settings;
  final AuthStore? auth;
  final ProjectStore? store;
  final bool showAi;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final Future<String?> _backupDirectory = _backupPath();

  SettingsStore get settings => widget.settings;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 840),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                SettingsSection(
                  title: '外观与体验',
                  children: [
                    ListTile(
                      leading: const Icon(Icons.brightness_6_outlined),
                      title: const Text('外观'),
                      subtitle: Text(switch (settings.themeMode) {
                        'light' => '浅色',
                        'dark' => '深色',
                        _ => '跟随系统',
                      }),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _pickThemeMode,
                    ),
                    ListTile(
                      leading: const Icon(Icons.palette_outlined),
                      title: const Text('代码高亮'),
                      subtitle: const Text('配色、TextMate 与自定义语法'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              HighlightSettingsPage(settings: settings),
                        ),
                      ),
                    ),
                  ],
                ),
                SettingsSection(
                  title: '编辑器',
                  children: [
                    SwitchListTile(
                      secondary: const Icon(Icons.map_outlined),
                      title: const Text('代码鸟瞰图'),
                      subtitle: const Text('在编辑器右侧快速定位代码'),
                      value: settings.minimap,
                      onChanged: settings.setMinimap,
                    ),
                    SwitchListTile(
                      secondary: const Icon(Icons.tab_outlined),
                      title: const Text('文件标签栏'),
                      subtitle: const Text('在编辑器顶部显示已打开的文件'),
                      value: settings.showEditorTabs,
                      onChanged: settings.setShowEditorTabs,
                    ),
                    SwitchListTile(
                      secondary: const Icon(Icons.autorenew_outlined),
                      title: const Text('自动保存'),
                      subtitle: const Text('停止输入 2.5 秒后保存修改'),
                      value: settings.autoSave,
                      onChanged: settings.setAutoSave,
                    ),
                    SwitchListTile(
                      secondary: const Icon(Icons.history_outlined),
                      title: const Text('历史版本备份'),
                      subtitle: const Text('自动保存和云同步覆盖文件前保留上一版本'),
                      value: settings.backupEnabled,
                      onChanged: settings.setBackupEnabled,
                    ),
                  ],
                ),
                if (widget.showAi)
                  SettingsSection(
                    title: 'AI 助手',
                    children: [
                      ListTile(
                        leading: const Icon(Icons.auto_awesome_outlined),
                        title: const Text('个人 AI 接口'),
                        subtitle: Text(
                          settings.aiModel.isEmpty
                              ? '连接你自己的 AI 服务与密钥'
                              : settings.aiModel,
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => editAiSettings(context, settings),
                      ),
                    ],
                  ),
                SettingsSection(
                  title: '数据与存储',
                  children: [
                    FutureBuilder<String?>(
                      future: _backupDirectory,
                      builder: (context, snapshot) => ListTile(
                        leading: const Icon(Icons.folder_copy_outlined),
                        title: const Text('历史备份目录'),
                        subtitle: Text(
                          snapshot.data ??
                              (snapshot.connectionState == ConnectionState.done
                                  ? '暂时无法读取目录'
                                  : '正在读取…'),
                        ),
                      ),
                    ),
                    const ListTile(
                      leading: Icon(Icons.delete_sweep_outlined),
                      title: Text('项目回收站'),
                      subtitle: Text(
                        '删除的项目会保存在应用数据目录的 recyclebin/projects_bin 中',
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.file_upload_outlined),
                      title: const Text('导出项目 JSON'),
                      subtitle: const Text('包含项目配置、源码与二进制资源'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: widget.store == null ? null : _exportProject,
                    ),
                    ListTile(
                      leading: const Icon(Icons.file_download_outlined),
                      title: const Text('导入项目 JSON'),
                      subtitle: const Text('恢复项目目录与语言 type'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _importProject,
                    ),
                  ],
                ),
                SettingsSection(
                  title: '关于',
                  children: [
                    ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: const Text('关于 QFLIStudio+'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => showQfliAbout(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickThemeMode() async {
    final picked = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('外观'),
        children: [
          for (final entry in const [
            ('system', '跟随系统', Icons.brightness_auto_outlined),
            ('light', '浅色', Icons.light_mode_outlined),
            ('dark', '深色', Icons.dark_mode_outlined),
          ])
            ListTile(
              leading: Icon(entry.$3),
              title: Text(entry.$2),
              trailing: settings.themeMode == entry.$1
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => Navigator.pop(context, entry.$1),
            ),
        ],
      ),
    );
    if (picked != null) await settings.setThemeMode(picked);
  }

  Future<void> _exportProject() async {
    if (!AppPaths.isDesktop || widget.store == null) {
      _showMessage('当前平台暂使用系统 Picker 导入导出');
      return;
    }
    final project = await _pickProject();
    if (project == null) return;
    try {
      final location = await getSaveLocation(
        suggestedName: '${project.name}.qfli.json',
        acceptedTypeGroups: const [
          XTypeGroup(label: 'QFLI project', extensions: ['json']),
        ],
      );
      if (location == null) return;
      await File(location.path).writeAsString(
        await ProjectArchiveService.exportProject(project),
        flush: true,
      );
      _showMessage('项目已导出');
    } on Object catch (error) {
      _showMessage('导出失败：$error');
    }
  }

  Future<void> _importProject() async {
    if (!AppPaths.isDesktop || widget.store == null) {
      _showMessage('当前平台暂使用系统 Picker 导入导出');
      return;
    }
    try {
      final file = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(label: 'QFLI project', extensions: ['json']),
        ],
      );
      if (file == null) return;
      final source = await file.readAsString();
      final data = jsonDecode(source);
      final name = data is Map && data['name'] is String
          ? (data['name'] as String).trim()
          : '';
      if (name.isEmpty || RegExp(r'[\\/:*?"<>|]').hasMatch(name)) {
        _showMessage('归档缺少有效项目名称');
        return;
      }
      final root = await AppPaths.projectsRoot(create: true);
      if (root == null) throw const FileSystemException('没有可写项目目录');
      final target = p.join(root, name);
      if (Directory(target).existsSync()) {
        _showMessage('项目已存在：$name');
        return;
      }
      await ProjectArchiveService.restoreProject(
        source: source,
        targetDirectory: target,
      );
      final result = await widget.store!.addExisting(target);
      _showMessage(result.error ?? '项目已导入');
    } on Object catch (error) {
      _showMessage('导入失败：$error');
    }
  }

  Future<Project?> _pickProject() async {
    final projects = widget.store!.projects
        .where(
          (project) =>
              !project.isCloud && Directory(project.path).existsSync(),
        )
        .toList();
    if (projects.isEmpty) {
      _showMessage('没有可导出的本地项目');
      return null;
    }
    return showDialog<Project>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('选择项目'),
        children: [
          for (final project in projects)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, project),
              child: Text(project.name),
            ),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  static Future<String?> _backupPath() async {
    final base = await AppPaths.storageDirectory();
    return base == null ? null : p.join(base, FileBackup.dirName);
  }
}

void showQfliAbout(BuildContext context) {
  showAboutDialog(
    context: context,
    applicationName: 'QFLIStudio+',
    applicationVersion: '1.0.0',
    applicationIcon: const Icon(Icons.code_rounded, size: 40),
    children: [const Text('轻量代码编辑器与开发者社区。管理项目，编写代码，分享你的经验。')],
  );
}
