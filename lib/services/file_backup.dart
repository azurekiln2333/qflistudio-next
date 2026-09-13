import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import 'app_paths.dart';

/// 一个历史备份版本。
class BackupVersion {
  const BackupVersion({
    required this.file,
    required this.time,
    required this.size,
  });

  final File file;
  final DateTime time;
  final int size;

  /// 标签页/时间线上的紧凑时间显示。
  String get timeLabel => DateFormat('MM-dd HH:mm').format(time);

  /// 完整时间显示。
  String get timeFull => DateFormat('yyyy-MM-dd HH:mm:ss').format(time);
}

/// 自动保存前的版本备份：`<应用数据>/files_backup/<项目名>/<文件名>-<时间戳><扩展名>`。
abstract final class FileBackup {
  static const String dirName = 'files_backup';

  /// 测试注入应用数据目录的覆盖项；为 null 时走 [AppPaths.storageDirectory]。
  @visibleForTesting
  static String? baseOverride;

  /// 把文件当前磁盘内容备份为带时间戳的副本（覆盖写入前调用）。
  /// 文件尚不存在（新建）或无应用数据目录时跳过；备份失败不阻塞保存。
  static Future<String?> backupBeforeOverwrite(
    File file, {
    required String projectName,
  }) async {
    try {
      if (!file.existsSync()) return null;
      final base = baseOverride ?? await AppPaths.storageDirectory();
      if (base == null) return null;
      final projectDir = Directory(
        p.join(base, dirName, _sanitize(projectName)),
      );
      await projectDir.create(recursive: true);
      final name = p.basenameWithoutExtension(file.path);
      final ext = p.extension(file.path);
      final stamp = _stamp(DateTime.now());
      var target = p.join(projectDir.path, '$name-$stamp$ext');
      var i = 1;
      while (File(target).existsSync()) {
        target = p.join(projectDir.path, '$name-$stamp-${i++}$ext');
      }
      await file.copy(target);
      return null;
    } catch (_) {
      // 备份失败不阻塞自动保存。
      return null;
    }
  }

  /// 列出某文件的历史备份版本（按时间倒序）。
  static Future<List<BackupVersion>> listVersions(
    File original, {
    required String projectName,
  }) async {
    try {
      final base = baseOverride ?? await AppPaths.storageDirectory();
      if (base == null) return const [];
      final dir = Directory(p.join(base, dirName, _sanitize(projectName)));
      if (!dir.existsSync()) return const [];
      final name = p.basenameWithoutExtension(original.path);
      final ext = p.extension(original.path);
      final pattern = RegExp(
        '${RegExp.escape(name)}-(\\d{8}-\\d{6}-\\d{3})'
        '${RegExp.escape(ext)}\$',
      );
      final versions = <BackupVersion>[];
      for (final entity in dir.listSync(followLinks: false)) {
        if (entity is! File) continue;
        final match = pattern.firstMatch(p.basename(entity.path));
        if (match == null) continue;
        final time = _parseStamp(match.group(1)!);
        if (time == null) continue;
        versions.add(BackupVersion(
          file: entity,
          time: time,
          size: entity.lengthSync(),
        ));
      }
      versions.sort((a, b) => b.time.compareTo(a.time));
      return versions;
    } catch (_) {
      return const [];
    }
  }

  /// 恢复版本到原文件（恢复前先把当前内容备份一份，防丢）。
  static Future<void> restoreVersion(
    BackupVersion version,
    File original, {
    required String projectName,
  }) async {
    await backupBeforeOverwrite(original, projectName: projectName);
    await Directory(p.dirname(original.path)).create(recursive: true);
    await version.file.copy(original.path);
  }

  static DateTime? _parseStamp(String stamp) {
    // yyyyMMdd-HHmmss-mmm
    final m = RegExp(r'^(\d{4})(\d{2})(\d{2})-(\d{2})(\d{2})(\d{2})-(\d{3})$')
        .firstMatch(stamp);
    if (m == null) return null;
    try {
      return DateTime(
        int.parse(m.group(1)!),
        int.parse(m.group(2)!),
        int.parse(m.group(3)!),
        int.parse(m.group(4)!),
        int.parse(m.group(5)!),
        int.parse(m.group(6)!),
        int.parse(m.group(7)!),
      );
    } on FormatException {
      return null;
    }
  }

  static String _sanitize(String name) =>
      name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

  static String _stamp(DateTime t) {
    String f2(int v) => v.toString().padLeft(2, '0');
    return '${t.year}${f2(t.month)}${f2(t.day)}'
        '-${f2(t.hour)}${f2(t.minute)}${f2(t.second)}'
        '-${t.millisecond.toString().padLeft(3, '0')}';
  }
}
