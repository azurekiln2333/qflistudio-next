import 'dart:math';

import 'package:path/path.dart' as p;

import '../config/api_config.dart';

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
    this.type = '',
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

  /// Stable source-language discriminator, for example `cpp` or `python`.
  String type;

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
    String type = '',
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
      type: type,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'path': path,
    'createdAt': createdAt.toIso8601String(),
    'lastOpenedAt': lastOpenedAt.toIso8601String(),
    if (cloudId != null) 'cloudId': cloudId,
    if (cloudId != null) 'cloudOrigin': ApiConfig.origin,
    'favorite': favorite,
    'language': language,
    'type': type,
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
      // 旧自定义服务器的 ID 不能直接拿到官方服务使用。
      // 来源不明的旧镜像保留为本地项目，用户可重新刷新导入官方云目录。
      cloudId: ApiConfig.ownsSession(json['cloudOrigin'] as String?)
          ? json['cloudId'] as String?
          : null,
      favorite: json['favorite'] as bool? ?? false,
      language: json['language'] as String? ?? '',
      type: json['type'] as String? ?? '',
    );
  }
}
