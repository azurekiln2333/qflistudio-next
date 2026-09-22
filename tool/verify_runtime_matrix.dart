import 'dart:io';

final _placeholderPattern = RegExp(
  r'开发中|尚未就绪|未就绪|不可用|placeholder|not[ -_]ready|not[ -_]implemented|_notReady|_notWired',
  caseSensitive: false,
);

class ProductSpec {
  const ProductSpec({
    required this.key,
    required this.sourcePath,
    required this.catalogToken,
    required this.profileName,
    required this.types,
    required this.extensions,
    this.isRoot = false,
  });

  final String key;
  final String sourcePath;
  final String catalogToken;
  final String? profileName;
  final List<String> types;
  final List<String> extensions;
  final bool isRoot;
}

const _products = <ProductSpec>[
  ProductSpec(
    key: 'qflistudio',
    sourcePath: 'lib/main.dart',
    catalogToken: 'qfliStudio',
    profileName: 'qfliStudioProfile',
    isRoot: true,
    types: [
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
    ],
    extensions: [
      '.c',
      '.h',
      '.cpp',
      '.cc',
      '.cxx',
      '.hpp',
      '.hh',
      '.lua',
      '.js',
      '.ts',
      '.sh',
      '.rs',
      '.go',
      '.java',
      '.html',
      '.css',
      '.py',
      '.dart',
      '.sql',
      '.json',
      '.md',
    ],
  ),
  ProductSpec(
    key: 'script',
    sourcePath: 'apps/qfli_lua/lib/main.dart',
    catalogToken: 'script',
    profileName: 'luaProfile',
    types: ['lua', 'javascript', 'typescript', 'shell'],
    extensions: ['.lua', '.js', '.ts', '.sh'],
  ),
  ProductSpec(
    key: 'rustcore',
    sourcePath: 'apps/qfli_rust/lib/main.dart',
    catalogToken: 'rustCore',
    profileName: 'rustProfile',
    types: ['rust'],
    extensions: ['.rs'],
  ),
  ProductSpec(
    key: 'goshift',
    sourcePath: 'apps/qfli_go/lib/main.dart',
    catalogToken: 'goShift',
    profileName: 'goProfile',
    types: ['go'],
    extensions: ['.go'],
  ),
  ProductSpec(
    key: 'jvmx',
    sourcePath: 'apps/qfli_java/lib/main.dart',
    catalogToken: 'jvmx',
    profileName: 'javaProfile',
    types: ['java'],
    extensions: ['.java'],
  ),
  ProductSpec(
    key: 'webforge',
    sourcePath: 'apps/qfli_web/lib/main.dart',
    catalogToken: 'webForge',
    profileName: 'webProfile',
    types: ['html', 'css', 'javascript'],
    extensions: ['.html', '.css', '.js'],
  ),
  ProductSpec(
    key: 'pyflow',
    sourcePath: 'apps/qfli_python/lib/main.dart',
    catalogToken: 'pyFlow',
    profileName: 'pythonProfile',
    types: ['python'],
    extensions: ['.py'],
  ),
  ProductSpec(
    key: 'forge',
    sourcePath: 'apps/qfli_c/lib/main.dart',
    catalogToken: 'forge',
    profileName: 'forgeProfile',
    types: ['c', 'cpp'],
    extensions: ['.c', '.h', '.cpp', '.cc', '.cxx', '.hpp', '.hh'],
  ),
  ProductSpec(
    key: 'dartwing',
    sourcePath: 'apps/qfli_dart/lib/main.dart',
    catalogToken: 'dartWing',
    profileName: 'dartProfile',
    types: ['dart'],
    extensions: ['.dart'],
  ),
  ProductSpec(
    key: 'sqlab',
    sourcePath: 'apps/qfli_sql/lib/main.dart',
    catalogToken: 'sqlab',
    profileName: 'sqlProfile',
    types: ['sql'],
    extensions: ['.sql'],
  ),
  ProductSpec(
    key: 'json',
    sourcePath: 'apps/qfli_json/lib/main.dart',
    catalogToken: 'json',
    profileName: 'jsonProfile',
    types: ['json'],
    extensions: ['.json'],
  ),
  ProductSpec(
    key: 'note',
    sourcePath: 'apps/qfli_note/lib/main.dart',
    catalogToken: 'note',
    profileName: 'noteProfile',
    types: ['markdown'],
    extensions: ['.md', '.markdown'],
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

  final diagnostics = <Diagnostic>[];
  final absoluteRoot = Directory(root).absolute.path;
  final profileSources = _discoverProfileSources(absoluteRoot);
  final seenKeys = <String, String>{};
  for (final file in profileSources) {
    final source = file.readAsStringSync();
    final keyMatch = RegExp(
      r'productKey\s*:\s*StudioProductCatalog\.([A-Za-z0-9_]+)Key',
    ).firstMatch(source);
    if (keyMatch == null) continue;
    final key = _catalogKey(keyMatch.group(1)!);
    final relativePath = _relativePath(file.path, absoluteRoot);
    final previousPath = seenKeys[key];
    if (previousPath != null) {
      diagnostics.add(
        Diagnostic(
          relativePath,
          _lineOf(source, keyMatch.start),
          'product key "$key" is duplicated; it is already declared in '
          '$previousPath. Keep one installable profile per product identity.',
        ),
      );
    } else {
      seenKeys[key] = relativePath;
    }
  }

  for (final product in _products) {
    final file = File(_join(absoluteRoot, product.sourcePath));
    if (!file.existsSync()) {
      diagnostics.add(
        Diagnostic(
          product.sourcePath,
          null,
          'missing ${product.key} product profile source; add the profile '
          'before claiming the 12-product release matrix is complete.',
        ),
      );
      continue;
    }
    _verifyProfile(product, file, absoluteRoot, diagnostics);
  }

  final missingKeys = _products
      .map((product) => product.key)
      .where((key) => !seenKeys.containsKey(key) && key != 'qflistudio')
      .toList();
  if (missingKeys.isNotEmpty) {
    diagnostics.add(
      Diagnostic(
        'product catalog',
        null,
        'profile declarations are missing for: ${missingKeys.join(', ')}. '
            'Check productKey and StudioProfile.current wiring.',
      ),
    );
  }

  if (diagnostics.isEmpty) {
    stdout.writeln(
      'PASS: all ${_products.length} product profiles satisfy the release '
      'runtime matrix contract.',
    );
    return;
  }

  stdout.writeln(
    'FAIL: runtime matrix is not release-ready (${diagnostics.length} '
    'diagnostic${diagnostics.length == 1 ? '' : 's'}).',
  );
  for (final diagnostic in diagnostics) {
    stdout.writeln('  - $diagnostic');
  }
  stdout.writeln(
    'Next: add explicit runtimeKind, runtimeStatus, supportedFileExtensions, '
    'and HarmonyOS fixture evidence to each profile; keep unfinished runners '
    'unavailable until their device path is proven.',
  );
  exitCode = 1;
}

void _verifyProfile(
  ProductSpec product,
  File file,
  String root,
  List<Diagnostic> diagnostics,
) {
  final source = file.readAsStringSync();
  final path = _relativePath(file.path, root);
  final profileStart = source.indexOf(RegExp(r'\bStudioProfile\s*\('));
  if (profileStart < 0) {
    diagnostics.add(
      Diagnostic(
        path,
        null,
        'no StudioProfile declaration found for ${product.key}; the root '
        'entrypoint needs an explicit release profile descriptor.',
      ),
    );
  }

  final keyMatch = RegExp(
    r'productKey\s*:\s*StudioProductCatalog\.([A-Za-z0-9_]+)Key',
  ).firstMatch(source);
  if (keyMatch == null) {
    diagnostics.add(
      Diagnostic(
        path,
        null,
        'missing productKey; use StudioProductCatalog.${product.catalogToken}Key '
        'for the ${product.key} product.',
      ),
    );
  } else if (_catalogKey(keyMatch.group(1)!) != product.key) {
    diagnostics.add(
      Diagnostic(
        path,
        _lineOf(source, keyMatch.start),
        'productKey resolves to "${_catalogKey(keyMatch.group(1)!)}", expected '
        '"${product.key}".',
      ),
    );
  }

  if (product.profileName != null &&
      !RegExp(
        'StudioProfile\\s+${RegExp.escape(product.profileName!)}\\s*=\\s*StudioProfile',
      ).hasMatch(source)) {
    diagnostics.add(
      Diagnostic(
        path,
        null,
        'expected profile symbol ${product.profileName}; keep the product '
        'profile name stable so release tooling can identify it.',
      ),
    );
  }

  final runtimeKind = _stringField(source, 'runtimeKind');
  final runtimeStatus = _stringField(source, 'runtimeStatus');
  final extensions =
      _listField(source, 'supportedFileExtensions') ??
      _listField(source, 'supportedExtensions');
  if (runtimeKind == null) {
    diagnostics.add(
      Diagnostic(
        path,
        null,
        'missing runtimeKind; declare the concrete device execution or '
        'preview mechanism for ${product.types.join(', ')}.',
      ),
    );
  }
  if (runtimeStatus == null) {
    diagnostics.add(
      Diagnostic(
        path,
        null,
        'missing runtimeStatus; use available only after a real HarmonyOS '
        'fixture passes, otherwise use unavailable/unsupported.',
      ),
    );
  } else if (runtimeStatus != 'available') {
    diagnostics.add(
      Diagnostic(
        path,
        _fieldLine(source, 'runtimeStatus'),
        'runtimeStatus is "$runtimeStatus" for ${product.key}; the release '
        'gate requires available only after the target fixture passes.',
      ),
    );
  }
  if (extensions == null) {
    diagnostics.add(
      Diagnostic(
        path,
        null,
        'missing supportedFileExtensions; declare every extension handled by '
        '${product.key}: ${product.extensions.join(', ')}.',
      ),
    );
  } else {
    final normalized = extensions.map((value) => value.toLowerCase()).toSet();
    final missing = product.extensions
        .where((extension) => !normalized.contains(extension))
        .toList();
    if (missing.isNotEmpty) {
      diagnostics.add(
        Diagnostic(
          path,
          _fieldLine(source, 'supportedFileExtensions') ??
              _fieldLine(source, 'supportedExtensions'),
          'supported file extensions omit ${missing.join(', ')} for '
          '${product.key}.',
        ),
      );
    }
  }

  final runnerMatch = RegExp(
    r'\brunner\s*:\s*([A-Za-z0-9_]+)\s*\(',
  ).firstMatch(source);
  final runtimeFiles = _runtimeFiles(file.parent);
  if (runtimeStatus == 'available') {
    if (runnerMatch == null &&
        runtimeKind != null &&
        !runtimeKind.toLowerCase().contains('preview')) {
      diagnostics.add(
        Diagnostic(
          path,
          null,
          'runtimeStatus is available but no runner is wired; connect a '
          'NativeRuntime/preview implementation before release.',
        ),
      );
    }
    for (final runtimeFile in runtimeFiles) {
      final runtimeSource = runtimeFile.readAsStringSync();
      final placeholder = _placeholderPattern.firstMatch(runtimeSource);
      if (placeholder == null) continue;
      diagnostics.add(
        Diagnostic(
          _relativePath(runtimeFile.path, root),
          _lineOf(runtimeSource, placeholder.start),
          'placeholder runtime marker "${placeholder.group(0)}" is reachable '
          'from an available ${product.key} profile; complete the backend '
          'or mark the profile unavailable.',
        ),
      );
    }
  }
}

List<File> _runtimeFiles(Directory libDirectory) {
  if (!libDirectory.existsSync()) return const [];
  return libDirectory
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .toList();
}

List<File> _discoverProfileSources(String root) {
  final files = <File>[];
  final rootMain = File(_join(root, 'lib/main.dart'));
  if (rootMain.existsSync()) files.add(rootMain);
  final apps = Directory(_join(root, 'apps'));
  if (!apps.existsSync()) return files;
  for (final entry in apps.listSync()) {
    if (entry is! Directory) continue;
    final main = File(_join(entry.path, 'lib/main.dart'));
    if (main.existsSync()) files.add(main);
  }
  return files;
}

String? _stringField(String source, String field) => RegExp(
  r'''\b''' + RegExp.escape(field) + r'''\s*:\s*['"]([^'"]+)['"]''',
).firstMatch(source)?.group(1);

List<String>? _listField(String source, String field) {
  final match = RegExp(
    '\\b${RegExp.escape(field)}\\s*:\\s*\\[([\\s\\S]*?)\\]',
  ).firstMatch(source);
  if (match == null) return null;
  return RegExp(r'''['"]([^'"]+)['"]''')
      .allMatches(match.group(1)!)
      .map((item) => item.group(1)!.toLowerCase())
      .toList();
}

int? _fieldLine(String source, String field) {
  final index = source.indexOf(RegExp('\\b${RegExp.escape(field)}\\b'));
  return index < 0 ? null : _lineOf(source, index);
}

int _lineOf(String source, int offset) =>
    '\n'.allMatches(source.substring(0, offset)).length + 1;

String _catalogKey(String token) {
  const keys = <String, String>{
    'qfliStudio': 'qflistudio',
    'script': 'script',
    'rustCore': 'rustcore',
    'goShift': 'goshift',
    'jvmx': 'jvmx',
    'webForge': 'webforge',
    'pyFlow': 'pyflow',
    'forge': 'forge',
    'dartWing': 'dartwing',
    'sqlab': 'sqlab',
    'json': 'json',
    'note': 'note',
  };
  return keys[token] ?? token;
}

String? _parseRoot(List<String> args) {
  if (args.contains('--help')) {
    stdout.writeln(
      'Usage: dart run tool/verify_runtime_matrix.dart [--root PATH]',
    );
    return null;
  }
  if (args.isEmpty) return Directory.current.path;
  if (args.length == 2 && args.first == '--root') return args[1];
  if (args.length == 1 && args.first.startsWith('--root=')) {
    return args.first.substring('--root='.length);
  }
  stderr.writeln(
    'Usage: dart run tool/verify_runtime_matrix.dart [--root PATH]',
  );
  exitCode = 2;
  return null;
}

String _join(String first, String second) =>
    '$first${Platform.pathSeparator}$second';

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
