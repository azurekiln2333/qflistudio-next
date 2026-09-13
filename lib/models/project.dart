import 'dart:math';

import 'package:path/path.dart' as p;

/// 一个已注册到 QFLIStudio+ 的项目。
class Project {
  Project({
    required this.id,
    required this.name,
    required this.path,
    required this.createdAt,
    required this.lastOpenedAt,
    this.cloudId,
    this.favorite = false,
    this.language = '',
  });

  final String id;
  String name;
  String path;
  DateTime createdAt;
  DateTime lastOpenedAt;

  /// 云端项目在服务器上的数字 ID（字符串存储）；本地项目为 null。
  final String? cloudId;

  /// 是否已收藏。
  bool favorite;

  /// 语言标注：优先来自项目配置文件 .qfli/project.json；
  /// 创建时来自模板，添加已有文件夹时按扩展名检测并写入配置。
  String language;

  bool get isCloud => cloudId != null;

  static String _newId() {
    final rnd = Random();
    final stamp = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    return '$stamp-${rnd.nextInt(36 * 36 * 36).toRadixString(36)}';
  }

  factory Project.create({
    required String name,
    required String path,
    String? cloudId,
    bool favorite = false,
    String language = '',
  }) {
    final now = DateTime.now();
    return Project(
      id: _newId(),
      name: name,
      path: path,
      createdAt: now,
      lastOpenedAt: now,
      cloudId: cloudId,
      favorite: favorite,
      language: language,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'path': path,
    'createdAt': createdAt.toIso8601String(),
    'lastOpenedAt': lastOpenedAt.toIso8601String(),
    if (cloudId != null) 'cloudId': cloudId,
    'favorite': favorite,
    'language': language,
  };

  static Project fromJson(Map<String, dynamic> json) {
    final path = json['path'] as String? ?? '';
    final created =
        DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now();
    return Project(
      id: json['id'] as String? ?? _newId(),
      name: (json['name'] as String?) ?? p.basename(path),
      path: path,
      createdAt: created,
      lastOpenedAt:
          DateTime.tryParse(json['lastOpenedAt'] as String? ?? '') ?? created,
      cloudId: json['cloudId'] as String?,
      favorite: json['favorite'] as bool? ?? false,
      language: json['language'] as String? ?? '',
    );
  }
}
