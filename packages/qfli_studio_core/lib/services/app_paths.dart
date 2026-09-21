import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 应用可写目录与配置文件的路径解析。
///
/// 在鸿蒙/Android 等移动平台上，插件缺失或沙箱限制都可能让
/// path_provider 失败，这里按候选顺序逐个探测真实可写性。
abstract final class AppPaths {
  static const String _probeMarker = '.qfli_write_probe';
  static Future<String?>? _storageFuture;
  static Future<String?>? _writableFuture;
  static int _probeId = 0;

  /// 首个可写的候选目录；全部失败返回 null。
  static Future<String?> writableDirectory() =>
      _writableFuture ??= _findWritableDirectory();

  static Future<String?> _findWritableDirectory() async {
    final candidates = <String>[];

    Future<void> tryAdd(Future<Directory?> Function() getter) async {
      try {
        final dir = await getter().timeout(const Duration(seconds: 2));
        if (dir != null) candidates.add(dir.path);
      } catch (_) {
        // 平台实现缺失（如 ohos 未注册插件）时忽略。
      }
    }

    await tryAdd(() => getApplicationDocumentsDirectory());
    await tryAdd(() => getApplicationSupportDirectory());
    await tryAdd(() => getExternalStorageDirectory());

    for (final key in const ['HOME', 'USERPROFILE', 'TMPDIR', 'TEMP', 'TMP']) {
      final value = Platform.environment[key];
      if (value != null && value.isNotEmpty) candidates.add(value);
    }
    try {
      if (Directory.current.path.isNotEmpty) {
        candidates.add(Directory.current.path);
      }
    } catch (_) {}

    for (final path in candidates) {
      if (await _isWritable(path)) return path;
    }
    return null;
  }

  /// 配置文件所在目录：优先应用支持目录，其次文档目录，最后任意可写目录。
  static Future<String?> storageDirectory() =>
      _storageFuture ??= _findStorageDirectory();

  static Future<String?> _findStorageDirectory() async {
    // 三个 Store 共享一次探测；第一个候选成功后立即返回。
    for (final getter in [
      getApplicationSupportDirectory,
      getApplicationDocumentsDirectory,
    ]) {
      try {
        final dir = await getter().timeout(const Duration(seconds: 2));
        if (await _isWritable(dir.path)) return dir.path;
      } catch (_) {}
    }
    return writableDirectory();
  }

  /// 新建项目的默认根目录：`<应用数据>/projects`。
  ///
  /// [create] 为 true 时确保目录存在（用于创建项目前）。
  static Future<String?> projectsRoot({bool create = false}) async {
    final base = await storageDirectory();
    if (base == null) return null;
    final dir = Directory(p.join(base, 'projects'));
    if (create) {
      try {
        await dir.create(recursive: true);
      } on FileSystemException {
        return null;
      }
    }
    return dir.path;
  }

  /// 通过写入并删除探针文件验证目录可写。
  static Future<bool> _isWritable(String dirPath) async {
    try {
      if (!await Directory(dirPath).exists()) return false;
      final probe = File(
        p.join(
          dirPath,
          '$_probeMarker${DateTime.now().microsecondsSinceEpoch}_${_probeId++}',
        ),
      );
      await probe.writeAsString('ok', flush: false);
      await probe.delete();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 是否为桌面平台（可访问任意磁盘路径）。
  static bool get isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
}
