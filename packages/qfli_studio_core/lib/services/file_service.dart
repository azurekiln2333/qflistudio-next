import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

/// 文件系统相关工具方法。
abstract final class FileService {
  static final RegExp _illegalChars = RegExp(r'[\\/:*?"<>|]');

  /// 新建文件/文件夹的名称校验。
  static bool isValidEntryName(String name) {
    final trimmed = name.trim();
    return trimmed.isNotEmpty &&
        trimmed != '.' &&
        trimmed != '..' &&
        !_illegalChars.hasMatch(trimmed);
  }

  /// 列出目录内容：文件夹优先，名称不区分大小写排序。
  static List<FileSystemEntity> listSortedSync(String dirPath) {
    final entities = Directory(dirPath).listSync(followLinks: false);
    int rank(FileSystemEntity e) => e is Directory ? 0 : 1;
    String name(FileSystemEntity e) => p.basename(e.path).toLowerCase();
    entities.sort((a, b) {
      final r = rank(a) - rank(b);
      return r != 0 ? r : name(a).compareTo(name(b));
    });
    return entities;
  }

  /// 根据扩展名选择文件图标。
  static IconData iconForFile(String fileName) {
    final ext = p.extension(fileName).toLowerCase();
    switch (ext) {
      case '.dart':
        return Icons.flutter_dash;
      case '.md':
      case '.txt':
        return Icons.article_outlined;
      case '.json':
        return Icons.data_object;
      case '.yaml':
      case '.yml':
      case '.toml':
      case '.ini':
      case '.properties':
      case '.xml':
        return Icons.settings_outlined;
      case '.png':
      case '.jpg':
      case '.jpeg':
      case '.gif':
      case '.webp':
      case '.bmp':
      case '.svg':
      case '.ico':
        return Icons.image_outlined;
      case '.mp3':
      case '.wav':
      case '.flac':
      case '.ogg':
        return Icons.music_note_outlined;
      case '.mp4':
      case '.mov':
      case '.avi':
      case '.mkv':
        return Icons.movie_outlined;
      case '.zip':
      case '.tar':
      case '.gz':
      case '.rar':
      case '.7z':
        return Icons.folder_zip_outlined;
      case '.exe':
      case '.dll':
      case '.so':
      case '.dylib':
      case '.bat':
      case '.sh':
      case '.ps1':
        return Icons.terminal_outlined;
      case '.ttf':
      case '.otf':
      case '.woff':
      case '.woff2':
        return Icons.font_download_outlined;
      case '.pdf':
        return Icons.picture_as_pdf_outlined;
      case '.lock':
        return Icons.lock_outline;
      case '.html':
      case '.htm':
      case '.css':
      case '.js':
      case '.mjs':
      case '.ts':
      case '.tsx':
      case '.jsx':
      case '.py':
      case '.java':
      case '.kt':
      case '.kts':
      case '.go':
      case '.rs':
      case '.c':
      case '.h':
      case '.cpp':
      case '.hpp':
      case '.cs':
      case '.php':
      case '.rb':
      case '.swift':
      case '.gradle':
      case '.sql':
      case '.cmake':
        return Icons.code_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }

  /// 在系统文件管理器中打开目录。
  static Future<void> revealInFileManager(String path) async {
    try {
      if (Platform.isWindows) {
        await Process.run('explorer.exe', [path]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [path]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [path]);
      }
    } catch (_) {
      // 打开失败时静默忽略。
    }
  }
}
