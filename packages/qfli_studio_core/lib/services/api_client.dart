import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../community/models.dart';
import '../config/api_config.dart';

/// API 调用异常：message 为用户可读文案。
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// azurekiln-qfli-server 的 HTTP 客户端。
class ApiClient {
  ApiClient({http.Client? transport}) : _transport = transport;

  final http.Client? _transport;
  // 延迟创建并复用连接，不在应用首帧初始化网络。
  late final http.Client _http = _transport ?? http.Client();

  static final ApiClient instance = ApiClient();

  void close() => _http.close();

  Map<String, String> _headers({String? token}) => {
    'content-type': 'application/json',
    if (token != null) 'authorization': 'Bearer $token',
  };

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, Object>? body,
    Map<String, Object>? query,
    String? token,
  }) async {
    final uri = ApiConfig.endpoint(path, query);
    try {
      final request = http.Request(method, uri)
        ..followRedirects = false
        ..headers.addAll(_headers(token: token));
      if (body != null) request.body = jsonEncode(body);
      final response = await _http
          .send(request)
          .then(http.Response.fromStream)
          .timeout(ApiConfig.requestTimeout);
      final text = utf8.decode(response.bodyBytes);
      dynamic data;
      try {
        data = text.isEmpty ? null : jsonDecode(text);
      } on FormatException {
        data = text;
      }
      if (response.statusCode >= 300) {
        final message = data is Map && data['error'] is String
            ? data['error'] as String
            : '服务暂时不可用（${response.statusCode}），请稍后重试';
        throw ApiException(message, statusCode: response.statusCode);
      }
      if (data != null && data is! Map && data is! List) {
        throw ApiException('服务响应异常，请稍后重试');
      }
      return data;
    } on SocketException catch (e) {
      throw ApiException('无法连接服务器：${e.message}');
    } on TimeoutException {
      throw ApiException('连接超时，请检查网络后重试');
    } on http.ClientException {
      throw ApiException('暂时无法连接服务，请检查网络后重试');
    } on HandshakeException {
      throw ApiException('无法建立安全连接，请检查设备时间或稍后重试');
    } on FormatException {
      throw ApiException('服务响应异常，请稍后重试');
    } on HttpException catch (e) {
      throw ApiException('网络错误：${e.message}');
    }
  }

  // ---- 认证 ----

  Future<({String token, CommunityUser user})> register(
    String username,
    String password,
    String? nickname,
  ) async {
    final data =
        await _send(
              'POST',
              '/api/auth/register',
              body: {
                'username': username,
                'password': password,
                if (nickname != null && nickname.isNotEmpty)
                  'nickname': nickname,
              },
            )
            as Map<String, dynamic>;
    return (
      token: data['token'] as String,
      user: CommunityUser.fromJson(data['user']),
    );
  }

  Future<({String token, CommunityUser user})> login(
    String username,
    String password,
  ) async {
    final data =
        await _send(
              'POST',
              '/api/auth/login',
              body: {'username': username, 'password': password},
            )
            as Map<String, dynamic>;
    return (
      token: data['token'] as String,
      user: CommunityUser.fromJson(data['user']),
    );
  }

  /// OAuth2 网关授权页地址；未配置网关时抛 ApiException（501）。
  Future<String> oauth2Url() async {
    final data =
        await _send('GET', '/api/auth/oauth2/url') as Map<String, dynamic>;
    return data['url'] as String;
  }

  Future<({String token, CommunityUser user})> oauth2Complete(
    String code,
  ) async {
    final data =
        await _send('POST', '/api/auth/oauth2/complete', body: {'code': code})
            as Map<String, dynamic>;
    return (
      token: data['token'] as String,
      user: CommunityUser.fromJson(data['user']),
    );
  }

  Future<({String token, CommunityUser user})> huaweiLogin(
    String authorizationCode,
  ) async {
    final data =
        await _send(
              'POST',
              '/api/auth/huawei',
              body: {'authorizationCode': authorizationCode},
            )
            as Map<String, dynamic>;
    return (
      token: data['token'] as String,
      user: CommunityUser.fromJson(data['user']),
    );
  }

  // ---- 用户 ----

  Future<CommunityUser> me(String token) async {
    final data =
        await _send('GET', '/api/users/me', token: token)
            as Map<String, dynamic>;
    return CommunityUser.fromJson(data['user']);
  }

  Future<CommunityUser> updateMe(
    String token, {
    String? nickname,
    String? bio,
    String? avatarColor,
  }) async {
    final data =
        await _send(
              'PATCH',
              '/api/users/me',
              token: token,
              body: {
                'nickname': ?nickname,
                'bio': ?bio,
                'avatarColor': ?avatarColor,
              },
            )
            as Map<String, dynamic>;
    return CommunityUser.fromJson(data['user']);
  }

  /// 我的信息 + 社区统计（发帖/评论/点赞数）。
  Future<({CommunityUser user, int posts, int comments, int likes})>
  meWithStats(String token) async {
    final data =
        await _send('GET', '/api/users/me', token: token)
            as Map<String, dynamic>;
    final stats = (data['stats'] ?? {}) as Map<String, dynamic>;
    return (
      user: CommunityUser.fromJson(data['user'] as Map<String, dynamic>),
      posts: (stats['posts'] as num?)?.toInt() ?? 0,
      comments: (stats['comments'] as num?)?.toInt() ?? 0,
      likes: (stats['likes_given'] as num?)?.toInt() ?? 0,
    );
  }

  /// 我的帖子列表（最近 50 篇）。
  Future<List<Map<String, dynamic>>> myPosts(String token) async {
    final data =
        await _send('GET', '/api/users/me/posts', token: token)
            as Map<String, dynamic>;
    return [
      for (final item in (data['items'] as List? ?? []))
        Map<String, dynamic>.from(item as Map),
    ];
  }

  Future<({bool checkedToday, int streak, int points, List<TaskInfo> tasks})>
  tasks(String token) async {
    final data =
        await _send('GET', '/api/users/me/tasks', token: token)
            as Map<String, dynamic>;
    return (
      checkedToday: data['checkedToday'] as bool? ?? false,
      streak: (data['streak'] as num?)?.toInt() ?? 0,
      points: (data['points'] as num?)?.toInt() ?? 0,
      tasks: [
        for (final t in (data['tasks'] as List? ?? []))
          TaskInfo.fromJson(t as Map<String, dynamic>),
      ],
    );
  }

  Future<({int streak, int points, int reward, bool alreadyChecked})> checkin(
    String token,
  ) async {
    final data =
        await _send('POST', '/api/users/me/checkin', token: token)
            as Map<String, dynamic>;
    return (
      streak: (data['streak'] as num?)?.toInt() ?? 0,
      points: (data['points'] as num?)?.toInt() ?? 0,
      reward: (data['reward'] as num?)?.toInt() ?? 0,
      alreadyChecked: data['alreadyChecked'] as bool? ?? false,
    );
  }

  // ---- 社区 ----

  Future<List<Zone>> zones() async {
    final data = await _send('GET', '/api/zones') as Map<String, dynamic>;
    return [
      for (final z in (data['items'] as List? ?? []))
        Zone.fromJson(z as Map<String, dynamic>),
    ];
  }

  Future<List<TagCount>> tags({String? type, int? zoneId}) async {
    final data =
        await _send(
              'GET',
              '/api/tags',
              query: {'type': ?type, 'zoneId': ?zoneId},
            )
            as Map<String, dynamic>;
    return [
      for (final t in (data['items'] as List? ?? []))
        TagCount.fromJson(t as Map<String, dynamic>),
    ];
  }

  Future<({List<Post> items, int total})> posts({
    String? type,
    int? zoneId,
    String? tag,
    String? keyword,
    int page = 1,
    String? token,
  }) async {
    final data =
        await _send(
              'GET',
              '/api/posts',
              token: token,
              query: {
                'type': ?type,
                'zoneId': ?zoneId,
                if (tag != null && tag.isNotEmpty) 'tag': tag,
                if (keyword != null && keyword.isNotEmpty) 'q': keyword,
                'page': page,
                'pageSize': 20,
              },
            )
            as Map<String, dynamic>;
    return (
      items: [
        for (final p in (data['items'] as List? ?? []))
          Post.fromJson(p as Map<String, dynamic>),
      ],
      total: (data['total'] as num?)?.toInt() ?? 0,
    );
  }

  Future<Post> postDetail(int id, {String? token}) async {
    final data =
        await _send('GET', '/api/posts/$id', token: token)
            as Map<String, dynamic>;
    return Post.fromJson(data['post'] as Map<String, dynamic>);
  }

  Future<int> createPost({
    required String token,
    required String type,
    required int zoneId,
    required String title,
    required String content,
    required List<String> tags,
  }) async {
    final data =
        await _send(
              'POST',
              '/api/posts',
              token: token,
              body: {
                'type': type,
                'zoneId': zoneId,
                'title': title,
                'content': content,
                'tags': tags,
              },
            )
            as Map<String, dynamic>;
    return (data['id'] as num).toInt();
  }

  Future<void> deletePost(String token, int id) async {
    await _send('DELETE', '/api/posts/$id', token: token);
  }

  Future<({bool liked, int likeCount})> toggleLike(
    String token,
    int postId,
  ) async {
    final data =
        await _send('POST', '/api/posts/$postId/like', token: token)
            as Map<String, dynamic>;
    return (
      liked: data['liked'] as bool,
      likeCount: (data['likeCount'] as num).toInt(),
    );
  }

  Future<List<Comment>> comments(int postId) async {
    final data =
        await _send('GET', '/api/posts/$postId/comments')
            as Map<String, dynamic>;
    return [
      for (final c in (data['items'] as List? ?? []))
        Comment.fromJson(c as Map<String, dynamic>),
    ];
  }

  Future<Comment> addComment(
    String token,
    int postId, {
    required String content,
    int? parentId,
  }) async {
    final data =
        await _send(
              'POST',
              '/api/posts/$postId/comments',
              token: token,
              body: {'content': content, 'parentId': ?parentId},
            )
            as Map<String, dynamic>;
    return Comment.fromJson(data['comment'] as Map<String, dynamic>);
  }

  // ---- 在线终端 ----

  Future<({String stdout, String stderr, int exitCode})> terminalExec(
    String token,
    String command,
  ) async {
    final data =
        await _send(
              'POST',
              '/api/terminal/exec',
              token: token,
              body: {'command': command},
            )
            as Map<String, dynamic>;
    return (
      stdout: data['stdout'] as String? ?? '',
      stderr: data['stderr'] as String? ?? '',
      exitCode: (data['exitCode'] as num?)?.toInt() ?? 1,
    );
  }

  // ---- 云端项目（私有云盘）----

  Future<List<Map<String, dynamic>>> cloudProjects(String token) async {
    final data =
        await _send('GET', '/api/cloud/projects', token: token)
            as Map<String, dynamic>;
    return [
      for (final p in (data['items'] as List? ?? []))
        Map<String, dynamic>.from(p as Map),
    ];
  }

  Future<Map<String, dynamic>> cloudCreateProject(
    String token,
    String name,
  ) async {
    return await _send(
          'POST',
          '/api/cloud/projects',
          token: token,
          body: {'name': name},
        )
        as Map<String, dynamic>;
  }

  Future<void> cloudDeleteProject(String token, int id) async {
    await _send('DELETE', '/api/cloud/projects/$id', token: token);
  }

  Future<Map<String, dynamic>> cloudFileTree(String token, int id) async {
    return await _send('GET', '/api/cloud/projects/$id/files', token: token)
        as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> cloudReadFile(
    String token,
    int id,
    String path,
  ) async {
    return await _send(
          'GET',
          '/api/cloud/projects/$id/file',
          token: token,
          query: {'path': path},
        )
        as Map<String, dynamic>;
  }

  Future<void> cloudWriteFile(
    String token,
    int id,
    String path,
    String base64Content,
  ) async {
    await _send(
      'PUT',
      '/api/cloud/projects/$id/file',
      token: token,
      body: {'path': path, 'content': base64Content},
    );
  }

  Future<void> cloudDeleteFile(String token, int id, String path) async {
    await _send(
      'DELETE',
      '/api/cloud/projects/$id/file',
      token: token,
      query: {'path': path},
    );
  }

  Future<({String stdout, String stderr, int exitCode})> cloudGit(
    String token,
    int id, {
    required String action,
    String? message,
    String? url,
  }) async {
    final data =
        await _send(
              'POST',
              '/api/cloud/projects/$id/git',
              token: token,
              body: {'action': action, 'message': ?message, 'url': ?url},
            )
            as Map<String, dynamic>;
    return (
      stdout: data['stdout'] as String? ?? '',
      stderr: data['stderr'] as String? ?? '',
      exitCode: (data['exitCode'] as num?)?.toInt() ?? 1,
    );
  }

  /// 审计日志（仅管理员），分页倒序。
  Future<({List<Map<String, dynamic>> items, int total})> auditLogs(
    String token, {
    int page = 1,
    String? action,
    String? user,
  }) async {
    final data =
        await _send(
              'GET',
              '/api/audit',
              token: token,
              query: {
                'page': page,
                'pageSize': 50,
                'action': ?action,
                'user': ?user,
              },
            )
            as Map<String, dynamic>;
    return (
      items: [
        for (final r in (data['items'] as List? ?? []))
          Map<String, dynamic>.from(r as Map),
      ],
      total: (data['total'] as num?)?.toInt() ?? 0,
    );
  }

  Future<bool> health() async {
    try {
      final data = await _send('GET', '/api/health');
      return data is Map && data['ok'] == true;
    } on ApiException {
      return false;
    }
  }
}

/// 调试用：dump 响应（release 无操作）。
void debugLogResponse(Object? data) {
  if (kDebugMode) {
    debugPrint('[api] $data');
  }
}
