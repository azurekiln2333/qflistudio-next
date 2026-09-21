import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:qfli_studio_core/config/api_config.dart';
import 'package:qfli_studio_core/models/project.dart';
import 'package:qfli_studio_core/services/api_client.dart';
import 'package:qfli_studio_core/services/cloud_sync_service.dart';
import 'package:qfli_studio_core/store/auth_store.dart';

const _user = {
  'id': 12,
  'username': 'demo',
  'nickname': '开发者',
  'bio': '',
  'avatarColor': '#2196F3',
  'points': 10,
  'checkinStreak': 2,
  'provider': 'local',
  'isAdmin': true,
};

void main() {
  test('旧云镜像保留为本地副本，官方缓存不复用旧服务器目录', () async {
    final directory = await Directory.systemTemp.createTemp(
      'qfli_cloud_origin_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final legacy = Directory(p.join(directory.path, 'cloud_projects', '7'));
    await legacy.create(recursive: true);
    final oldFile = File(p.join(legacy.path, 'old.txt'));
    await oldFile.writeAsString('legacy project');
    final project = Project.create(
      name: 'demo',
      path: legacy.path,
      cloudId: '7',
    );
    final oldJson = project.toJson()..remove('cloudOrigin');
    final local = Project.fromJson(oldJson);
    expect(local.isCloud, isFalse);
    expect(local.path, legacy.path);
    expect(Project.fromJson(project.toJson()).isCloud, isTrue);
    final service = await CloudSyncService.open(
      cloudId: 7,
      name: 'demo',
      testHome: directory.path,
    );
    expect(service.localPath, isNot(legacy.path));
    expect(service.existsAnyFile(), isFalse);
    expect(await oldFile.readAsString(), 'legacy project');
    service.dispose();
  });

  test('账号、社区、云端与终端共用固定 HTTPS 域名', () async {
    final requests = <http.Request>[];
    final client = ApiClient(
      transport: MockClient((request) async {
        requests.add(request);
        final Object data = switch (request.url.path) {
          '/api/auth/login' => {'token': 'test-token', 'user': _user},
          '/api/zones' => {'items': []},
          '/api/cloud/projects' => {'items': []},
          '/api/terminal/exec' => {'stdout': 'ok', 'stderr': '', 'exitCode': 0},
          _ => {'ok': true},
        };
        return http.Response(
          jsonEncode(data),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    addTearDown(client.close);
    final auth = await client.login('demo', 'sample-password');
    expect(auth.user.nickname, '开发者');
    await client.zones();
    await client.cloudProjects(auth.token);
    await client.terminalExec(auth.token, 'pwd');
    expect(requests, hasLength(4));
    for (final request in requests) {
      expect(request.url.origin, 'https://qfli.lqsxm666.top');
      expect(request.followRedirects, isFalse);
    }
    expect(requests[0].headers['authorization'], isNull);
    expect(requests[2].headers['authorization'], 'Bearer test-token');
    expect(requests[3].headers['authorization'], 'Bearer test-token');
  });

  test('查询参数正确转义，绝对 URL 不能替换服务来源', () {
    final uri = ApiConfig.endpoint('/api/posts', {
      'keyword': '中文 & #x',
      'page': 2,
    });
    expect(uri.queryParameters['keyword'], '中文 & #x');
    expect(uri.queryParameters['page'], '2');
    expect(
      () => ApiConfig.endpoint('https://example.com/api/posts'),
      throwsArgumentError,
    );
    expect(ApiConfig.ownsSession('https://qfli.lqsxm666.top/'), isTrue);
    expect(
      ApiConfig.ownsSession('https://qfli.lqsxm666.top.example.org'),
      isFalse,
    );
    expect(ApiConfig.ownsSession('https://name@qfli.lqsxm666.top'), isFalse);
    expect(ApiConfig.ownsSession('http://qfli.lqsxm666.top'), isFalse);
  });

  test('网关 HTML、重定向、网络失败均返回可重试的 API 错误', () async {
    for (final response in [
      http.Response('<html>Unavailable</html>', 200),
      http.Response('', 302, headers: {'location': 'https://example.org'}),
      http.Response(
        '{"error":"稍后重试"}',
        503,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
    ]) {
      final client = ApiClient(transport: MockClient((_) async => response));
      await expectLater(client.zones(), throwsA(isA<ApiException>()));
      client.close();
    }
    final offline = ApiClient(
      transport: MockClient((_) async => throw http.ClientException('offline')),
    );
    await expectLater(offline.zones(), throwsA(isA<ApiException>()));
    offline.close();
  });

  test('DELETE 的 204 响应无需 JSON 正文', () async {
    final client = ApiClient(
      transport: MockClient((_) async => http.Response('', 204)),
    );
    addTearDown(client.close);
    await client.deletePost('test-token', 1);
  });

  group('登录态迁移', () {
    late Directory directory;
    late File file;
    setUp(() async {
      directory = await Directory.systemTemp.createTemp('qfli_auth_migration_');
      file = File(p.join(directory.path, 'auth.json'));
    });
    tearDown(() async => directory.delete(recursive: true));

    test('旧自定义服务器令牌不会发送给官方服务', () async {
      await file.writeAsString(
        jsonEncode({
          'serverUrl': 'http://192.168.1.100:3000',
          'token': 'old-server-token',
          'user': _user,
        }),
      );
      final auth = AuthStore(storageFile: file);
      addTearDown(auth.dispose);
      await auth.load();
      expect(auth.isLoggedIn, isFalse);
      final persisted = jsonDecode(await file.readAsString()) as Map;
      expect(persisted['serverUrl'], isNull);
      expect(persisted['token'], isNull);
      expect(persisted['serviceOrigin'], ApiConfig.origin);
    });

    test('同源会话保留，管理员状态随资料与积分一起持久化', () async {
      await file.writeAsString(
        jsonEncode({
          'serverUrl': '${ApiConfig.baseUrl}/',
          'token': 'official-token',
          'user': _user,
        }),
      );
      final auth = AuthStore(storageFile: file);
      addTearDown(auth.dispose);
      await auth.load();
      expect(auth.isLoggedIn, isTrue);
      expect(auth.user!.isAdmin, isTrue);
      auth.updatePoints(points: 20);
      expect(auth.user!.isAdmin, isTrue);
      await auth.signIn(auth.token!, auth.user!);
      final restored = AuthStore(storageFile: file);
      addTearDown(restored.dispose);
      await restored.load();
      expect(restored.user!.points, 20);
      expect(restored.user!.isAdmin, isTrue);
      await restored.signOut();
      expect((jsonDecode(await file.readAsString()) as Map)['token'], isNull);
    });

    test('无来源或损坏的旧缓存不能构成登录态', () async {
      await file.writeAsString(
        jsonEncode({'token': 'unknown-token', 'user': _user}),
      );
      final auth = AuthStore(storageFile: file);
      addTearDown(auth.dispose);
      await auth.load();
      expect(auth.isLoggedIn, isFalse);
      await file.writeAsString('{invalid json');
      await auth.load();
      expect(auth.token, isNull);
      expect(auth.user, isNull);
    });
  });
}
