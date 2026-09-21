import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// AI 回复中的一段内容：纯文本或代码块。
class AiSegment {
  const AiSegment.text(this.text)
      : isCode = false,
        code = null,
        lang = null,
        path = null;
  const AiSegment.code(this.code, {this.lang, this.path})
      : isCode = true,
        text = null;

  final bool isCode;
  final String? text;
  final String? code;

  /// 代码块语言（```python:src/main.py 的 python）。
  final String? lang;

  /// 代码块标注的目标文件路径（相对项目根），null 表示未指定。
  final String? path;
}

/// AI 服务：OpenAI 兼容的 chat/completions 流式客户端。
abstract final class AiService {
  static const Duration _timeout = Duration(seconds: 180);

  /// 由用户填写的接口地址推导 chat/completions 端点：
  /// - 已含 /chat/completions：原样使用（支持完整自定义端点）
  /// - 以 /v1 结尾：追加 /chat/completions
  /// - 其余：追加 /v1/chat/completions
  static String endpoint(String baseUrl) {
    var base = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    if (base.isEmpty) return base;
    if (base.contains('/chat/completions')) return base;
    if (base.toLowerCase().endsWith('/v1')) return '$base/chat/completions';
    return '$base/v1/chat/completions';
  }

  /// 解析回复中的 ```代码块```，提取标注的文件路径。
  /// 支持三种栅栏标注：```lang:path、```path.ext、```lang。
  static List<AiSegment> parseSegments(String content) {
    final segments = <AiSegment>[];
    final fence = RegExp(r'^```(.*)$', multiLine: true);
    var cursor = 0;
    while (true) {
      final open = fence.firstMatch(content.substring(cursor));
      if (open == null) break;
      final textStart = cursor + open.start;
      if (textStart > cursor) {
        segments.add(AiSegment.text(content.substring(cursor, textStart)));
      }
      final info = open.group(1)!.trim();
      final lang = _fenceLang(info);
      final path = _fencePath(info);
      final bodyStart = cursor + open.end + 1; // 跳过栅栏行后的换行
      final close = content.indexOf('```', bodyStart);
      if (close < 0) {
        // 未闭合：剩余内容都算代码。
        segments.add(AiSegment.code(
          content.substring(bodyStart),
          lang: lang,
          path: path,
        ));
        cursor = content.length;
        break;
      }
      segments.add(AiSegment.code(
        content.substring(bodyStart, close),
        lang: lang,
        path: path,
      ));
      cursor = close + 3;
    }
    if (cursor < content.length) {
      segments.add(AiSegment.text(content.substring(cursor)));
    }
    return segments;
  }

  /// 流式对话：逐段产出模型增量文本。
  /// [baseUrl]/[apiKey]/[model] 来自用户设置；[messages] 为完整对话历史。
  static Stream<String> chat({
    required String baseUrl,
    required String apiKey,
    required String model,
    required List<({String role, String content})> messages,
    String? systemPrompt,
  }) async* {
    final endpoint = endpointFor(baseUrl);
    if (endpoint.isEmpty) {
      throw const AiException('请先在设置中配置 AI 接口地址');
    }
    final uri = Uri.parse(endpoint);
    try {
      final request = await HttpClient()
          .postUrl(uri)
          .timeout(const Duration(seconds: 20));
      request.headers.set('content-type', 'application/json');
      if (apiKey.trim().isNotEmpty) {
        request.headers.set('authorization', 'Bearer ${apiKey.trim()}');
      }
      final body = <String, dynamic>{
        'model': model.trim(),
        'stream': true,
        'messages': [
          if (systemPrompt != null && systemPrompt.isNotEmpty)
            {'role': 'system', 'content': systemPrompt},
          for (final m in messages)
            {'role': m.role, 'content': m.content},
        ],
      };
      request.add(utf8.encode(jsonEncode(body)));
      final response = await request.close().timeout(_timeout);
      if (response.statusCode >= 400) {
        final text =
            await response.transform(utf8.decoder).join().timeout(const Duration(seconds: 10));
        String message = '接口错误（${response.statusCode}）';
        try {
          final data = jsonDecode(text);
          if (data is Map && data['error'] is Map) {
            message = '${data['error']['message'] ?? message}';
          } else if (data is Map && data['message'] is String) {
            message = data['message'];
          }
        } on FormatException {
          if (text.trim().isNotEmpty) message = text.trim();
        }
        throw AiException(message);
      }

      final isSse =
          (response.headers.contentType?.mimeType ?? '') == 'text/event-stream';
      if (!isSse) {
        // 非流式响应：整体 JSON。
        final text = await response.transform(utf8.decoder).join().timeout(_timeout);
        final data = jsonDecode(text);
        final content = data is Map && data['choices'] is List
            ? ((data['choices'][0] as Map)['message'] as Map)['content']
            : null;
        if (content is String && content.isNotEmpty) {
          yield content;
        }
        return;
      }

      await for (final raw
          in response.transform(utf8.decoder).transform(const LineSplitter())) {
        var line = raw.trim();
        if (line.isEmpty || !line.startsWith('data:')) continue;
        var payload = line.substring(5).trim();
        if (payload == '[DONE]') break;
        try {
          final data = jsonDecode(payload);
          final choices = data['choices'];
          if (choices is List && choices.isNotEmpty) {
            final delta = (choices[0] as Map)['delta'];
            if (delta is Map && delta['content'] is String) {
              final piece = delta['content'] as String;
              if (piece.isNotEmpty) yield piece;
            }
          }
        } on FormatException {
          continue;
        }
      }
    } on SocketException catch (e) {
      throw AiException('无法连接 AI 接口：${e.message}');
    } on TimeoutException {
      throw AiException('AI 接口请求超时');
    } on HttpException catch (e) {
      throw AiException('网络错误：${e.message}');
    } on FormatException {
      throw AiException('AI 接口返回了无法解析的内容');
    }
  }

  static String endpointFor(String baseUrl) => endpoint(baseUrl);
}

class AiException implements Exception {
  const AiException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 栅栏信息行 ```lang:path → 语言部分。
String _fenceLang(String info) {
  if (info.contains(':')) {
    return info.substring(0, info.indexOf(':')).trim();
  }
  return info;
}

/// 栅栏信息行 ```lang:path → 路径部分（无则 null）。
String? _fencePath(String info) {
  if (info.contains(':')) {
    final value = info.substring(info.indexOf(':') + 1).trim();
    return value.isEmpty ? null : value;
  }
  if (RegExp(r'\.[A-Za-z0-9]+$').hasMatch(info)) return info;
  return null;
}
