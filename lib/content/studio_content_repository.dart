import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:qfli_studio_core/content/asset_content_repository.dart'
    show ContentAssetException;
import 'package:qfli_studio_core/content/content_repository.dart';

/// Offline content source for the QFLIStudio+ main app.
///
/// The main product ships one composed catalog under its own `assets/content/`
/// directory. [tool/generate_studio_content.dart] copies every sibling
/// product's authoritative local curriculum into those documents, so this
/// repository needs no dependency on the language product packages (or their
/// runtimes) at build or runtime.
///
/// The shared core already bundles its own `packages/qfli_studio_core/...
/// assets/content/...` aggregate. In the main app the plain key resolves to the
/// composed catalog, so it is tried first; the package-qualified key keeps the
/// repository usable if it is ever imported from another package's test
/// harness.
class StudioContentRepository implements ContentRepository {
  StudioContentRepository({AssetBundle? bundle})
    : _bundle = bundle ?? rootBundle;

  static const tutorialAsset = 'assets/content/tutorials.json';
  static const exampleAsset = 'assets/content/examples.json';
  static const provenanceAsset = 'assets/content/provenance.json';

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
    final sources = await Future.wait([
      _loadString(tutorialAsset),
      _loadString(exampleAsset),
    ]);
    // AssetBundle decodes UTF-8 off the UI isolate; keep JSON parsing and model
    // construction off it too, matching the shared AssetContentRepository.
    return compute(_parseCatalog, sources, debugLabel: 'parse-studio-content');
  }

  Future<String> _loadString(String asset) async {
    final keys = <String>[asset, 'packages/qflistudio/$asset'];
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

ContentCatalog _parseCatalog(List<String> sources) => ContentCatalog.fromJson(
  tutorialsSource: sources[0],
  examplesSource: sources[1],
);
