import 'package:path/path.dart' as p;
import 'package:re_highlight/re_highlight.dart';

import 'highlight_import.dart';

/// 可移植 TextMate JSON 子集：match、begin/end、patterns、repository/include。
/// 不支持的 Oniguruma/注入/捕获规则会在导入时拒绝，不静默改变语义。
class TextMateGrammar {
  const TextMateGrammar._({
    required this.name,
    required this.scopeName,
    required this.fileTypes,
    required this.source,
    required this.mode,
    required this.scopes,
  });

  final String name;
  final String scopeName;
  final List<String> fileTypes;
  final String source;
  final Mode mode;
  final Map<String, String> scopes;

  bool matchesFile(String fileName) {
    final name = p.basename(fileName).toLowerCase();
    return fileTypes.any((type) => name == type || name.endsWith('.$type'));
  }

  static TextMateGrammar parse(String source, {String? fileTypes}) {
    final data = decodeHighlightJson(source);
    final scope = data['scopeName'];
    if (scope is! String || !RegExp(r'^[a-zA-Z][\w.-]+$').hasMatch(scope)) {
      throw const FormatException('语法需要有效的 scopeName，例如 source.mylang');
    }
    final rawTypes = fileTypes?.split(RegExp(r'[,，\s]+')) ?? data['fileTypes'];
    if (rawTypes is! List) throw const FormatException('请填写此语法使用的文件后缀');
    final types = rawTypes
        .whereType<String>()
        .map(
          (type) => type.trim().toLowerCase().replaceFirst(RegExp(r'^\.'), ''),
        )
        .where((type) => type.isNotEmpty)
        .toSet()
        .toList();
    if (types.isEmpty ||
        types.any((type) => !RegExp(r'^[\w.-]+$').hasMatch(type))) {
      throw const FormatException('文件后缀格式不正确，例如 lua 或 html,css');
    }
    if (data['injections'] != null || data['injectionSelector'] != null) {
      throw const FormatException('当前兼容模式不支持 TextMate injections');
    }
    final compiler = _GrammarCompiler(data);
    final modes = compiler.patterns(data['patterns'], <String>{}, 0);
    if (modes.isEmpty) throw const FormatException('语法需要至少一条高亮规则');
    return TextMateGrammar._(
      name: data['name'] as String? ?? scope,
      scopeName: scope,
      fileTypes: types,
      source: source,
      mode: Mode(name: scope, unicodeRegex: true, contains: modes),
      scopes: compiler.scopes,
    );
  }
}

class _GrammarCompiler {
  _GrammarCompiler(this.root);

  final Map<String, dynamic> root;
  final Map<String, String> scopes = {};
  final Map<String, List<Mode>> _repositoryCache = {};
  var _count = 0;

  String? _scope(dynamic value) {
    if (value == null) return null;
    if (value is! String || value.contains(r'$') || value.trim().isEmpty) {
      throw const FormatException('语法作用域必须是固定名称');
    }
    for (final entry in scopes.entries) {
      if (entry.value == value) return entry.key;
    }
    final key = 'tm${scopes.length}';
    scopes[key] = value;
    return key;
  }

  List<Mode> patterns(dynamic values, Set<String> resolving, int depth) {
    if (depth > 40) throw const FormatException('语法嵌套不能超过 40 层');
    if (values == null) return [];
    if (values is! List) throw const FormatException('patterns 必须是数组');
    return [for (final value in values) ..._rule(value, resolving, depth + 1)];
  }

  List<Mode> _rule(dynamic value, Set<String> resolving, int depth) {
    if (depth > 40) throw const FormatException('语法嵌套不能超过 40 层');
    if (++_count > 1024) throw const FormatException('语法最多支持 1024 条规则');
    if (value is! Map) throw const FormatException('语法规则必须是对象');
    if (value['disabled'] == 1 || value['disabled'] == true) return [];
    final include = value['include'];
    if (include != null) {
      if (include is! String || !include.startsWith('#')) {
        throw FormatException('暂不支持外部语法或自引用 include：$include');
      }
      final cached = _repositoryCache[include];
      if (cached != null) return cached;
      if (resolving.contains(include)) {
        throw FormatException('循环 include 需要完整 TextMate 引擎：$include');
      }
      final repo = root['repository'];
      final target = repo is Map ? repo[include.substring(1)] : null;
      if (target == null) throw FormatException('找不到语法引用 $include');
      final rules = _rule(target, {...resolving, include}, depth + 1);
      _repositoryCache[include] = rules;
      return rules;
    }
    for (final field in [
      'while',
      'whileCaptures',
      'contentName',
      'applyEndPatternLast',
      'repository',
    ]) {
      if (value[field] != null) throw FormatException('当前兼容模式不支持 $field');
    }
    if (value['match'] != null) {
      if (value['begin'] != null ||
          value['end'] != null ||
          value['patterns'] != null) {
        throw const FormatException('match 规则不能同时定义 begin/end/patterns');
      }
      return [
        Mode(
          match: _regex(value['match']),
          scope: _captureScope(value['captures']) ?? _scope(value['name']),
          relevance: 0,
        ),
      ];
    }
    if (value['begin'] != null) {
      if (value['end'] == null) throw const FormatException('begin 规则需要 end');
      return [
        Mode(
          begin: _regex(value['begin']),
          end: _regex(value['end'], isEnd: true),
          scope: _scope(value['name']),
          beginScope: _captureScope(
            value['beginCaptures'] ?? value['captures'],
          ),
          endScope: _captureScope(value['endCaptures'] ?? value['captures']),
          contains: patterns(value['patterns'], resolving, depth),
          relevance: 0,
        ),
      ];
    }
    if (value['end'] != null) throw const FormatException('end 规则缺少 begin');
    return patterns(value['patterns'], resolving, depth);
  }

  String? _captureScope(dynamic captures) {
    if (captures == null) return null;
    if (captures is! Map) throw const FormatException('captures 必须是对象');
    if (captures.keys.any((key) => key.toString() != '0')) {
      throw const FormatException('当前兼容模式仅支持 captures 的整体匹配组 0');
    }
    final capture = captures['0'];
    if (capture == null) return null;
    if (capture is! Map || capture['patterns'] != null) {
      throw const FormatException('不支持捕获组内再次匹配 patterns');
    }
    return _scope(capture['name']);
  }

  String _regex(dynamic value, {bool isEnd = false}) {
    if (value is! String || value.length > 4096) {
      throw const FormatException('正则规则必须是长度不超过 4096 的字符串');
    }
    if (RegExp(
          r'\\[AzZGKRXhHvV]|\(\?[a-zA-Z>-]|\(\*|[+*?}]\+',
        ).hasMatch(value) ||
        (isEnd && RegExp(r'\\[1-9]').hasMatch(value))) {
      throw const FormatException('此规则依赖 Oniguruma 或 begin/end 反向引用，当前平台不支持');
    }
    try {
      final pattern = RegExp(value, multiLine: true, unicode: true);
      if (!isEnd && pattern.hasMatch('')) {
        throw const FormatException('match/begin 不能匹配空字符串');
      }
    } on FormatException {
      throw FormatException('不支持的正则表达式：$value');
    }
    return value;
  }
}
