import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../config/api_config.dart';

import '../services/api_client.dart';
import '../services/app_paths.dart';
import '../services/project_templates.dart';

/// 云端项目条目（服务器返回）。
class CloudProjectInfo {
  const CloudProjectInfo({
    required this.id,
    required this.name,
    required this.fileCount,
  });

  final int id;
  final String name;
  final int fileCount;

  static CloudProjectInfo fromJson(Map<String, dynamic> j) => CloudProjectInfo(
    id: (j['id'] as num).toInt(),
    name: j['name'] as String,
    fileCount: (j['files'] as num?)?.toInt() ?? 0,
  );
}

/// 云端文件条目。
class CloudFileInfo {
  const CloudFileInfo({required this.path, required this.mtime});

  final String path;
  final double mtime;

  static CloudFileInfo fromJson(Map<String, dynamic> j) => CloudFileInfo(
    path: j['path'] as String,
    mtime: (j['mtime'] as num).toDouble(),
  );
}

/// 同步状态。
enum SyncState { idle, syncing, synced, offline }

/// 云端项目同步客户端：
/// 本地镜像目录（应用沙箱 cloud_projects/云端ID）与服务器逐文件同步。
/// - 拉取：打开项目时把服务器文件树下载到镜像目录
/// - 推送：编辑防抖后把单个文件 PUT 上去；保存立即推送
class CloudSyncService {
  CloudSyncService._({required this.cloudId, required this.localPath});

  final int cloudId;
  final String localPath;

  final _stateController = StreamController<SyncState>.broadcast();
  Stream<SyncState> get stateStream => _stateController.stream;
  SyncState _state = SyncState.idle;
  SyncState get state => _state;

  void _setState(SyncState s) {
    _state = s;
    if (!_stateController.isClosed) _stateController.add(s);
  }

  static Future<String> _cacheRoot() async {
    final env = Platform.environment['QFLI_TEST_HOME'];
    if (env != null && env.isNotEmpty) return env;
    final base = await AppPaths.storageDirectory();
    return p.join(
      base ?? Directory.systemTemp.path,
      'cloud_projects',
      Uri.encodeComponent(ApiConfig.origin),
    );
  }

  /// 打开（或创建）某个云端项目的本地镜像。
  static Future<CloudSyncService> open({
    required int cloudId,
    required String name,
    String? testHome,
  }) async {
    final localPath = testHome != null
        ? p.join(
            testHome,
            'cloud_projects',
            Uri.encodeComponent(ApiConfig.origin),
            '$cloudId',
          )
        : p.join(await _cacheRoot(), '$cloudId');
    await Directory(localPath).create(recursive: true);
    return CloudSyncService._(cloudId: cloudId, localPath: localPath);
  }

  /// 镜像目录中是否已有任何文件。
  bool existsAnyFile() {
    final dir = Directory(localPath);
    if (!dir.existsSync()) return false;
    for (final entity in dir.listSync(recursive: true, followLinks: false)) {
      if (entity is File) return true;
    }
    return false;
  }

  // ---- 拉取 ----

  /// 从服务器拉取文件树到镜像目录（服务器为准，覆盖本地）。
  Future<({int pulled, String? error})> pullAll({
    required String token,
    bool onlyIfMissing = false,
  }) async {
    _setState(SyncState.syncing);
    try {
      final client = ApiClient.instance;
      final data = await client.cloudFileTree(token, cloudId);
      final remote = [
        for (final f in (data['files'] as List? ?? []))
          CloudFileInfo.fromJson(f as Map<String, dynamic>),
      ];
      var pulled = 0;
      final remotePaths = <String>{};
      for (final info in remote) {
        remotePaths.add(info.path);
        final local = File(p.join(localPath, info.path));
        final exists = local.existsSync();
        if (onlyIfMissing && exists) continue;
        if (exists &&
            onlyIfMissing == false &&
            local.lastModifiedSync().millisecondsSinceEpoch / 1000 >=
                info.mtime) {
          // 本地不落后于服务器，跳过（避免覆盖未同步的本地修改）。
          continue;
        }
        final content = await client.cloudReadFile(token, cloudId, info.path);
        final bytes = base64Decode(content['content'] as String);
        await local.parent.create(recursive: true);
        await local.writeAsBytes(bytes, flush: true);
        pulled++;
      }
      // 删除服务器上已不存在的文件。
      if (!onlyIfMissing) {
        await _prune(localPath, localPath, remotePaths);
      }
      _setState(SyncState.synced);
      return (pulled: pulled, error: null);
    } on ApiException catch (e) {
      _setState(SyncState.offline);
      return (pulled: 0, error: e.message);
    }
  }

  Future<void> _prune(String dir, String root, Set<String> keep) async {
    await for (final entity in Directory(dir).list(followLinks: false)) {
      final rel = p.relative(entity.path, from: root).replaceAll(r'\', '/');
      if (entity is Directory) {
        await _prune(entity.path, root, keep);
        if (await Directory(entity.path).list().isEmpty) {
          await entity.delete();
        }
      } else if (!keep.contains(rel)) {
        await entity.delete();
      }
    }
  }

  // ---- 推送 ----

  /// 推送单个文件（编辑防抖 / 保存时调用）。
  Future<String?> pushFile(String token, String absolutePath) async {
    if (!p.isWithin(localPath, absolutePath)) return '文件不在云端项目目录内';
    final rel = p.relative(absolutePath, from: localPath).replaceAll(r'\', '/');
    _setState(SyncState.syncing);
    try {
      final bytes = await File(absolutePath).readAsBytes();
      await ApiClient.instance.cloudWriteFile(
        token,
        cloudId,
        rel,
        base64Encode(bytes),
      );
      _setState(SyncState.synced);
      return null;
    } on ApiException catch (e) {
      _setState(SyncState.offline);
      return e.message;
    }
  }

  /// 推送本地删除。
  Future<String?> pushDelete(String token, String absolutePath) async {
    if (!p.isWithin(localPath, absolutePath)) return null;
    final rel = p.relative(absolutePath, from: localPath).replaceAll(r'\', '/');
    _setState(SyncState.syncing);
    try {
      await ApiClient.instance.cloudDeleteFile(token, cloudId, rel);
      _setState(SyncState.synced);
      return null;
    } on ApiException catch (e) {
      _setState(SyncState.offline);
      return e.message;
    }
  }

  // ---- 创建 ----

  /// 在服务器创建云端项目并推送模板文件；返回服务器项目 ID。
  static Future<({int? id, String? error})> createCloudProject({
    required String token,
    required String name,
    required ProjectTemplate template,
  }) async {
    try {
      final created = await ApiClient.instance.cloudCreateProject(token, name);
      final id = (created['id'] as num).toInt();
      final service = await CloudSyncService.open(
        cloudId: id,
        name: name,
        testHome: Platform.environment['QFLI_TEST_HOME'],
      );
      final files = template.files.isEmpty
          ? [const TemplateFile('src/.gitkeep', '')]
          : template.files;
      for (final file in files) {
        await Directory(
          p.dirname(p.join(service.localPath, file.path)),
        ).create(recursive: true);
        await File(
          p.join(service.localPath, file.path),
        ).writeAsString(file.content, flush: true);
        await service.pushFile(token, p.join(service.localPath, file.path));
      }
      return (id: id, error: null);
    } on ApiException catch (e) {
      return (id: null, error: e.message);
    }
  }

  /// 服务器上的 git 操作（需服务器安装 git）。
  Future<({String stdout, String stderr, int exitCode})> git(
    String token,
    String action, {
    String? message,
    String? url,
  }) {
    return ApiClient.instance.cloudGit(
      token,
      cloudId,
      action: action,
      message: message,
      url: url,
    );
  }

  void dispose() {
    _stateController.close();
  }
}
