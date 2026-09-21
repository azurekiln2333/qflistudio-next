import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/tutorial.dart';

/// 入门教程加载器。
///
/// 教程 JSON 放在 `packages/qfli_studio_core/assets/tutorials/` 下，随包打进
/// 每个语言 App。加载时按 [bundledLanguages] 取文件，解析成 [Tutorial]。
///
/// 资产 key 的两种形态都要兼容：
/// - 在依赖本包的语言 App 里，key 带包名前缀：
///   `packages/qfli_studio_core/assets/tutorials/c.json`
/// - 在本包自己的测试里，key 是不带前缀的：
///   `assets/tutorials/c.json`
///
/// 所以这里按顺序试，命中即用。
abstract final class TutorialService {
  /// 当前随包分发的语言教程。新增语言时在这里登记。
  static const List<String> bundledLanguages = <String>[
    'c',
    'cpp',
    'web',
    'python',
    'java',
    'dart',
    'lua',
  ];

  static const String _assetDir = 'assets/tutorials';

  /// 已解析的教程缓存，避免每次进页面都读盘 + 解析。
  static final Map<String, Tutorial> _cache = <String, Tutorial>{};

  /// 加载某个语言的教程；文件不存在或结构非法时返回 null。
  static Future<Tutorial?> load(String language) async {
    final cached = _cache[language];
    if (cached != null) return cached;

    final raw = await _readAsset(language);
    if (raw == null) return null;

    final tutorial = parse(language, raw);
    _cache[language] = tutorial;
    return tutorial;
  }

  /// 加载全部已登记语言的教程，跳过加载失败的语言。
  static Future<List<Tutorial>> loadAll() async {
    final result = <Tutorial>[];
    for (final language in bundledLanguages) {
      final tutorial = await load(language);
      if (tutorial != null) result.add(tutorial);
    }
    return result;
  }

  /// 同步返回已缓存的结果；没加载过就是 null。
  ///
  /// 给「进页面时先渲染上次结果」用，避免闪白。
  static Tutorial? cached(String language) => _cache[language];

  /// 清空缓存（测试用）。
  static void clearCache() => _cache.clear();

  /// 解析一段教程 JSON 文本。
  ///
  /// 结构非法时抛 [TutorialFormatException]，消息里带上语言名，方便定位是哪份
  /// 文件写坏了。
  static Tutorial parse(String language, String source) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (e) {
      throw TutorialFormatException(language, '不是合法 JSON（${e.message}）');
    }
    if (decoded is! Map) {
      throw TutorialFormatException(language, '顶层必须是 JSON 对象');
    }
    final map = decoded.cast<String, Object?>();
    final chapters = <TutorialChapter>[];
    for (final raw in _list(map['chapters'])) {
      final chapter = _map(raw);
      final lessons = <TutorialLesson>[];
      for (final rawLesson in _list(chapter['lessons'])) {
        lessons.add(
          _lesson(_map(rawLesson), fallbackType: _str(map['type'], fallback: language)),
        );
      }
      chapters.add(
        TutorialChapter(
          id: _str(chapter['id']),
          title: _str(chapter['title']),
          lessons: lessons,
        ),
      );
    }

    final parsedExamples = [
      for (final raw in _list(map['examples'])) _example(_map(raw)),
    ];
    final examples = parsedExamples.isNotEmpty
        ? parsedExamples
        : [
            for (final chapter in chapters)
              for (final lesson in chapter.lessons)
                ExampleCode(
                  id: lesson.id,
                  type: lesson.type,
                  title: lesson.title,
                  summary: lesson.summary,
                  code: lesson.code,
                  output: lesson.output,
                  sourceLessonId: lesson.id,
                ),
          ];

    return Tutorial(
      language: _str(map['language'], fallback: language),
      type: _str(map['type'], fallback: language),
      displayName: _str(map['displayName'], fallback: language),
      schemaVersion: _int(map['schemaVersion'], fallback: 1),
      updatedAt: _str(map['updatedAt']),
      runtime: _runtime(_map(map['runtime'])),
      chapters: chapters,
      examples: examples,
    );
  }

  // --- 内部工具 -----------------------------------------------------------

  static TutorialRuntime _runtime(Map<String, Object?> map) {
    return TutorialRuntime(
      kind: _str(map['kind'], fallback: 'unknown'),
      status: _str(map['status'], fallback: 'planned'),
      engine: _str(map['engine']),
      stdin: _nullableStr(map['stdin']),
      stdout: _nullableStr(map['stdout']),
      limits: _nullableStr(map['limits']),
      note: _nullableStr(map['note']),
    );
  }

  static TutorialLesson _lesson(
    Map<String, Object?> map, {
    required String fallbackType,
  }) {
    final tasks = <TutorialTask>[];
    for (final raw in _list(map['tasks'])) {
      final task = _map(raw);
      tasks.add(
        TutorialTask(
          prompt: _str(task['prompt']),
          hint: _str(task['hint']),
          answer: _str(task['answer']),
        ),
      );
    }
    return TutorialLesson(
      id: _str(map['id']),
      type: _str(map['type'], fallback: fallbackType),
      title: _str(map['title']),
      summary: _str(map['summary']),
      concepts: [for (final c in _list(map['concepts'])) _str(c)],
      explain: _str(map['explain']),
      code: _str(map['code']),
      output: _str(map['output']),
      tasks: tasks,
    );
  }

  static ExampleCode _example(Map<String, Object?> map) => ExampleCode(
    id: _str(map['id']),
    type: _str(map['type'], fallback: 'unknown'),
    title: _str(map['title']),
    summary: _str(map['summary']),
    code: _str(map['code']),
    output: _str(map['output']),
    sourceLessonId: _nullableStr(map['sourceLessonId']),
  );

  /// 依次尝试带包名前缀和不带前缀的 asset key。
  ///
  /// 两个 key 都取不到时返回 null。这里刻意不抛异常：教程加载失败只应该让
  /// 「教程」入口显示为空，不该把 IDE 带崩。但失败原因会打到日志里，避免像
  /// 「测试没初始化 binding」这种问题被静默吞掉。
  static Future<String?> _readAsset(String language) async {
    final failures = <String>[];
    for (final key in <String>[
      'packages/qfli_studio_core/$_assetDir/$language.json',
      '$_assetDir/$language.json',
    ]) {
      try {
        return await rootBundle.loadString(key);
      } on FlutterError catch (e) {
        failures.add('$key: ${e.message}');
      } on Exception catch (e) {
        failures.add('$key: $e');
      }
    }
    if (kDebugMode) {
      debugPrint('[TutorialService] 读取 $language 教程失败：${failures.join(' | ')}');
    }
    return null;
  }

  static Map<String, Object?> _map(Object? value) {
    if (value is Map) return value.cast<String, Object?>();
    return const <String, Object?>{};
  }

  static List<Object?> _list(Object? value) {
    if (value is List) return value;
    return const <Object?>[];
  }

  static String _str(Object? value, {String fallback = ''}) {
    if (value is String) return value;
    if (value == null) return fallback;
    return value.toString();
  }

  static String? _nullableStr(Object? value) {
    if (value is String) return value;
    return null;
  }

  static int _int(Object? value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }
}
