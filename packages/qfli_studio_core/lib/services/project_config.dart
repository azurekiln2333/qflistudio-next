import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// 项目级配置文件：`<项目根>/.qfli/project.json`。
///
/// 语言等信息随项目走，应用侧注册表（projects.json）丢失或换设备后
/// 仍能恢复语言标注。
abstract final class ProjectConfig {
  static const String dirName = '.qfli';
  static const String fileName = 'project.json';

  static String configPath(String projectRoot) =>
      p.join(projectRoot, dirName, fileName);

  /// 读取完整配置；文件不存在或内容损坏返回 null。
  static Map<String, dynamic>? read(String projectRoot) {
    try {
      final file = File(configPath(projectRoot));
      if (!file.existsSync()) return null;
      final data = jsonDecode(file.readAsStringSync());
      return data is Map ? Map<String, dynamic>.from(data) : null;
    } catch (_) {
      return null;
    }
  }

  /// 读取语言标注；缺失返回 null。
  static String? readLanguage(String projectRoot) =>
      read(projectRoot)?['language'] as String?;

  static String? readType(String projectRoot) =>
      read(projectRoot)?['type'] as String?;

  /// 写入（或合并更新）项目配置；失败静默，不阻塞创建/添加流程。
  static Future<void> write({
    required String projectRoot,
    required String name,
    required String language,
    String type = '',
  }) async {
    try {
      final existing = read(projectRoot) ?? <String, dynamic>{};
      existing['version'] = 1;
      existing['name'] = name;
      existing['language'] = language;
      if (type.isNotEmpty) existing['type'] = type;
      if (!existing.containsKey('createdAt')) {
        existing['createdAt'] = DateTime.now().toIso8601String();
      }
      final file = File(configPath(projectRoot));
      await file.parent.create(recursive: true);
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(existing),
        flush: true,
      );
    } catch (_) {
      // 配置写入失败不影响项目本身。
    }
  }
}
