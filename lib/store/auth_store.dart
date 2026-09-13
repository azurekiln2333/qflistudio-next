import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../community/models.dart';
import '../services/api_client.dart';
import '../services/app_paths.dart';

/// 登录状态与个人资料的持久化（auth.json）。
class AuthStore extends ChangeNotifier {
  AuthStore({File? storageFile}) : _storageOverride = storageFile;

  final File? _storageOverride;
  File? _storage;

  String? _token;
  CommunityUser? _user;
  String? _serverUrl;

  bool get isLoggedIn => _token != null && _user != null;
  String? get token => _token;
  CommunityUser? get user => _user;
  String? get serverUrl => _serverUrl;

  Future<void> load() async {
    try {
      _storage = _storageOverride ?? await _resolveStorage();
      if (await _storage!.exists()) {
        final data =
            jsonDecode(await _storage!.readAsString()) as Map<String, dynamic>;
        _serverUrl = data['serverUrl'] as String?;
        _token = data['token'] as String?;
        if (data['user'] is Map) {
          _user = CommunityUser.fromJson(
            Map<String, dynamic>.from(data['user'] as Map),
          );
        }
        if (_serverUrl != null && _serverUrl!.isNotEmpty) {
          ApiClient.configure(_serverUrl!);
        }
      }
    } catch (_) {
      // 配置损坏时按未登录处理。
    }
    notifyListeners();
  }

  Future<File> _resolveStorage() async {
    final base = await AppPaths.storageDirectory();
    if (base == null) throw const FileSystemException('未找到可写目录');
    return File(p.join(base, 'auth.json'));
  }

  Future<void> _persist() async {
    final file = _storage;
    if (file == null) return;
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        if (_serverUrl != null) 'serverUrl': _serverUrl,
        if (_token != null) 'token': _token,
        if (_user != null) 'user': {
          'id': _user!.id,
          'username': _user!.username,
          'nickname': _user!.nickname,
          'bio': _user!.bio,
          'avatarColor': _user!.avatarColor,
          'points': _user!.points,
          'checkinStreak': _user!.checkinStreak,
          'provider': _user!.provider,
        },
      }),
    );
  }

  /// 配置服务器地址并连通性检查；失败返回错误文案。
  Future<String?> setServer(String url) async {
    final client = ApiClient.configure(url);
    final ok = await client.health();
    if (!ok) {
      return '无法连接 $url，请确认服务器已启动且地址正确';
    }
    _serverUrl = client.baseUrl;
    await _persist();
    notifyListeners();
    return null;
  }

  Future<void> signIn(String token, CommunityUser user) async {
    _token = token;
    _user = user;
    await _persist();
    notifyListeners();
  }

  /// 刷新资料（进入我的页/编辑资料后调用）。
  Future<void> refreshMe() async {
    final token = _token;
    final client = ApiClient.instance;
    if (token == null || client == null) return;
    try {
      final fresh = await client.me(token);
      _user = CommunityUser(
        id: fresh.id,
        username: fresh.username,
        nickname: fresh.nickname,
        bio: fresh.bio,
        avatarColor: fresh.avatarColor,
        points: fresh.points,
        checkinStreak: fresh.checkinStreak,
        provider: fresh.provider,
      );
      await _persist();
      notifyListeners();
    } on ApiException {
      // 网络不通时保留本地缓存。
    }
  }

  Future<void> updateProfile({String? nickname, String? bio}) async {
    final token = _token;
    final client = ApiClient.instance;
    if (token == null || client == null) return;
    final fresh = await client.updateMe(token, nickname: nickname, bio: bio);
    _user = fresh;
    await _persist();
    notifyListeners();
  }

  void updatePoints({int? points, int? streak}) {
    if (_user == null) return;
    _user = CommunityUser(
      id: _user!.id,
      username: _user!.username,
      nickname: _user!.nickname,
      bio: _user!.bio,
      avatarColor: _user!.avatarColor,
      points: points ?? _user!.points,
      checkinStreak: streak ?? _user!.checkinStreak,
      provider: _user!.provider,
    );
    notifyListeners();
  }

  Future<void> signOut() async {
    _token = null;
    _user = null;
    await _persist();
    notifyListeners();
  }
}
