import 'dart:io';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:re_editor/re_editor.dart';

import '../services/file_encoding.dart';

import '../models/project.dart';
import 'open_file.dart';
import 'project_history.dart';

/// 编辑器页面的状态：打开的标签页、当前标签、读取与保存。
class EditorController extends ChangeNotifier {
  EditorController({required this.project});

  static const int maxFileSize = 2 * 1024 * 1024;

  final Project project;
  final List<OpenFile> files = [];
  int _currentIndex = -1;

  OpenFile? get current => (_currentIndex >= 0 && _currentIndex < files.length)
      ? files[_currentIndex]
      : null;

  int get currentIndex => _currentIndex;

  bool isDirty(String path) =>
      files.any((f) => p.equals(f.path, path) && f.dirty);

  /// 打开文件；成功返回 null，失败返回错误信息。
  /// [ownerProjectName] 为文件所属项目名（跨项目打开时用于标签显示），
  /// [ownerProjectPath] 为该项目根目录。
  Future<String?> openPath(
    String path, {
    String? ownerProjectName,
    String? ownerProjectPath,
    bool readOnly = false,
    String? timeLabel,
    FileCursor? cursor,
  }) async {
    final existing = files.indexWhere((f) => p.equals(f.path, path));
    if (existing >= 0) {
      select(existing);
      return null;
    }

    final file = File(path);
    if (!file.existsSync()) return '文件不存在';
    try {
      if (file.lengthSync() > maxFileSize) {
        return '文件超过 2 MB，暂不支持在编辑器中打开';
      }
      final bytes = await file.readAsBytes();
      if (_looksBinary(bytes)) return '暂不支持打开二进制文件';
      final encoding = TextCodec.detect(bytes);
      final content = TextCodec.byName(encoding).decode(bytes);
      final open = OpenFile(
        path: path,
        content: content,
        highlightTheme: null,
        ownerProjectName: ownerProjectName ?? project.name,
        projectRootPath: ownerProjectPath ?? project.path,
        readOnly: readOnly,
        timeLabel: timeLabel,
        encoding: encoding,
      );
      // 历史快照只读：不标记脏、不走保存/云同步。
      if (!readOnly) {
        open.controller.addListener(() => _markDirty(open));
      }
      _restoreCursor(open, cursor);
      files.add(open);
      _currentIndex = files.length - 1;
      notifyListeners();
      focusCurrent();
      return null;
    } on FileSystemException catch (e) {
      return '无法读取文件：${e.message}';
    }
  }

  /// 恢复上次光标位置（越界自动钳制到文件实际范围内）。
  void _restoreCursor(OpenFile open, FileCursor? cursor) {
    if (cursor == null) return;
    final lines = open.controller.codeLines;
    if (lines.isEmpty) return;
    int clampIndex(int i) => i.clamp(0, lines.length - 1);
    int clampOffset(int index, int offset) {
      final lineText = lines[index].text;
      return offset.clamp(0, lineText.length);
    }

    final base = clampIndex(cursor.baseIndex);
    final extent = clampIndex(cursor.extentIndex);
    open.controller.selection = CodeLineSelection(
      baseIndex: base,
      baseOffset: clampOffset(base, cursor.baseOffset),
      extentIndex: extent,
      extentOffset: clampOffset(extent, cursor.extentOffset),
    );
  }

  void _markDirty(OpenFile open) {
    if (open.dirty) return;
    // re_editor 在 CodeEditor 首次挂载时会在 build 阶段同步通知一次，
    // 这是初始化而非内容修改：此刻 notifyListeners 会打断构建，
    // 还会把刚打开的文件误标为未保存，直接忽略。
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      return;
    }
    // 控制器对内容与选区/composing 变化都会通知。选区变化走 copyWith，
    // 保留同一个 codeLines 引用；只有引用被替换（内容确实变了）才算修改。
    final pre = open.controller.preValue;
    if (pre != null &&
        identical(pre.codeLines, open.controller.value.codeLines)) {
      return;
    }
    open.dirty = true;
    notifyListeners();
  }

  void select(int index) {
    if (index < 0 || index >= files.length || index == _currentIndex) return;
    _currentIndex = index;
    notifyListeners();
    focusCurrent();
  }

  /// 关闭标签页；未保存确认由页面层负责。
  /// 注意先移除再计算新索引：关闭最后一个标签时选中相邻标签，
  /// 修复旧实现中索引越界导致"关一个全没了"的问题。
  void closeAt(int index) {
    if (index < 0 || index >= files.length) return;
    final wasCurrent = index == _currentIndex;
    final wasBeforeCurrent = index < _currentIndex;
    files[index].dispose();
    files.removeAt(index);
    if (files.isEmpty) {
      _currentIndex = -1;
    } else if (wasCurrent) {
      _currentIndex = index.clamp(0, files.length - 1);
    } else if (wasBeforeCurrent) {
      _currentIndex -= 1;
    }
    notifyListeners();
  }

  /// 关闭所有标签（可保留一个，用于"关闭其他"）。
  void closeAll({OpenFile? keep}) {
    for (final f in [...files]) {
      if (keep != null && identical(f, keep)) continue;
      f.dispose();
      files.remove(f);
    }
    _currentIndex = files.isEmpty ? -1 : 0;
    notifyListeners();
  }

  /// 保存指定标签页；失败返回错误信息。
  Future<String?> saveAt(int index) async {
    if (index < 0 || index >= files.length) return null;
    final open = files[index];
    if (open.readOnly) return null; // 历史快照只读
    try {
      await File(open.path).writeAsBytes(
        TextCodec.byName(open.encoding).encode(open.controller.text),
        flush: true,
      );
    } on FileSystemException catch (e) {
      return '保存失败：${e.message}';
    }
    open.dirty = false;
    notifyListeners();
    return null;
  }

  /// 用指定编码重新解码文件（不写盘；保存时将使用新编码）。
  Future<String?> reopenWithEncoding(int index, String encoding) async {
    if (index < 0 || index >= files.length) return null;
    final open = files[index];
    if (open.readOnly) return '历史快照只读';
    try {
      final bytes = await File(open.path).readAsBytes();
      final text = TextCodec.byName(encoding).decode(bytes);
      open.encoding = encoding;
      open.controller.text = text;
      open.dirty = false;
      notifyListeners();
      return null;
    } on FileSystemException catch (e) {
      return '读取失败：${e.message}';
    }
  }

  /// 某文件/目录被删除后，移除编辑器中相关的标签页。
  void closePathsUnder(String targetPath) {
    final target = p.canonicalize(targetPath);
    final currentPath = current?.path;
    for (var i = files.length - 1; i >= 0; i--) {
      final filePath = p.canonicalize(files[i].path);
      if (filePath == target || p.isWithin(target, filePath)) {
        files[i].dispose();
        files.removeAt(i);
      }
    }
    if (currentPath != null) {
      _currentIndex = files.indexWhere((f) => f.path == currentPath);
    } else {
      _currentIndex = -1;
    }
    notifyListeners();
  }

  void focusCurrent() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final open = current;
      if (open != null && open.focusNode.canRequestFocus) {
        open.focusNode.requestFocus();
      }
    });
  }

  bool _looksBinary(List<int> bytes) {
    final n = bytes.length < 8192 ? bytes.length : 8192;
    for (var i = 0; i < n; i++) {
      if (bytes[i] == 0) return true;
    }
    return false;
  }

  @override
  void dispose() {
    for (final open in files) {
      open.dispose();
    }
    files.clear();
    super.dispose();
  }
}
