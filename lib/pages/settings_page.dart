import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../services/app_paths.dart';
import '../services/api_client.dart';
import '../editor/ai_panel.dart';
import '../store/auth_store.dart';
import '../services/file_backup.dart';
import '../store/settings_store.dart';

/// 统一设置页：编辑器 / 存储 / 通用 / 账号。
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.settings, this.auth});

  final SettingsStore settings;

  /// 服务器地址等账号相关设置需要登录态（未登录时隐藏对应项）。
  final AuthStore? auth;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => ListView(
          children: [
            const _SectionHeader('通用'),
            ListTile(
              leading: const Icon(Icons.brightness_6_outlined),
              title: const Text('外观'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    switch (settings.themeMode) {
                      'light' => '浅色',
                      'dark' => '深色',
                      _ => '跟随系统',
                    },
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 14,
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              onTap: () => _pickThemeMode(context),
            ),
            ListTile(
              leading: const Icon(Icons.auto_awesome),
              title: const Text('AI 接口设置'),
              subtitle: Text(
                settings.aiModel.isEmpty
                    ? '未配置（自定义 OpenAI 兼容接口）'
                    : settings.aiModel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => editAiSettings(context, settings),
            ),
            const _SectionHeader('账号'),
            if (auth != null && auth!.isLoggedIn)
              ListTile(
                leading: const Icon(Icons.dns_outlined),
                title: const Text('服务器地址'),
                subtitle: Text(
                  auth!.serverUrl ?? ApiClient.instance?.baseUrl ?? '未设置',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _editServer(context),
              ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('关于 QFLIStudio+'),
              trailing: const Text('1.0.0'),
              onTap: () => _showAbout(context),
            ),
            const Divider(height: 1),
            const _SectionHeader('编辑器'),
            SwitchListTile(
              secondary: const Icon(Icons.map_outlined),
              title: const Text('代码鸟瞰图'),
              subtitle: const Text('编辑器右侧显示代码缩略导航条'),
              value: settings.minimap,
              onChanged: (value) => settings.setMinimap(value),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.history_outlined),
              title: const Text('历史版本备份'),
              subtitle: const Text('自动保存/同步覆盖文件前先备份一份到 files_backup（总开关）'),
              value: settings.backupEnabled,
              onChanged: (value) => settings.setBackupEnabled(value),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.autorenew_outlined),
              title: const Text('自动保存'),
              subtitle: const Text('编辑停止 2.5 秒后自动写盘；覆盖前先把上一版本备份到 files_backup'),
              value: settings.autoSave,
              onChanged: (value) => settings.setAutoSave(value),
            ),
            const Divider(height: 1),
            const _SectionHeader('存储'),
            FutureBuilder<String?>(
              future: _backupPath(),
              builder: (context, snapshot) {
                final path = snapshot.data;
                return ListTile(
                  leading: const Icon(Icons.folder_copy_outlined),
                  title: const Text('自动保存备份目录'),
                  subtitle: Text(
                    path ?? '未找到可写的应用数据目录',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_sweep_outlined),
              title: const Text('删除项目回收站'),
              subtitle: Text(
                '删除的项目会压缩备份到应用数据 recyclebin/projects_bin',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickThemeMode(BuildContext context) async {
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
              onTap: () => Navigator.of(context).pop(entry.$1),
            ),
        ],
      ),
    );
    if (picked != null) {
      await settings.setThemeMode(picked);
    }
  }

  Future<void> _editServer(BuildContext context) async {
    final auth = this.auth;
    if (auth == null) return;
    final controller =
        TextEditingController(text: auth.serverUrl ?? ApiClient.defaultBaseUrl);
    final confirmed = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('服务器地址'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'azurekiln-qfli-server 地址',
            prefixIcon: Icon(Icons.dns_outlined),
            hintText: 'http://192.168.1.100:3000',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop('ok'),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (confirmed == null) return;
    final err = await auth.setServer(controller.text);
    if (err != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  void _showAbout(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('关于 QFLIStudio+'),
        content: const Text(
          'QFLIStudio+ 是一个基于 Flutter / Material 3 的轻量级代码编辑器，'
          '支持项目管理、多标签代码编辑、社区教程与讨论，以及 AI 助手与在线终端。',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  static Future<String?> _backupPath() async {
    final base = await AppPaths.storageDirectory();
    if (base == null) return null;
    return p.join(base, FileBackup.dirName);
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
