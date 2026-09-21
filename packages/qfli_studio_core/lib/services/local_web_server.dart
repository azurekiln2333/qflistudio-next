import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// 页面注入脚本：劫持 console 与 window.onerror，
/// 把日志转发到预览服务器 /__debug，由编辑器的调试输出显示。
/// （即使预览页面打开在系统浏览器中，日志也能回传到 App。）
const String _debugInjectScript = '<script>\n'
    '(function () {\n'
    '  var send = function (level) {\n'
    '    return function () {\n'
    '      var parts = [];\n'
    '      for (var i = 0; i < arguments.length; i++) {\n'
    '        var a = arguments[i];\n'
    '        try { parts.push(typeof a === "object" ? JSON.stringify(a) : String(a)); }\n'
    '        catch (e) { parts.push(String(a)); }\n'
    '      }\n'
    '      try {\n'
    '        fetch("/__debug", {\n'
    '          method: "POST",\n'
    '          headers: { "content-type": "application/x-www-form-urlencoded" },\n'
    '          body: "l=" + encodeURIComponent(level) + "&m=" + encodeURIComponent(parts.join(" "))\n'
    '        });\n'
    '      } catch (e) {}\n'
    '    };\n'
    '  };\n'
    '  ["log", "info", "warn", "error"].forEach(function (k) {\n'
    '    var orig = console[k] ? console[k].bind(console) : function () {};\n'
    '    console[k] = function () { send(k).apply(null, arguments); orig.apply(null, arguments); };\n'
    '  });\n'
    '  window.onerror = function (msg, src, line) {\n'
    '    send("error")("Uncaught: " + msg + " @" + (line || ""));\n'
    '  };\n'
    '})();\n'
    '</script>\n';

/// 项目内静态文件服务器：绑定 127.0.0.1 随机端口，供 HTML 项目预览。
/// 预览 HTML 会注入调试桥，收集页面 console 日志（系统浏览器打开也有效）。
class LocalWebServer {
  LocalWebServer._(this._server, this.rootDir, this.port);

  final HttpServer _server;
  final String rootDir;
  final int port;
  final StreamController<String> _debugController =
      StreamController<String>.broadcast();
  final List<String> _debugBuffer = [];

  String get url => 'http://127.0.0.1:$port/index.html';

  /// 页面日志流。
  Stream<String> get debugStream => _debugController.stream;

  /// 已收到的日志（历史缓冲）。
  List<String> get debugBuffer => List.unmodifiable(_debugBuffer);

  static Future<LocalWebServer> start(String rootDir) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final instance = LocalWebServer._(server, rootDir, server.port);
    server.listen(instance._handle);
    return instance;
  }

  Future<void> stop() async {
    await _debugController.close();
    await _server.close(force: true);
  }

  Future<void> _handle(HttpRequest request) async {
    if (request.method == 'POST' && request.uri.path == '/__debug') {
      final body = await request
          .cast<List<int>>()
          .transform(utf8.decoder)
          .join();
      await request.response.close();
      var level = 'log';
      var msg = '';
      for (final pair in body.split('&')) {
        final kv = pair.split('=');
        if (kv.length != 2) continue;
        final value = Uri.decodeComponent(kv[1]);
        if (kv[0] == 'l') level = value;
        if (kv[0] == 'm') msg = value;
      }
      final shownLevel = level == 'log' ? 'debug' : level;
      final line = '[web.$shownLevel] ${msg.isEmpty ? '(空)' : msg}';
      _debugBuffer.add(line);
      if (_debugBuffer.length > 500) _debugBuffer.removeRange(0, 100);
      if (!_debugController.isClosed) _debugController.add(line);
      return;
    }
    try {
      var path = Uri.decodeComponent(request.uri.path);
      if (path.endsWith('/')) path += 'index.html';
      final relative = path.replaceFirst(RegExp(r'^/'), '');
      var file = File(p.join(rootDir, relative));
      // 防目录穿越。
      final root = p.canonicalize(rootDir);
      if (!p.isWithin(root, p.canonicalize(file.path))) {
        await _respond(request, HttpStatus.forbidden, 'Forbidden');
        return;
      }
      if (!file.existsSync()) {
        file = File(p.join(rootDir, 'index.html'));
      }
      if (!file.existsSync()) {
        file = File(p.join(rootDir, 'src', 'index.html'));
      }
      if (!file.existsSync()) {
        await _respond(request, HttpStatus.notFound, 'Not Found');
        return;
      }
      final bytes = await file.readAsBytes();
      final ext = p.extension(file.path).toLowerCase();
      if (ext == '.html' || ext == '.htm') {
        var html = utf8.decode(bytes, allowMalformed: true);
        final injectAt = html.indexOf('</head>');
        html = injectAt >= 0
            ? html.replaceFirst('</head>', '$_debugInjectScript</head>')
            : '$_debugInjectScript$html';
        request.response.headers.contentType =
            ContentType.parse('text/html; charset=utf-8');
        request.response.add(utf8.encode(html));
      } else {
        request.response.headers.contentType =
            ContentType.parse(_contentType(file.path));
        request.response.add(bytes);
      }
      await request.response.close();
    } catch (_) {
      try {
        await _respond(request, HttpStatus.internalServerError, 'Error');
      } catch (_) {}
    }
  }

  Future<void> _respond(HttpRequest request, int status, String body) async {
    request.response.statusCode = status;
    request.response.headers.contentType = ContentType.text;
    request.response.write(body);
    await request.response.close();
  }

  static String _contentType(String path) {
    final ext = p.extension(path).toLowerCase();
    switch (ext) {
      case '.html':
      case '.htm':
        return 'text/html; charset=utf-8';
      case '.css':
        return 'text/css; charset=utf-8';
      case '.js':
      case '.mjs':
        return 'text/javascript; charset=utf-8';
      case '.json':
        return 'application/json; charset=utf-8';
      case '.png':
        return 'image/png';
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.gif':
        return 'image/gif';
      case '.svg':
        return 'image/svg+xml';
      case '.ico':
        return 'image/x-icon';
      case '.webp':
        return 'image/webp';
      case '.woff':
        return 'font/woff';
      case '.woff2':
        return 'font/woff2';
      case '.mp3':
        return 'audio/mpeg';
      case '.mp4':
        return 'video/mp4';
      default:
        return 'application/octet-stream';
    }
  }
}

/// 在系统浏览器/WebView 中打开 URL。
abstract final class UrlOpener {
  static Future<void> open(String url) async {
    if (Platform.isWindows) {
      await Process.run('cmd', ['/c', 'start', '', url], runInShell: false);
    } else if (Platform.isMacOS) {
      await Process.run('open', [url]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [url]);
    }
    // ohos/android 的浏览器拉起由原生通道实现。
  }
}
