import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'content_repository.dart';

/// Offline repository backed by the two aggregate package assets.
class AssetContentRepository implements ContentRepository {
  AssetContentRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  static const tutorialAsset = 'assets/content/tutorials.json';
  static const exampleAsset = 'assets/content/examples.json';

  final AssetBundle _bundle;
  Future<ContentCatalog>? _catalogFuture;

  @override
  Future<ContentCatalog> load() => _catalogFuture ??= _loadCatalog();

  @override
  Future<List<TutorialContent>> tutorials({
    ContentFilter filter = const ContentFilter(),
  }) async {
    final catalog = await load();
    return [
      for (final tutorial in catalog.tutorials)
        if (filter.matches(tutorial)) tutorial,
    ];
  }

  @override
  Future<List<ExampleContent>> examples({
    ContentFilter filter = const ContentFilter(),
  }) async {
    final catalog = await load();
    return [
      for (final example in catalog.examples)
        if (filter.matches(example)) example,
    ];
  }

  Future<ContentCatalog> _loadCatalog() async {
    final tutorials = await _loadString(tutorialAsset);
    final examples = await _loadString(exampleAsset);
    return ContentCatalog.fromJson(
      tutorialsSource: tutorials,
      examplesSource: examples,
    );
  }

  Future<String> _loadString(String asset) async {
    final keys = <String>['packages/qfli_studio_core/$asset', asset];
    final failures = <String>[];
    for (final key in keys) {
      try {
        return await _bundle.loadString(key);
      } on FlutterError catch (error) {
        failures.add('$key: ${error.message}');
      } on Exception catch (error) {
        failures.add('$key: $error');
      }
    }
    throw ContentAssetException(asset, failures);
  }
}

class ContentAssetException implements Exception {
  const ContentAssetException(this.asset, this.failures);

  final String asset;
  final List<String> failures;

  @override
  String toString() => 'Unable to load content asset $asset: ${failures.join(' | ')}';
}
