import '../models/tutorial.dart';
import '../services/studio_profile.dart';
import 'content_repository.dart';

/// Converts the aggregate content contract into the legacy page models.
///
/// The pages still expose lesson and example detail routes, while the source
/// of truth is now the typed aggregate repository. Product filtering belongs
/// here so every offline page applies the same language/type rules.
abstract final class LocalContentAdapter {
  static Future<Tutorial?> loadTutorial({
    required ContentRepository repository,
    required String language,
    required String displayName,
    String? productKey,
  }) async {
    final entries = await repository.tutorials(
      filter: _filter(language: language, productKey: productKey),
    );
    if (entries.isEmpty) return null;

    final pairedFixtures = <String, Map<String, String>>{};
    if (entries.any(
      (entry) => entry.lessons.any((lesson) => lesson.inputFixtures.isEmpty),
    )) {
      for (final example in await repository.examples(
        filter: _filter(language: language, productKey: productKey),
      )) {
        final lessonId = example.sourceLessonId;
        if (lessonId != null && example.inputFixtures.isNotEmpty) {
          pairedFixtures.putIfAbsent(lessonId, () => example.inputFixtures);
        }
      }
    }
    final first = entries.first;
    return Tutorial(
      language: first.language,
      type: first.type,
      displayName: displayName,
      schemaVersion: 1,
      updatedAt: first.updatedAt,
      runtime: _runtime(),
      chapters: [
        for (final entry in entries)
          TutorialChapter(
            id: entry.id,
            title: entry.title,
            lessons: [
              for (final lesson in entry.lessons)
                TutorialLesson(
                  id: lesson.id,
                  type: entry.type,
                  language: entry.language,
                  level: entry.level,
                  inputFixtures: lesson.inputFixtures.isNotEmpty
                      ? lesson.inputFixtures
                      : pairedFixtures[lesson.id] ?? const {},
                  title: lesson.title,
                  summary: lesson.summary,
                  concepts: lesson.concepts,
                  explain: lesson.explain,
                  code: lesson.code,
                  output: lesson.output,
                  objective: lesson.objective,
                  prerequisites: lesson.prerequisites,
                  pitfalls: lesson.pitfalls,
                  tasks: [
                    for (final exercise in lesson.exercises)
                      TutorialTask(
                        prompt: exercise.prompt,
                        hint: exercise.hint,
                        answer: exercise.answer,
                      ),
                  ],
                ),
            ],
          ),
      ],
      examples: const [],
    );
  }

  static Future<List<ExampleCode>> loadExamples({
    required ContentRepository repository,
    required String language,
    String? productKey,
  }) async {
    final entries = await repository.examples(
      filter: _filter(language: language, productKey: productKey),
    );
    return [
      for (final entry in entries)
        ExampleCode(
          id: entry.id,
          type: entry.type,
          language: entry.language,
          level: entry.level,
          title: entry.title,
          summary: entry.summary,
          code: entry.code,
          output: entry.expectedOutput,
          sourceLessonId: entry.sourceLessonId,
          concepts: entry.concepts,
          inputFixtures: entry.inputFixtures,
        ),
    ];
  }

  static ContentFilter _filter({required String language, String? productKey}) {
    final key = productKey?.trim().toLowerCase();
    // The main product aggregates every language's local curriculum, so its
    // tabs must not be narrowed to the product id (which is not a content
    // language). The null-profile main shell passes that same id as language;
    // other null-profile callers keep their legacy single-language query.
    if (key == StudioProductCatalog.qfliStudioKey ||
        (key == null &&
            language.trim().toLowerCase() ==
                StudioProductCatalog.qfliStudioKey)) {
      return const ContentFilter();
    }
    if (key != null && key.isNotEmpty) {
      return ContentFilter.forProduct(key);
    }
    return ContentFilter(language: language);
  }

  static TutorialRuntime _runtime() {
    final profile = StudioProfile.current;
    return TutorialRuntime(
      kind: profile?.runtimeKind ?? 'offline-content',
      status: profile?.runtimeStatus ?? 'unavailable',
      engine: profile?.runtimeKind ?? 'offline content',
    );
  }
}
