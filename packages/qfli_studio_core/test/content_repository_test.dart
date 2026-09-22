import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qfli_studio_core/content/asset_content_repository.dart';
import 'package:qfli_studio_core/content/content_repository.dart';
import 'package:qfli_studio_core/content/content_validator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('parses aggregate tutorials and examples with typed metadata', () {
    final catalog = ContentCatalog.fromJson(
      tutorialsSource: jsonEncode({
        'schemaVersion': 1,
        'entries': [
          _tutorialEntry(id: 'python-basics', language: 'python', type: 'python'),
          _tutorialEntry(
            id: 'web-basics',
            language: 'javascript',
            type: 'javascript',
          ),
        ],
      }),
      examplesSource: jsonEncode({
        'schemaVersion': 1,
        'entries': [
          _exampleEntry(
            id: 'python-hello',
            language: 'python',
            type: 'python',
          ),
        ],
      }),
    );

    expect(catalog.schemaVersion, 1);
    expect(catalog.tutorials.first.id, 'python-basics');
    expect(catalog.tutorials.first.lessons.single.exercises.single.prompt, 'Try it');
    expect(catalog.examples.single.inputFixtures, {'stdin': 'Ada\n'});
    expect(catalog.examples.single.templateType, 'python');
    expect(
      ContentCatalogValidator.validate(catalog).isValid,
      isTrue,
    );
  });

  test('filters by language, type, locale, and product profile', () async {
    final repository = _repository(
      tutorials: {
        'schemaVersion': 1,
        'entries': [
          _tutorialEntry(
            id: 'python-zh',
            language: 'python',
            type: 'python',
            locale: 'zh-CN',
          ),
          _tutorialEntry(
            id: 'javascript-en',
            language: 'javascript',
            type: 'javascript',
            locale: 'en',
          ),
        ],
      },
      examples: {
        'schemaVersion': 1,
        'entries': [
          _exampleEntry(
            id: 'javascript-example',
            language: 'javascript',
            type: 'javascript',
            locale: 'en',
          ),
          _exampleEntry(
            id: 'python-example',
            language: 'python',
            type: 'python',
            locale: 'zh-CN',
          ),
        ],
      },
    );

    expect(
      (await repository.tutorials(
        filter: const ContentFilter(language: 'PYTHON', locale: 'zh-cn'),
      )).map((entry) => entry.id),
      ['python-zh'],
    );
    expect(
      (await repository.examples(
        filter: ContentFilter.forProduct('webforge'),
      )).map((entry) => entry.id),
      ['javascript-example'],
    );
  });

  test('accepts legacy per-language tutorial and example documents', () {
    final catalog = ContentCatalog.fromJson(
      tutorialsSource: jsonEncode({
        'language': 'lua',
        'type': 'lua',
        'displayName': 'Lua',
        'updatedAt': '2026-09-21',
        'chapters': [
          {
            'id': 'basics',
            'lessons': [
              {
                'id': 'hello',
                'title': 'Hello',
                'summary': 'Print text',
                'concepts': ['print'],
                'explain': 'Use print.',
                'code': 'print("hello")',
                'output': 'hello',
                'tasks': [
                  {'prompt': 'Change it', 'hint': 'Edit text', 'answer': '...'},
                ],
              },
            ],
          },
        ],
      }),
      examplesSource: jsonEncode({
        'language': 'lua',
        'type': 'lua',
        'examples': [
          {
            'title': 'Legacy example',
            'summary': 'A migrated example',
            'code': 'print("legacy")',
            'output': 'legacy',
          },
        ],
      }),
    );

    expect(catalog.tutorials.single.id, 'lua-legacy');
    expect(catalog.tutorials.single.lessons.single.exercises, hasLength(1));
    expect(catalog.examples.single.type, 'lua');
    expect(catalog.examples.single.id, 'lua-example');
    expect(catalog.examples.single.hasExplicitType, isFalse);
    expect(
      ContentCatalogValidator.validate(catalog).issues,
      contains(predicate<ContentValidationIssue>(
        (issue) => issue.message == 'locale is required',
      )),
    );
  });

  test('validator reports missing metadata, duplicate ids, and release counts', () {
    final catalog = ContentCatalog.fromJson(
      tutorialsSource: jsonEncode({
        'entries': [
          _tutorialEntry(id: 'same', language: 'python', type: 'python'),
          {..._tutorialEntry(id: 'same', language: 'python', type: '')},
        ],
      }),
      examplesSource: jsonEncode({'entries': []}),
    );

    final schemaResult = ContentCatalogValidator.validate(catalog);
    expect(schemaResult.issues.map((issue) => issue.message), contains('duplicate id; already used at tutorials[0]'));
    expect(schemaResult.issues.map((issue) => issue.message), contains('type is required'));

    final releaseResult = ContentCatalogValidator.validateForRelease(catalog);
    expect(releaseResult.isValid, isFalse);
    expect(
      releaseResult.issues.any((issue) => issue.message.contains('requires 100')),
      isTrue,
    );
  });

  test('asset repository loads both local and package-prefixed asset keys', () async {
    final local = _repository(
      tutorials: {'entries': [_tutorialEntry(id: 'local', language: 'c', type: 'c')]},
      examples: {'entries': [_exampleEntry(id: 'local-example', language: 'c', type: 'c')]},
    );
    expect((await local.load()).tutorials.single.id, 'local');

    final packageBundle = _MemoryAssetBundle({
      'packages/qfli_studio_core/assets/content/tutorials.json':
          jsonEncode({'entries': [_tutorialEntry(id: 'package', language: 'c', type: 'c')]}),
      'packages/qfli_studio_core/assets/content/examples.json':
          jsonEncode({'entries': [_exampleEntry(id: 'package-example', language: 'c', type: 'c')]}),
    });
    final repository = AssetContentRepository(bundle: packageBundle);
    expect((await repository.load()).examples.single.id, 'package-example');
  });
}

AssetContentRepository _repository({
  required Map<String, Object?> tutorials,
  required Map<String, Object?> examples,
}) => AssetContentRepository(
  bundle: _MemoryAssetBundle({
    'assets/content/tutorials.json': jsonEncode(tutorials),
    'assets/content/examples.json': jsonEncode(examples),
  }),
);

Map<String, Object?> _tutorialEntry({
  required String id,
  required String language,
  required String type,
  String locale = 'en',
}) => {
  'id': id,
  'language': language,
  'type': type,
  'locale': locale,
  'level': 'beginner',
  'title': 'Getting started',
  'summary': 'Learn the basics.',
  'concepts': ['basics'],
  'source': 'https://example.com/$id',
  'license': 'CC BY 4.0',
  'updatedAt': '2026-09-22',
  'lessons': [
    {
      'id': '$id-lesson',
      'title': 'First step',
      'summary': 'Run a first example.',
      'concepts': ['output'],
      'explain': 'Write and run a small program.',
      'code': 'print("hello")',
      'output': 'hello',
      'exercises': [
        {'prompt': 'Try it', 'hint': 'Change the text', 'answer': '...'},
      ],
    },
  ],
};

Map<String, Object?> _exampleEntry({
  required String id,
  required String language,
  required String type,
  String locale = 'en',
}) => {
  'id': id,
  'language': language,
  'type': type,
  'locale': locale,
  'level': 'beginner',
  'title': 'Hello example',
  'summary': 'A complete example.',
  'concepts': ['output'],
  'source': 'https://example.com/$id',
  'license': 'CC BY 4.0',
  'updatedAt': '2026-09-22',
  'code': 'print("hello")',
  'expectedOutput': 'hello',
  'inputFixtures': {'stdin': 'Ada\n'},
  'templateType': type,
};

class _MemoryAssetBundle extends AssetBundle {
  _MemoryAssetBundle(this.values);

  final Map<String, String> values;

  @override
  Future<ByteData> load(String key) async {
    final value = values[key];
    if (value == null) throw FlutterError('Missing test asset: $key');
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(value)));
  }
}
