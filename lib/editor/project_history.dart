import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// 项目内会话记忆文件（`<项目>/history.json`）：
/// - 每个文件的光标位置（打开文件时自动定位）
/// - 上次打开的文件列表与激活标签（打开项目时恢复现场）
class FileCursor {
  const FileCursor({
    required this.baseIndex,
    required this.baseOffset,
    required this.extentIndex,
    required this.extentOffset,
  });

  final int baseIndex;
  final int baseOffset;
  final int extentIndex;
  final int extentOffset;

  Map<String, dynamic> toJson() => {
        'baseIndex': baseIndex,
        'baseOffset': baseOffset,
        'extentIndex': extentIndex,
        'extentOffset': extentOffset,
      };

  static FileCursor fromJson(Map<String, dynamic> j) => FileCursor(
        baseIndex: (j['baseIndex'] as num?)?.toInt() ?? 0,
        baseOffset: (j['baseOffset'] as num?)?.toInt() ?? 0,
        extentIndex: (j['extentIndex'] as num?)?.toInt() ?? 0,
        extentOffset: (j['extentOffset'] as num?)?.toInt() ?? 0,
      );
}

/// 一次会话快照。
class ProjectSession {
  const ProjectSession({
    required this.cursors,
    required this.openFiles,
    required this.activeFile,
    this.expandedDirs = const [],
  });

  /// 相对路径 → 光标。
  final Map<String, FileCursor> cursors;

  /// 上次打开的文件（相对路径，按标签顺序）。
  final List<String> openFiles;

  /// 上次激活的标签。
  final String? activeFile;

  /// 文件树展开的目录（相对路径）。
  final List<String> expandedDirs;
}

abstract final class ProjectHistory {
  static File historyFile(String projectPath) =>
      File(p.join(projectPath, 'history.json'));

  static Future<ProjectSession> load(String projectPath) async {
    try {
      final file = historyFile(projectPath);
      if (!file.existsSync()) {
        return const ProjectSession(
          cursors: {},
          openFiles: [],
          activeFile: null,
        );
      }
      final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final files = data['files'] is Map
          ? Map<String, dynamic>.from(data['files'] as Map)
          : <String, dynamic>{};
      return ProjectSession(
        cursors: {
          for (final e in files.entries)
            e.key: FileCursor.fromJson(
              Map<String, dynamic>.from(e.value as Map),
            ),
        },
        openFiles: [
          for (final f in (data['openFiles'] as List? ?? [])) f as String,
        ],
        activeFile: data['activeFile'] as String?,
        expandedDirs: [
          for (final d in (data['expandedDirs'] as List? ?? []))
            d as String,
        ],
      );
    } catch (_) {
      // 配置损坏时按空会话处理。
      return const ProjectSession(
        cursors: {},
        openFiles: [],
        activeFile: null,
        expandedDirs: [],
      );
    }
  }

  /// 只更新文件树展开目录（保留会话其他字段）。
  static Future<void> saveExpandedDirs(
    String projectPath,
    List<String> dirs,
  ) async {
    final session = await load(projectPath);
    await save(
      projectPath,
      cursors: session.cursors,
      openFiles: session.openFiles,
      activeFile: session.activeFile,
      expandedDirs: dirs,
    );
  }

  static Future<void> save(
    String projectPath, {
    required Map<String, FileCursor> cursors,
    required List<String> openFiles,
    required String? activeFile,
    List<String>? expandedDirs,
  }) async {
    // 未显式传入时保留文件里已有的展开状态。
    final effectiveDirs = expandedDirs ??
        (await load(projectPath)).expandedDirs;
    try {
      final file = historyFile(projectPath);
      await file.parent.create(recursive: true);
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert({
          'version': 1,
          'openFiles': openFiles,
          'activeFile': activeFile,
          'expandedDirs': effectiveDirs,
          'files': {
            for (final e in cursors.entries) e.key: e.value.toJson(),
          },
        }),
        flush: true,
      );
    } catch (_) {
      // 写失败不打断编辑。
    }
  }
}
