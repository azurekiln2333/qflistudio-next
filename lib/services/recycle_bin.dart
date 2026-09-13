import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'app_paths.dart';

/// 回收站：删除项目/文件前先压缩备份到应用数据目录。
///
/// 目录结构：`<应用数据>/recyclebin/projects_bin`（整个项目文件夹）
/// 与 `<应用数据>/recyclebin/files_bin`（编辑器里删除的文件/文件夹）。
abstract final class RecycleBin {
  static const String projectsBin = 'projects_bin';
  static const String filesBin = 'files_bin';

  /// 测试注入应用数据目录的覆盖项；为 null 时走 [AppPaths.storageDirectory]。
  @visibleForTesting
  static String? baseOverride;

  /// 删除整个项目文件夹前的备份。返回错误信息，null 表示成功。
  static Future<String?> backupProject(Directory projectDir) =>
      _zipToBin(sourcePath: projectDir.path, bin: projectsBin);

  /// 删除文件/文件夹前的备份（files_bin），[projectName] 用于命名防混淆。
  static Future<String?> backupEntry(
    FileSystemEntity entity, {
    String? projectName,
  }) => _zipToBin(
    sourcePath: entity.path,
    bin: filesBin,
    namePrefix: projectName,
  );

  static Future<String?> _zipToBin({
    required String sourcePath,
    required String bin,
    String? namePrefix,
  }) async {
    try {
      final base = baseOverride ?? await AppPaths.storageDirectory();
      if (base == null) {
        return '未找到可写的应用数据目录，无法备份到回收站';
      }
      final binDir = Directory(p.join(base, 'recyclebin', bin));
      await binDir.create(recursive: true);
      final target = File(
        p.join(binDir.path, await _zipName(binDir, sourcePath, namePrefix)),
      );
      final bytes = await _compress(sourcePath, name: p.basename(sourcePath));
      await target.writeAsBytes(bytes, flush: true);
      return null;
    } catch (e) {
      return '备份失败：$e';
    }
  }

  static Future<String> _zipName(
    Directory binDir,
    String sourcePath,
    String? prefix,
  ) async {
    final stamp = _stamp(DateTime.now());
    final base = prefix == null || prefix.isEmpty
        ? '${p.basename(sourcePath)}-$stamp'
        : '$prefix-${p.basename(sourcePath)}-$stamp';
    var name = '$base.zip';
    var i = 1;
    while (File(p.join(binDir.path, name)).existsSync()) {
      name = '$base-${i++}.zip';
    }
    return name;
  }

  static String _stamp(DateTime t) {
    String f2(int v) => v.toString().padLeft(2, '0');
    return '${t.year}${f2(t.month)}${f2(t.day)}-${f2(t.hour)}${f2(t.minute)}${f2(t.second)}';
  }

  /// 把 [sourcePath]（文件或目录）压缩为 zip 字节流，路径以 [name] 为根。
  static Future<List<int>> _compress(
    String sourcePath, {
    required String name,
  }) async {
    final archive = Archive();
    await _addToArchive(archive, sourcePath, name);
    return ZipEncoder().encode(archive, level: DeflateLevel.defaultCompression);
  }

  static Future<void> _addToArchive(
    Archive archive,
    String fsPath,
    String archivePath,
  ) async {
    final type = FileSystemEntity.typeSync(fsPath, followLinks: false);
    if (type == FileSystemEntityType.directory) {
      archive.add(ArchiveFile.directory('$archivePath/'));
      for (final entity in Directory(fsPath).listSync(followLinks: false)) {
        await _addToArchive(
          archive,
          entity.path,
          '$archivePath/${p.basename(entity.path)}',
        );
      }
    } else if (type == FileSystemEntityType.file) {
      final bytes = await File(fsPath).readAsBytes();
      archive.add(ArchiveFile.bytes(archivePath, bytes));
    }
    // 符号链接等类型跳过，避免环引用。
  }
}
