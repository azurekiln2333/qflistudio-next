import 'dart:io';

class ProductPackage {
  const ProductPackage({
    required this.key,
    required this.appScopePath,
    required this.bundleName,
  });

  final String key;
  final String appScopePath;
  final String bundleName;
}

const _products = <ProductPackage>[
  ProductPackage(
    key: 'qflistudio',
    appScopePath: 'ohos/AppScope/app.json5',
    bundleName: 'com.azurekiln.qflistudio',
  ),
  ProductPackage(
    key: 'script',
    appScopePath: 'apps/qfli_lua/ohos/AppScope/app.json5',
    bundleName: 'com.azurekiln.qfli.script',
  ),
  ProductPackage(
    key: 'rustcore',
    appScopePath: 'apps/qfli_rust/ohos/AppScope/app.json5',
    bundleName: 'com.azurekiln.qfli.rustcore',
  ),
  ProductPackage(
    key: 'goshift',
    appScopePath: 'apps/qfli_go/ohos/AppScope/app.json5',
    bundleName: 'com.azurekiln.qfli.goshift',
  ),
  ProductPackage(
    key: 'jvmx',
    appScopePath: 'apps/qfli_java/ohos/AppScope/app.json5',
    bundleName: 'com.azurekiln.qfli.jvmx',
  ),
  ProductPackage(
    key: 'webforge',
    appScopePath: 'apps/qfli_web/ohos/AppScope/app.json5',
    bundleName: 'com.azurekiln.qfli.webforge',
  ),
  ProductPackage(
    key: 'pyflow',
    appScopePath: 'apps/qfli_python/ohos/AppScope/app.json5',
    bundleName: 'com.azurekiln.qfli.pyflow',
  ),
  ProductPackage(
    key: 'forge',
    appScopePath: 'apps/qfli_c/ohos/AppScope/app.json5',
    bundleName: 'com.azurekiln.qfli.forge',
  ),
  ProductPackage(
    key: 'dartwing',
    appScopePath: 'apps/qfli_dart/ohos/AppScope/app.json5',
    bundleName: 'com.azurekiln.qfli.dartwing',
  ),
  ProductPackage(
    key: 'sqlab',
    appScopePath: 'apps/qfli_sql/ohos/AppScope/app.json5',
    bundleName: 'com.azurekiln.qfli.sqlab',
  ),
  ProductPackage(
    key: 'json',
    appScopePath: 'apps/qfli_json/ohos/AppScope/app.json5',
    bundleName: 'com.azurekiln.qfli.json',
  ),
  ProductPackage(
    key: 'note',
    appScopePath: 'apps/qfli_note/ohos/AppScope/app.json5',
    bundleName: 'com.azurekiln.qfli.note',
  ),
];

class Diagnostic {
  const Diagnostic(this.path, this.line, this.message);

  final String path;
  final int? line;
  final String message;

  @override
  String toString() =>
      line == null ? '$path: $message' : '$path:$line: $message';
}

void main(List<String> args) {
  final root = _parseRoot(args);
  if (root == null) return;

  final absoluteRoot = Directory(root).absolute.path;
  final diagnostics = <Diagnostic>[];
  final expectedPaths = <String, ProductPackage>{
    for (final product in _products)
      _normalizePath(_join(absoluteRoot, product.appScopePath)): product,
  };

  final discovered = _discoverAppScopes(absoluteRoot);
  for (final file in discovered) {
    final normalized = _normalizePath(file.path);
    if (!expectedPaths.containsKey(normalized)) {
      diagnostics.add(
        Diagnostic(
          _relativePath(file.path, absoluteRoot),
          null,
          'unexpected HarmonyOS AppScope manifest; add it to the product '
          'catalog or remove the installable product before release.',
        ),
      );
    }
  }

  final seenBundles = <String, String>{};
  for (final product in _products) {
    final file = File(_join(absoluteRoot, product.appScopePath));
    if (!file.existsSync()) {
      diagnostics.add(
        Diagnostic(
          product.appScopePath,
          null,
          'missing ${product.key} AppScope manifest; the release must contain '
          'exactly ${_products.length} HarmonyOS product manifests.',
        ),
      );
      continue;
    }

    final source = file.readAsStringSync();
    final matches = RegExp(
      r'"bundleName"\s*:\s*"([^"]+)"',
    ).allMatches(source).toList();
    final path = _relativePath(file.path, absoluteRoot);
    if (matches.isEmpty) {
      diagnostics.add(
        Diagnostic(
          path,
          null,
          'missing app.bundleName; set it to "${product.bundleName}" for '
          '${product.key}.',
        ),
      );
      continue;
    }
    if (matches.length > 1) {
      diagnostics.add(
        Diagnostic(
          path,
          _lineOf(source, matches[1].start),
          'multiple bundleName declarations found; keep one canonical package '
          'identifier in AppScope/app.json5.',
        ),
      );
    }

    final actual = matches.first.group(1)!;
    final previousPath = seenBundles[actual];
    if (previousPath != null) {
      diagnostics.add(
        Diagnostic(
          path,
          _lineOf(source, matches.first.start),
          'bundleName "$actual" is duplicated; it is already used by '
          '$previousPath. Each installable product needs its own package.',
        ),
      );
    } else {
      seenBundles[actual] = path;
    }
    if (actual != product.bundleName) {
      diagnostics.add(
        Diagnostic(
          path,
          _lineOf(source, matches.first.start),
          'bundleName is "$actual", expected "${product.bundleName}" for '
          '${product.key}; update the manifest and matching signing '
          'profile together.',
        ),
      );
    }
  }

  if (discovered.length != _products.length) {
    diagnostics.add(
      Diagnostic(
        'HarmonyOS product catalog',
        null,
        'discovered ${discovered.length} AppScope manifests, expected '
            '${_products.length}; inspect the unexpected and missing paths '
            'listed above.',
      ),
    );
  }

  if (diagnostics.isEmpty) {
    stdout.writeln(
      'PASS: all ${_products.length} HarmonyOS product identifiers are unique '
      'and match the release catalog.',
    );
    return;
  }

  stdout.writeln(
    'FAIL: HarmonyOS product identifiers are not release-ready '
    '(${diagnostics.length} diagnostic${diagnostics.length == 1 ? '' : 's'}).',
  );
  for (final diagnostic in diagnostics) {
    stdout.writeln('  - $diagnostic');
  }
  stdout.writeln(
    'Next: keep the package key, app manifest, signing profile, and release '
    'artifact aligned; do not reuse a bundleName across products.',
  );
  exitCode = 1;
}

List<File> _discoverAppScopes(String root) {
  final files = <File>[];
  final rootManifest = File(_join(root, 'ohos/AppScope/app.json5'));
  if (rootManifest.existsSync()) files.add(rootManifest);

  final apps = Directory(_join(root, 'apps'));
  if (!apps.existsSync()) return files;
  for (final entry in apps.listSync()) {
    if (entry is! Directory) continue;
    final manifest = File(_join(entry.path, 'ohos/AppScope/app.json5'));
    if (manifest.existsSync()) files.add(manifest);
  }
  return files;
}

String? _parseRoot(List<String> args) {
  if (args.contains('--help')) {
    stdout.writeln(
      'Usage: dart run tool/verify_ohos_products.dart [--root PATH]',
    );
    return null;
  }
  if (args.isEmpty) return Directory.current.path;
  if (args.length == 2 && args.first == '--root') return args[1];
  if (args.length == 1 && args.first.startsWith('--root=')) {
    return args.first.substring('--root='.length);
  }
  stderr.writeln(
    'Usage: dart run tool/verify_ohos_products.dart [--root PATH]',
  );
  exitCode = 2;
  return null;
}

String _join(String first, String second) =>
    '$first${Platform.pathSeparator}$second';

String _normalizePath(String path) =>
    File(path).absolute.path.replaceAll('\\', '/').toLowerCase();

String _relativePath(String path, String root) {
  final normalizedPath = path.replaceAll('\\', '/');
  final normalizedRoot = root
      .replaceAll('\\', '/')
      .replaceFirst(RegExp(r'/$'), '');
  if (normalizedPath.startsWith('$normalizedRoot/')) {
    return normalizedPath.substring(normalizedRoot.length + 1);
  }
  return normalizedPath;
}

int _lineOf(String source, int offset) =>
    '\n'.allMatches(source.substring(0, offset)).length + 1;
