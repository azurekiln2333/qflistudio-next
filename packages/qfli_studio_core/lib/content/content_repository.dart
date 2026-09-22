import 'dart:convert';

/// The content types supported by the product line.
abstract final class ContentProductTypes {
  static const all = <String>{
    'c',
    'cpp',
    'lua',
    'javascript',
    'typescript',
    'shell',
    'rust',
    'go',
    'java',
    'html',
    'css',
    'python',
    'dart',
    'sql',
    'json',
    'markdown',
  };

  /// Product-to-content mapping kept at the content boundary so repository
  /// consumers do not need to know how product profiles are implemented.
  static const byProduct = <String, Set<String>>{
    'qflistudio': all,
    'script': {'lua', 'javascript', 'typescript', 'shell'},
    'rustcore': {'rust'},
    'goshift': {'go'},
    'jvmx': {'java'},
    'webforge': {'html', 'css', 'javascript'},
    'pyflow': {'python'},
    'forge': {'c', 'cpp'},
    'dartwing': {'dart'},
    'sqlab': {'sql'},
    'json': {'json'},
    'note': {'markdown'},
  };
}

/// A typed query for content entries.
class ContentFilter {
  const ContentFilter({this.language, this.type, this.locale, this.types});

  factory ContentFilter.forProduct(String productKey) {
    final types = ContentProductTypes.byProduct[productKey.trim().toLowerCase()];
    if (types == null) {
      throw ArgumentError.value(productKey, 'productKey', 'Unknown product');
    }
    return ContentFilter(types: types);
  }

  final String? language;
  final String? type;
  final String? locale;
  final Set<String>? types;

  bool matches(ContentEntry entry) {
    final normalizedLanguage = language?.trim().toLowerCase();
    final normalizedType = type?.trim().toLowerCase();
    final normalizedLocale = locale?.trim().toLowerCase();
    if (normalizedLanguage != null &&
        entry.language.trim().toLowerCase() != normalizedLanguage) {
      return false;
    }
    if (normalizedType != null &&
        entry.type.trim().toLowerCase() != normalizedType) {
      return false;
    }
    if (normalizedLocale != null &&
        entry.locale.trim().toLowerCase() != normalizedLocale) {
      return false;
    }
    if (types != null &&
        !types!.contains(entry.type.trim().toLowerCase())) {
      return false;
    }
    return true;
  }
}

/// Shared metadata for tutorial and example entries.
abstract class ContentEntry {
  const ContentEntry({
    required this.id,
    required this.language,
    required this.type,
    required this.locale,
    required this.level,
    required this.title,
    required this.summary,
    required this.concepts,
    required this.source,
    required this.license,
    required this.updatedAt,
    this.hasExplicitId = true,
    this.hasExplicitLanguage = true,
    this.hasExplicitType = true,
  });

  final String id;
  final String language;
  final String type;
  final String locale;
  final String level;
  final String title;
  final String summary;
  final List<String> concepts;
  final String source;
  final String license;
  final String updatedAt;

  /// These flags keep compatibility fallbacks visible to the release validator.
  final bool hasExplicitId;
  final bool hasExplicitLanguage;
  final bool hasExplicitType;
}

class TutorialContent extends ContentEntry {
  const TutorialContent({
    required super.id,
    required super.language,
    required super.type,
    required super.locale,
    required super.level,
    required super.title,
    required super.summary,
    required super.concepts,
    required super.source,
    required super.license,
    required super.updatedAt,
    required this.lessons,
    super.hasExplicitId = true,
    super.hasExplicitLanguage = true,
    super.hasExplicitType = true,
  });

  final List<TutorialLessonContent> lessons;
}

class TutorialLessonContent {
  const TutorialLessonContent({
    required this.id,
    required this.title,
    required this.summary,
    required this.concepts,
    required this.explain,
    required this.code,
    required this.output,
    required this.exercises,
  });

  final String id;
  final String title;
  final String summary;
  final List<String> concepts;
  final String explain;
  final String code;
  final String output;
  final List<ContentExercise> exercises;
}

class ContentExercise {
  const ContentExercise({
    required this.prompt,
    required this.hint,
    required this.answer,
  });

  final String prompt;
  final String hint;
  final String answer;
}

class ExampleContent extends ContentEntry {
  const ExampleContent({
    required super.id,
    required super.language,
    required super.type,
    required super.locale,
    required super.level,
    required super.title,
    required super.summary,
    required super.concepts,
    required super.source,
    required super.license,
    required super.updatedAt,
    required this.code,
    required this.expectedOutput,
    required this.inputFixtures,
    required this.templateType,
    this.sourceLessonId,
    super.hasExplicitId = true,
    super.hasExplicitLanguage = true,
    super.hasExplicitType = true,
  });

  final String code;
  final String expectedOutput;
  final Map<String, String> inputFixtures;
  final String templateType;
  final String? sourceLessonId;
}

/// The aggregate content snapshot returned by a repository.
class ContentCatalog {
  const ContentCatalog({
    required this.schemaVersion,
    required this.tutorials,
    required this.examples,
  });

  final int schemaVersion;
  final List<TutorialContent> tutorials;
  final List<ExampleContent> examples;

  /// Parses the two aggregate documents used by [AssetContentRepository].
  ///
  /// In addition to `{entries: [...]}`, this accepts the old per-language
  /// tutorial document and an old `{examples: [...]}` document. Compatibility
  /// values are retained in the typed model and marked as non-explicit so the
  /// release validator can report what still needs migration.
  factory ContentCatalog.fromJson({
    required String tutorialsSource,
    required String examplesSource,
  }) {
    final tutorialDocument = _decodeDocument(tutorialsSource, 'tutorials');
    final exampleDocument = _decodeDocument(examplesSource, 'examples');
    final tutorialRoot = _rootMap(tutorialDocument);
    final exampleRoot = _rootMap(exampleDocument);
    final schemaVersion = _int(
      tutorialRoot?['schemaVersion'] ?? exampleRoot?['schemaVersion'],
      fallback: 1,
    );

    return ContentCatalog(
      schemaVersion: schemaVersion,
      tutorials: [
        for (final entry in _tutorialEntries(tutorialDocument))
          _parseTutorial(entry, tutorialRoot),
      ],
      examples: [
        for (final entry in _exampleEntries(exampleDocument))
          _parseExample(entry, exampleRoot),
      ],
    );
  }
}

/// The source boundary for bundled or remote content.
abstract interface class ContentRepository {
  Future<ContentCatalog> load();

  Future<List<TutorialContent>> tutorials({
    ContentFilter filter = const ContentFilter(),
  });

  Future<List<ExampleContent>> examples({
    ContentFilter filter = const ContentFilter(),
  });
}

class ContentFormatException implements Exception {
  const ContentFormatException(this.document, this.message);

  final String document;
  final String message;

  @override
  String toString() => 'Content document $document is invalid: $message';
}

Object _decodeDocument(String source, String document) {
  try {
    return jsonDecode(source);
  } on FormatException catch (error) {
    throw ContentFormatException(document, error.message);
  }
}

List<Map<String, Object?>> _tutorialEntries(Object document) {
  return _entries(
    document,
    documentName: 'tutorials',
    legacyKeys: const ['tutorials'],
    isTutorial: true,
  );
}

List<Map<String, Object?>> _exampleEntries(Object document) {
  return _entries(
    document,
    documentName: 'examples',
    legacyKeys: const ['examples'],
    isTutorial: false,
  );
}

List<Map<String, Object?>> _entries(
  Object document, {
  required String documentName,
  required List<String> legacyKeys,
  required bool isTutorial,
}) {
  if (document is List) return _mapList(document, documentName);
  if (document is! Map) {
    throw ContentFormatException(documentName, 'top level must be an object or list');
  }
  final map = document.cast<String, Object?>();
  if (map.containsKey('entries')) {
    return _mapList(_requiredList(map['entries'], documentName, 'entries'), documentName);
  }
  for (final key in legacyKeys) {
    if (map.containsKey(key)) {
      return _mapList(_requiredList(map[key], documentName, key), documentName);
    }
  }
  if ((isTutorial && map.containsKey('chapters')) ||
      (!isTutorial && map.containsKey('code'))) {
    return [map];
  }
  return const [];
}

List<Map<String, Object?>> _mapList(
  List<Object?> values,
  String documentName,
) {
  return [
    for (var index = 0; index < values.length; index++)
      _map(values[index], '$documentName.entries[$index]'),
  ];
}

List<Object?> _requiredList(Object? value, String document, String field) {
  if (value is List) return value;
  throw ContentFormatException(document, '$field must be an array');
}

TutorialContent _parseTutorial(
  Map<String, Object?> map,
  Map<String, Object?>? document,
) {
  final isLegacyDocument = map.containsKey('chapters');
  final languageValue = _text(map['language']);
  final language = languageValue;
  final typeValue = _text(map['type']);
  final type = typeValue.isNotEmpty
      ? typeValue
      : isLegacyDocument
      ? language
      : '';
  final idValue = _text(map['id']);
  final id = idValue.isNotEmpty
      ? idValue
      : isLegacyDocument && language.isNotEmpty
      ? '$language-legacy'
      : '';
  final title = _text(map['title']).isNotEmpty
      ? _text(map['title'])
      : _text(map['displayName']);
  final lessons = _tutorialLessons(map, type);

  return TutorialContent(
    id: id,
    language: language,
    type: type,
    locale: _text(map['locale']),
    level: _text(map['level']),
    title: title,
    summary: _text(map['summary']),
    concepts: _strings(map['concepts']),
    source: _text(map['source']),
    license: _text(map['license']),
    updatedAt: _text(map['updatedAt']).isNotEmpty
        ? _text(map['updatedAt'])
        : _text(document?['updatedAt']),
    lessons: lessons,
    hasExplicitId: idValue.isNotEmpty,
    hasExplicitLanguage: languageValue.isNotEmpty,
    hasExplicitType: typeValue.isNotEmpty,
  );
}

List<TutorialLessonContent> _tutorialLessons(
  Map<String, Object?> map,
  String fallbackType,
) {
  final lessons = <TutorialLessonContent>[];
  if (map.containsKey('lessons')) {
    for (final raw in _requiredList(map['lessons'], 'tutorials', 'lessons')) {
      lessons.add(_parseLesson(_map(raw, 'tutorials.lessons')));
    }
    return lessons;
  }
  for (final rawChapter in _list(map['chapters'])) {
    final chapter = _map(rawChapter, 'tutorials.chapters');
    for (final rawLesson in _list(chapter['lessons'])) {
      final lesson = _map(rawLesson, 'tutorials.chapters.lessons');
      lessons.add(_parseLesson(lesson, fallbackType: fallbackType));
    }
  }
  return lessons;
}

TutorialLessonContent _parseLesson(
  Map<String, Object?> map, {
  String? fallbackType,
}) {
  final exercisesValue = map.containsKey('exercises')
      ? map['exercises']
      : map['tasks'];
  return TutorialLessonContent(
    id: _text(map['id']),
    title: _text(map['title']),
    summary: _text(map['summary']),
    concepts: _strings(map['concepts']),
    explain: _text(map['explain']),
    code: _rawText(map['code']),
    output: _rawText(map['output']),
    exercises: [
      for (final raw in _list(exercisesValue))
        _parseExercise(_map(raw, 'tutorials.exercises')),
    ],
  );
}

ContentExercise _parseExercise(Map<String, Object?> map) => ContentExercise(
  prompt: _text(map['prompt']),
  hint: _text(map['hint']),
  answer: _rawText(map['answer']),
);

ExampleContent _parseExample(
  Map<String, Object?> map,
  Map<String, Object?>? document,
) {
  final isLegacyDocument =
      document != null &&
      document.containsKey('examples') &&
      !document.containsKey('entries');
  final languageValue = _text(map['language']);
  final documentLanguage = _text(document?['language']);
  final language = languageValue.isNotEmpty ? languageValue : documentLanguage;
  final typeValue = _text(map['type']);
  final documentType = _text(document?['type']);
  final type = typeValue.isNotEmpty
      ? typeValue
      : documentType.isNotEmpty
      ? documentType
      : isLegacyDocument
      ? language
      : '';
  final idValue = _text(map['id']);
  final id = idValue.isNotEmpty
      ? idValue
      : isLegacyDocument && language.isNotEmpty
      ? '$language-example'
      : '';
  final code = _rawText(map['code']).isNotEmpty
      ? _rawText(map['code'])
      : _rawText(map['sourceCode']);

  return ExampleContent(
    id: id,
    language: language,
    type: type,
    locale: _text(map['locale']),
    level: _text(map['level']),
    title: _text(map['title']),
    summary: _text(map['summary']),
    concepts: _strings(map['concepts']),
    source: _text(map['source']),
    license: _text(map['license']),
    updatedAt: _text(map['updatedAt']).isNotEmpty
        ? _text(map['updatedAt'])
        : _text(document?['updatedAt']),
    code: code,
    expectedOutput: _rawText(map['expectedOutput']).isNotEmpty
        ? _rawText(map['expectedOutput'])
        : _rawText(map['output']),
    inputFixtures: _inputFixtures(map),
    templateType: _text(map['templateType']).isNotEmpty
        ? _text(map['templateType'])
        : type,
    sourceLessonId: _nullableText(map['sourceLessonId']),
    hasExplicitId: idValue.isNotEmpty,
    hasExplicitLanguage: languageValue.isNotEmpty || documentLanguage.isNotEmpty,
    hasExplicitType: typeValue.isNotEmpty,
  );
}

Map<String, String> _inputFixtures(Map<String, Object?> map) {
  final result = <String, String>{};
  final value = map['inputFixtures'];
  if (value is Map) {
    for (final entry in value.entries) {
      if (entry.key is String && entry.value is String) {
        result[entry.key as String] = entry.value as String;
      }
    }
  } else if (value is String) {
    result['stdin'] = value;
  } else if (_rawText(map['input']).isNotEmpty) {
    result['stdin'] = _rawText(map['input']);
  }
  return result;
}

Map<String, Object?>? _rootMap(Object document) => document is Map
    ? document.cast<String, Object?>()
    : null;

Map<String, Object?> _map(Object? value, String path) {
  if (value is Map) return value.cast<String, Object?>();
  throw ContentFormatException(path, 'entry must be an object');
}

List<Object?> _list(Object? value) => value is List ? value : const [];

List<String> _strings(Object? value) => [
  for (final item in _list(value))
    if (_text(item).isNotEmpty) _text(item),
];

String _text(Object? value) => value is String ? value.trim() : '';

String _rawText(Object? value) => value is String ? value : '';

String? _nullableText(Object? value) {
  final text = _text(value);
  return text.isEmpty ? null : text;
}

int _int(Object? value, {required int fallback}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}
