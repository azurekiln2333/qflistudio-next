import 'content_repository.dart';

class ContentValidationIssue {
  const ContentValidationIssue(this.path, this.message);

  final String path;
  final String message;

  @override
  String toString() => '$path: $message';
}

class ContentValidationResult {
  const ContentValidationResult(this.issues);

  final List<ContentValidationIssue> issues;

  bool get isValid => issues.isEmpty;
}

/// Validates aggregate content without changing or rewriting the source JSON.
abstract final class ContentCatalogValidator {
  static const releaseMinimumPerType = 100;

  static ContentValidationResult validate(
    ContentCatalog catalog, {
    bool enforceReleaseMinimum = false,
    Set<String>? requiredTypes,
    int minimumEntriesPerType = releaseMinimumPerType,
  }) {
    final issues = <ContentValidationIssue>[];
    final ids = <String, String>{};

    void validateEntry(ContentEntry entry, String path) {
      if (!entry.hasExplicitId || entry.id.isEmpty) {
        issues.add(ContentValidationIssue(path, 'id is required'));
      }
      if (!entry.hasExplicitLanguage || entry.language.isEmpty) {
        issues.add(ContentValidationIssue(path, 'language is required'));
      }
      if (!entry.hasExplicitType || entry.type.isEmpty) {
        issues.add(ContentValidationIssue(path, 'type is required'));
      }
      for (final field in <MapEntry<String, String>>[
        MapEntry('locale', entry.locale),
        MapEntry('level', entry.level),
        MapEntry('title', entry.title),
        MapEntry('summary', entry.summary),
        MapEntry('source', entry.source),
        MapEntry('license', entry.license),
        MapEntry('updatedAt', entry.updatedAt),
      ]) {
        if (field.value.isEmpty) {
          issues.add(ContentValidationIssue(path, '${field.key} is required'));
        }
      }
      if (entry.concepts.isEmpty) {
        issues.add(ContentValidationIssue(path, 'concepts must not be empty'));
      }
      final previous = ids[entry.id];
      if (entry.id.isNotEmpty && previous != null) {
        issues.add(ContentValidationIssue(path, 'duplicate id; already used at $previous'));
      } else if (entry.id.isNotEmpty) {
        ids[entry.id] = path;
      }
    }

    for (var index = 0; index < catalog.tutorials.length; index++) {
      final tutorial = catalog.tutorials[index];
      final path = 'tutorials[$index]';
      validateEntry(tutorial, path);
      if (tutorial.lessons.isEmpty) {
        issues.add(ContentValidationIssue(path, 'lessons must not be empty'));
      }
      for (var lessonIndex = 0; lessonIndex < tutorial.lessons.length; lessonIndex++) {
        final lesson = tutorial.lessons[lessonIndex];
        final lessonPath = '$path.lessons[$lessonIndex]';
        for (final field in <MapEntry<String, String>>[
          MapEntry('id', lesson.id),
          MapEntry('title', lesson.title),
          MapEntry('summary', lesson.summary),
          MapEntry('explain', lesson.explain),
          MapEntry('code', lesson.code),
          MapEntry('output', lesson.output),
        ]) {
          if (field.value.isEmpty) {
            issues.add(ContentValidationIssue(lessonPath, '${field.key} is required'));
          }
        }
        if (lesson.concepts.isEmpty) {
          issues.add(ContentValidationIssue(lessonPath, 'concepts must not be empty'));
        }
      }
    }

    for (var index = 0; index < catalog.examples.length; index++) {
      final example = catalog.examples[index];
      final path = 'examples[$index]';
      validateEntry(example, path);
      for (final field in <MapEntry<String, String>>[
        MapEntry('code', example.code),
        MapEntry('templateType', example.templateType),
      ]) {
        if (field.value.isEmpty) {
          issues.add(ContentValidationIssue(path, '${field.key} is required'));
        }
      }
    }

    if (enforceReleaseMinimum) {
      final expected = requiredTypes ?? ContentProductTypes.all;
      for (final type in expected) {
        final tutorialCount = catalog.tutorials
            .where((entry) => entry.type.trim().toLowerCase() == type)
            .length;
        final exampleCount = catalog.examples
            .where((entry) => entry.type.trim().toLowerCase() == type)
            .length;
        if (tutorialCount < minimumEntriesPerType) {
          issues.add(
            ContentValidationIssue(
              'tutorials',
              '$type has $tutorialCount entries; requires $minimumEntriesPerType',
            ),
          );
        }
        if (exampleCount < minimumEntriesPerType) {
          issues.add(
            ContentValidationIssue(
              'examples',
              '$type has $exampleCount entries; requires $minimumEntriesPerType',
            ),
          );
        }
      }
    }
    return ContentValidationResult(List.unmodifiable(issues));
  }

  static ContentValidationResult validateForRelease(ContentCatalog catalog) =>
      validate(catalog, enforceReleaseMinimum: true);
}
