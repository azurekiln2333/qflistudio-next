import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:qfli_studio_core/models/tutorial.dart';
import 'package:qfli_studio_core/services/tutorial_service.dart';

/// 最小可用教程文档，用来测解析逻辑本身。
Map<String, Object?> _minimalDoc() => <String, Object?>{
  'language': 'demo',
  'displayName': 'Demo',
  'schemaVersion': 1,
  'updatedAt': '2026-09-19',
  'runtime': <String, Object?>{
    'kind': 'interpreter',
    'status': 'planned',
    'engine': '演示引擎',
  },
  'chapters': <Object?>[
    <String, Object?>{
      'id': 'basics',
      'title': '基础',
      'lessons': <Object?>[
        <String, Object?>{
          'id': 'hello',
          'title': '你好',
          'summary': '打印一行字',
          'concepts': <Object?>['输出'],
          'explain': '正文',
          'code': 'print("hi")',
          'output': 'hi',
          'tasks': <Object?>[
            <String, Object?>{
              'prompt': '改成 hello',
              'hint': '改字符串',
              'answer': 'print("hello")',
            },
          ],
        },
      ],
    },
  ],
};

void main() {
  // 读 asset 要走 rootBundle，必须先初始化测试 binding。
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TutorialService.parse', () {
    test('解析出完整结构', () {
      final tutorial = TutorialService.parse(
        'demo',
        jsonEncode(_minimalDoc()),
      );

      expect(tutorial.language, 'demo');
      expect(tutorial.displayName, 'Demo');
      expect(tutorial.schemaVersion, 1);
      expect(tutorial.runtime.kind, 'interpreter');
      expect(tutorial.runtime.status, 'planned');
      expect(tutorial.runtime.isAvailable, isFalse);
      expect(tutorial.chapters, hasLength(1));

      final lesson = tutorial.chapters.single.lessons.single;
      expect(lesson.id, 'hello');
      expect(lesson.concepts, ['输出']);
      expect(lesson.tasks, hasLength(1));
      expect(lesson.tasks.single.answer, 'print("hello")');

      expect(tutorial.lessonCount, 1);
      expect(tutorial.allLessons, hasLength(1));
      expect(tutorial.isRunnable, isFalse);
    });

    test('不是合法 JSON 时抛 TutorialFormatException', () {
      expect(
        () => TutorialService.parse('demo', '{ 这不是 json'),
        throwsA(
          isA<TutorialFormatException>().having(
            (e) => e.language,
            'language',
            'demo',
          ),
        ),
      );
    });

    test('顶层不是对象时抛 TutorialFormatException', () {
      expect(
        () => TutorialService.parse('demo', '[1, 2, 3]'),
        throwsA(isA<TutorialFormatException>()),
      );
    });

    test('缺字段时退化为空值而不是崩溃', () {
      final tutorial = TutorialService.parse('demo', '{}');

      // language / displayName 回落到传入的语言名。
      expect(tutorial.language, 'demo');
      expect(tutorial.displayName, 'demo');
      expect(tutorial.schemaVersion, 1);
      expect(tutorial.chapters, isEmpty);
      expect(tutorial.lessonCount, 0);
      // runtime 缺失时给 unknown / planned。
      expect(tutorial.runtime.kind, 'unknown');
      expect(tutorial.runtime.status, 'planned');
      expect(tutorial.runtime.isAvailable, isFalse);
    });

    test('status 为 available 时 isRunnable 为真', () {
      final doc = _minimalDoc();
      (doc['runtime']! as Map<String, Object?>)['status'] = 'available';
      final tutorial = TutorialService.parse('demo', jsonEncode(doc));
      expect(tutorial.runtime.isAvailable, isTrue);
      expect(tutorial.isRunnable, isTrue);
    });
  });

  group('随包分发的教程资产', () {
    test('五个语言的教程都能加载', () async {
      TutorialService.clearCache();
      final tutorials = await TutorialService.loadAll();

      expect(
        tutorials.map((t) => t.language).toSet(),
        TutorialService.bundledLanguages.toSet(),
      );
      for (final tutorial in tutorials) {
        expect(tutorial.chapters, isNotEmpty, reason: '${tutorial.language} 无章节');
        expect(tutorial.lessonCount, greaterThan(0));
        expect(tutorial.displayName, isNotEmpty);
        expect(tutorial.updatedAt, isNotEmpty);
        expect(tutorial.runtime.engine, isNotEmpty);
        expect(
          tutorial.runtime.status,
          anyOf('available', 'planned'),
          reason: '${tutorial.language} 的 status 取值不在约定范围内',
        );
      }
    });

    test('每课的必填内容都非空，且至少有一道练习题', () async {
      TutorialService.clearCache();
      for (final tutorial in await TutorialService.loadAll()) {
        for (final chapter in tutorial.chapters) {
          expect(chapter.id, isNotEmpty);
          expect(chapter.title, isNotEmpty);
          expect(chapter.lessons, isNotEmpty);
          for (final lesson in chapter.lessons) {
            final where = '${tutorial.language}/${chapter.id}/${lesson.id}';
            expect(lesson.id, isNotEmpty, reason: where);
            expect(lesson.title, isNotEmpty, reason: where);
            expect(lesson.summary, isNotEmpty, reason: where);
            expect(lesson.explain, isNotEmpty, reason: where);
            expect(lesson.code, isNotEmpty, reason: where);
            expect(lesson.output, isNotEmpty, reason: where);
            expect(lesson.concepts, isNotEmpty, reason: where);
            expect(lesson.tasks, isNotEmpty, reason: where);
            for (final task in lesson.tasks) {
              expect(task.prompt, isNotEmpty, reason: where);
              expect(task.hint, isNotEmpty, reason: where);
              expect(task.answer, isNotEmpty, reason: where);
            }
          }
        }
      }
    });

    test('章节 id 与课时 id 在各自语言内不重复', () async {
      TutorialService.clearCache();
      for (final tutorial in await TutorialService.loadAll()) {
        final chapterIds = tutorial.chapters.map((c) => c.id).toList();
        expect(
          chapterIds.toSet(),
          hasLength(chapterIds.length),
          reason: '${tutorial.language} 有重复章节 id',
        );

        final lessonIds = tutorial.allLessons.map((l) => l.id).toList();
        expect(
          lessonIds.toSet(),
          hasLength(lessonIds.length),
          reason: '${tutorial.language} 有重复课时 id',
        );
      }
    });

    test('文件名里的语言与文档内的 language 字段一致', () async {
      TutorialService.clearCache();
      for (final language in TutorialService.bundledLanguages) {
        final tutorial = await TutorialService.load(language);
        expect(tutorial, isNotNull, reason: '$language.json 没加载到');
        expect(tutorial!.language, language);
      }
    });

    test('已可运行的语言必须说明引擎怎么跑', () async {
      TutorialService.clearCache();
      for (final tutorial in await TutorialService.loadAll()) {
        if (!tutorial.isRunnable) continue;
        expect(
          tutorial.runtime.engine,
          isNotEmpty,
          reason: '${tutorial.language} 标记为可用却没写引擎',
        );
        // 解释器类要有 stdin 说明，静态服务器类要有 stdout 说明。
        final hasHow = (tutorial.runtime.stdin ?? '').isNotEmpty ||
            (tutorial.runtime.stdout ?? '').isNotEmpty;
        expect(hasHow, isTrue, reason: '${tutorial.language} 没说清输入/输出怎么走');
      }
    });

    test('缓存命中后不再重复解析', () async {
      TutorialService.clearCache();
      final first = await TutorialService.load('c');
      final second = await TutorialService.load('c');
      expect(identical(first, second), isTrue);
      expect(TutorialService.cached('c'), isNotNull);
    });
  });
}
