import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../community/models.dart';
import '../config/api_config.dart';
import '../services/api_client.dart';
import '../services/app_paths.dart';

/// 登录状态与个人资料的持久化（auth.json）。
class AuthStore extends ChangeNotifier {
  AuthStore({File? storageFile}) : _storageOverride = storageFile;

  final File? _storageOverride;
  File? _storage;

  String? _token;
  CommunityUser? _user;

  bool get isLoggedIn => _token != null && _user != null;
  String? get token => _token;
  CommunityUser? get user => _user;

  Future<void> load() async {
    try {
      _storage = _storageOverride ?? await _resolveStorage();
      if (await _storage!.exists()) {
        final data =
            jsonDecode(await _storage!.readAsString()) as Map<String, dynamic>;
        final source = data['serviceOrigin'] ?? data['serverUrl'];
        final trusted = source is String && ApiConfig.ownsSession(source);
        _token = trusted ? data['token'] as String? : null;
        _user = null;
        if (trusted && data['user'] is Map) {
          _user = CommunityUser.fromJson(
            Map<String, dynamic>.from(data['user'] as Map),
          );
        }
        // 移除旧服务器配置；不同来源的登录信息不会发送给官方服务。
        if (data.containsKey('serverUrl') || !trusted) await _persist();
      }
    } catch (_) {
      // 配置损坏时按未登录处理。
      _token = null;
      _user = null;
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
        'serviceOrigin': ApiConfig.origin,
        if (_token != null) 'token': _token,
        if (_user != null)
          'user': {
            'id': _user!.id,
            'username': _user!.username,
            'nickname': _user!.nickname,
            'bio': _user!.bio,
            'avatarColor': _user!.avatarColor,
            'points': _user!.points,
            'checkinStreak': _user!.checkinStreak,
            'provider': _user!.provider,
            'isAdmin': _user!.isAdmin,
          },
      }),
    );
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
    if (token == null) return;
    try {
      final fresh = await client.me(token);
      if (_token != token) return;
      _user = fresh;
      await _persist();
      notifyListeners();
    } on ApiException {
      // 网络不通时保留本地缓存。
    }
  }

  Future<void> updateProfile({String? nickname, String? bio}) async {
    final token = _token;
    final client = ApiClient.instance;
    if (token == null) return;
    final fresh = await client.updateMe(token, nickname: nickname, bio: bio);
    if (_token != token) return;
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
      isAdmin: _user!.isAdmin,
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
