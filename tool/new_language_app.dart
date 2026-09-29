// 从并列仓库 qfli_c 生成一个新的语言专属 App。
//
// 用法：
//   dart run tool/new_language_app.dart              # 生成全部尚未生成的 App
//   dart run tool/new_language_app.dart web python   # 只生成指定的
//   dart run tool/new_language_app.dart --force web  # 覆盖已存在的目录（合并，不删除）
//
// 为什么是「生成」而不是「手抄」：一个语言一个 App 意味着每个新语言都要复制
// 一整套平台工程（android/ios/macos/linux/windows/web/ohos）再改品牌信息，
// 手抄必然会漏掉某处 applicationId 或窗口标题，而且漏了不容易发现。这个脚本
// 把「机械部分」集中到一处，把「每个语言真正不同的部分」（档位、运行后端、
// 测试）留在下面 _specs 里显式写清楚。
//
// 每个 App 里真正与语言相关的只有三个文件：
//   lib/main.dart            档位：收窄模板、指定入口文件、挂上运行后端
//   lib/<id>_runner.dart     运行后端（解释器接入点）
//   test/<id>_app_test.dart  接线测试
// 其余都是内核提供的同一套 UI。
//
// 生成完还会顺手把 ohos/ 的依赖装上（npm install + ohpm install），否则这个 App
// 在 DevEco 里连 Sync 都过不去——本机上没有任何自动流程会做这一步，详见
// _bootstrapOhos 的注释。
import 'dart:io';

import 'package:path/path.dart' as p;

/// 模板来源：C 版已经跑通，作为所有语言 App 的骨架。
const String _templateApp = '../qfli_c';

/// 复制时整目录跳过的名字（构建产物与 IDE/包管理缓存）。
const Set<String> _skipDirs = <String>{
  '.git',
  'packages',
  'build',
  '.dart_tool',
  '.idea',
  '.gradle',
  '.cxx',
  '.hvigor',
  '.preview',
  'ephemeral',
  'oh_modules',
  'node_modules',
};

/// 复制时跳过的文件（生成物，构建时会重新产出；或属于 C 版专有）。
const Set<String> _skipFiles = <String>{
  'pubspec.lock',
  '.flutter-plugins-dependencies',
  '.flutter',
  '.flutter_tool_state',
  'Generated.xcconfig',
  'Flutter-Generated.xcconfig',
  'flutter_export_environment.sh',
  'generated_plugin_registrant.cc',
  'generated_plugin_registrant.h',
  'GeneratedPluginRegistrant.h',
  'GeneratedPluginRegistrant.m',
  'GeneratedPluginRegistrant.swift',
};

/// 一个语言 App 的全部差异点。
class _Spec {
  const _Spec({
    required this.id,
    required this.displayName,
    required this.template,
    required this.entryFileNames,
    required this.runnerClass,
    required this.sourceExtensions,
    required this.description,
    required this.htmlDescription,
    required this.pendingRunner,
    this.productTitle,
    this.packageKey,
  });

  /// 目录名后缀，也是档位 id：`web` → `../qfli_web`。
  final String id;

  /// 展示名，例如 `Python`。
  final String displayName;

  /// 新建项目时放行的模板。
  final String template;

  /// 入口文件候选，按优先级排列。
  final List<String> entryFileNames;

  /// 运行后端类名；为空表示不需要后端（交给内核）。
  final String? runnerClass;

  /// 后端接管的源码后缀。
  final List<String> sourceExtensions;

  /// App 描述（pubspec 用，带产品名前缀）。
  final String description;

  /// `web/index.html` 的 description：那里产品名前缀由模板自带，
  /// 所以这里只给后缀句，否则会拼成「X 版：X 版：……」。
  final String htmlDescription;

  /// true 表示解释器还没落地，后端先返回「开发中」。
  final bool pendingRunner;

  final String? productTitle;
  final String? packageKey;

  /// `QFLIStudio+ C 版` 里的 `C` 换成这个。
  String get title => productTitle ?? 'QFLIStudio+ $displayName 版';

  /// macOS 的 PRODUCT_NAME 不带「版」。
  String get macName => title;

  String get appDir => '../qfli_$id';

  String get runtimePackage => 'qfli_${id}_runtime';

  String get androidAppId => 'com.azurekiln.qfli.${packageKey ?? id}';

  String get ohosBundleName => androidAppId;

  /// Windows 的窗口标题。C++ 源码里只把非 ASCII 字符写成 `\uXXXX`，
  /// ASCII 原样保留——全是转义虽然也对，但没人读得出来。
  String get cppEscapedTitle => title.runes.map((r) {
    if (r >= 0x20 && r < 0x7F) return String.fromCharCode(r);
    return '\\u${r.toRadixString(16).padLeft(4, '0')}';
  }).join();

  String get entryList => entryFileNames.map((e) => "'$e'").join(', ');
}

const List<_Spec> _specs = <_Spec>[
  _Spec(
    id: 'rust',
    displayName: 'Rust',
    productTitle: 'QFLIRustCore',
    packageKey: 'rustcore',
    template: 'rust',
    entryFileNames: ['main.rs', 'src/main.rs'],
    runnerClass: 'RustProgramRunner',
    sourceExtensions: ['.rs'],
    description: 'QFLIRustCore：Rust 编辑器与桌面工具链入口。',
    htmlDescription: 'Rust 编辑器与桌面工具链入口。',
    pendingRunner: true,
  ),
  _Spec(
    id: 'go',
    displayName: 'Go',
    productTitle: 'QFLIGoShift',
    packageKey: 'goshift',
    template: 'go',
    entryFileNames: ['main.go', 'src/main.go'],
    runnerClass: 'GoProgramRunner',
    sourceExtensions: ['.go'],
    description: 'QFLIGoShift：Go 编辑器与桌面工具链入口。',
    htmlDescription: 'Go 编辑器与桌面工具链入口。',
    pendingRunner: true,
  ),
  _Spec(
    id: 'sql',
    displayName: 'SQL',
    productTitle: 'QFLISQLab',
    packageKey: 'sqlab',
    template: 'sql',
    entryFileNames: ['main.sql', 'src/main.sql'],
    runnerClass: 'SqlProgramRunner',
    sourceExtensions: ['.sql'],
    description: 'QFLISQLab：SQLite 数据库与 SQL 工作流。',
    htmlDescription: 'SQLite 数据库与 SQL 工作流。',
    pendingRunner: true,
  ),
  _Spec(
    id: 'json',
    displayName: 'JSON',
    productTitle: 'QFLIJson',
    packageKey: 'json',
    template: 'json',
    entryFileNames: ['data.json', 'src/data.json'],
    runnerClass: null,
    sourceExtensions: ['.json'],
    description: 'QFLIJson：JSON 编辑、校验、格式化与结构预览。',
    htmlDescription: 'JSON 编辑、校验、格式化与结构预览。',
    pendingRunner: false,
  ),
  _Spec(
    id: 'note',
    displayName: 'Markdown',
    productTitle: 'QFLINote',
    packageKey: 'note',
    template: 'markdown',
    entryFileNames: ['README.md', 'src/README.md'],
    runnerClass: null,
    sourceExtensions: ['.md', '.markdown'],
    description: 'QFLINote：Markdown 编辑与预览。',
    htmlDescription: 'Markdown 编辑与预览。',
    pendingRunner: false,
  ),
  _Spec(
    id: 'cpp',
    displayName: 'C++',
    template: 'cpp',
    entryFileNames: ['main.cpp', 'src/main.cpp'],
    runnerClass: 'CppProgramRunner',
    sourceExtensions: ['.cpp', '.cc', '.cxx', '.hpp', '.hh'],
    description: 'QFLIStudio+ C++ 版：手机上的 C++ IDE，本地解释执行。',
    htmlDescription: '手机上的 C++ IDE，本地解释执行。',
    pendingRunner: true,
  ),
  _Spec(
    id: 'lua',
    displayName: 'Lua',
    template: 'lua',
    entryFileNames: ['main.lua', 'src/main.lua'],
    runnerClass: 'LuaProgramRunner',
    sourceExtensions: ['.lua'],
    description: 'QFLIStudio+ Lua 版：手机上的 Lua IDE，本地解释执行。',
    htmlDescription: '手机上的 Lua IDE，本地解释执行。',
    pendingRunner: true,
  ),
  _Spec(
    id: 'web',
    displayName: 'Web',
    // 枚举成员叫 html，展示名才是 'Web'。
    template: 'html',
    entryFileNames: ['index.html', 'src/index.html'],
    // Web 不需要自带解释器：内核的 RunnerService 已经会用 LocalWebServer
    // 起一个本地静态服务器并注入调试桥，这里不接管反而是对的。
    runnerClass: null,
    sourceExtensions: ['.html', '.htm'],
    description: 'QFLIStudio+ Web 版：手机上的网页 IDE，本地静态服务器预览，console 输出回传到编辑器。',
    htmlDescription: '手机上的网页 IDE：本地静态服务器预览，console 输出回传到编辑器。',
    pendingRunner: false,
  ),
  _Spec(
    id: 'python',
    displayName: 'Python',
    template: 'python',
    entryFileNames: ['main.py', 'src/main.py'],
    runnerClass: 'PythonProgramRunner',
    sourceExtensions: ['.py'],
    description: 'QFLIStudio+ Python 版：手机上的 Python IDE，本地解释执行。',
    htmlDescription: '手机上的 Python IDE，本地解释执行。',
    pendingRunner: true,
  ),
  _Spec(
    id: 'java',
    displayName: 'Java',
    template: 'java',
    entryFileNames: ['Main.java', 'src/Main.java'],
    runnerClass: 'JavaProgramRunner',
    sourceExtensions: ['.java'],
    description: 'QFLIStudio+ Java 版：手机上的 Java IDE，本地解释执行。',
    htmlDescription: '手机上的 Java IDE，本地解释执行。',
    pendingRunner: true,
  ),
  _Spec(
    id: 'dart',
    displayName: 'Dart',
    template: 'dart',
    entryFileNames: ['main.dart', 'src/main.dart'],
    runnerClass: 'DartProgramRunner',
    sourceExtensions: ['.dart'],
    description: 'QFLIStudio+ Dart 版：手机上的 Dart IDE，本地解释执行。',
    htmlDescription: '手机上的 Dart IDE，本地解释执行。',
    pendingRunner: true,
  ),
];

void main(List<String> args) {
  final force = args.contains('--force');
  final wanted = args.where((a) => !a.startsWith('-')).toSet();

  final root = _findRepoRoot();
  final selected = _specs
      .where((s) => wanted.isEmpty || wanted.contains(s.id))
      .toList();

  if (selected.isEmpty) {
    stderr.writeln('没有匹配的语言。可选：${_specs.map((s) => s.id).join(', ')}');
    exitCode = 2;
    return;
  }

  for (final spec in selected) {
    _generate(root, spec, force: force);
  }

  stdout.writeln('\n完成。请在每个新 App 目录运行 `flutter pub get`。');
}

void _generate(String root, _Spec spec, {required bool force}) {
  final dest = Directory(p.join(root, spec.appDir));
  if (dest.existsSync() && !force) {
    stdout.writeln('跳过 ${spec.appDir}（已存在，加 --force 可覆盖）');
    return;
  }

  // 覆盖采用「合并」语义：把骨架文件拷过去覆盖同名文件，**不删除**目录里
  // 已有的其他文件。这样重复执行是幂等的，也不会因为一次误操作清掉别人放在
  // 这个 App 里的东西。
  final copied = _copyTree(Directory(p.join(root, _templateApp)), dest);
  _brand(spec, dest);
  _writeSources(spec, dest);
  // Flutter 测试/工具链需要这个项目标记；它被 gitignore，
  // 但不能依赖用户手动再跑一次 flutter create 才出现。
  _write(p.join(dest.path, '.flutter'), '');
  _write(p.join(dest.path, '.flutter_tool_state'), '{\n  "is-bot": true\n}\n');
  _initGitRepository(dest);
  _bootstrapOhos(dest, spec);
  stdout.writeln('生成 ${spec.appDir}（写入 $copied 个骨架文件）');
}

void _initGitRepository(Directory dest) {
  if (Directory(p.join(dest.path, '.git')).existsSync()) return;
  final result = Process.runSync(
    'git',
    ['init', '-b', 'main'],
    workingDirectory: dest.path,
    runInShell: Platform.isWindows,
  );
  if (result.exitCode != 0) {
    throw StateError('无法初始化 ${dest.path} 的 Git 仓库：${result.stderr}');
  }
}

/// 把新 App 的 `ohos/` 依赖装上，否则一在 DevEco 里 Sync 就报
/// `Cannot find module 'flutter-hvigor-plugin'`。
///
/// 两步都不能省，而且**本机上没有任何自动流程会做它们**：
///
/// - `npm install` —— 装 `flutter-hvigor-plugin`。`hvigorconfig.ts` 在配置阶段就要
///   加载它，所以缺了它连 Sync 都进不去。
/// - `ohpm install` —— 装 `@ohos/hypium` 等 ohpm 依赖。
///
/// 为什么 flutter 工具不帮忙：正常流程里 `installHvigorPlugin` 负责 npm install，
/// 但它在 `ensureReadyForPlatformSpecificTooling` 里排在 `updateLocalProperties`
/// **后面**，后者找不到 HarmonyOS SDK 就直接退出，npm install 永远轮不到执行。
/// DevEco Studio 打开项目时也只跑 ohpm 那一半，不管 npm。所以生成器必须自己补。
void _bootstrapOhos(Directory dest, _Spec spec) {
  final ohos = Directory(p.join(dest.path, 'ohos'));
  if (!ohos.existsSync()) return;

  _runStep(
    'npm install',
    'npm',
    <String>['install', '--no-audit', '--no-fund'],
    ohos.path,
    useShell: true,
  );

  final pmCli = _findOhpmCli();
  final node = _findNode();
  if (pmCli == null || node == null) {
    stdout.writeln(
      '  ! 没自动跑 ohpm install，请在 ${spec.appDir}/ohos 手动执行一次：'
      'ohpm install',
    );
    return;
  }
  // 这里**不能**用 shell：node 的绝对路径带空格（`...\DevEco Studio\tools\...`），
  // 走 shell 拼命令行时不会被加引号，会报「不是内部或外部命令」。
  _runStep('ohpm install', node, <String>[pmCli, 'install'], ohos.path);
}

/// 跑一步依赖安装。失败只警告，不让整个生成失败——骨架文件已经写好了，
/// 用户手动补一条命令即可。
void _runStep(
  String label,
  String exe,
  List<String> args,
  String cwd, {
  bool useShell = false,
}) {
  try {
    final result = Process.runSync(
      exe,
      args,
      workingDirectory: cwd,
      runInShell: useShell,
    );
    if (result.exitCode == 0) {
      stdout.writeln('  $label 完成');
      return;
    }
    stdout.writeln('  ! $label 退出码 ${result.exitCode}');
    final tail = '${result.stderr}'.trim().split('\n');
    if (tail.isNotEmpty && tail.last.trim().isNotEmpty) {
      stdout.writeln('    ${tail.last.trim()}');
    }
  } on ProcessException catch (e) {
    stdout.writeln('  ! 跑不了 $label（$exe）：${e.message}');
  }
}

/// 找 DevEco 自带的 ohpm 入口。
///
/// 直接用 `pm-cli.js` 而不是 `ohpm.bat`：那个 .bat 在 Git Bash 这类受限 shell 下
/// 会自我递归（`BATCH RECURSION exceeds STACK limits`），而 pm-cli.js 不会。
List<String> _devEcoRoots() {
  final roots = <String>[];
  final env = Platform.environment;
  for (final key in <String>['DEVECO_SDK_HOME', 'DEVECO_HOME']) {
    final value = env[key];
    if (value == null || value.isEmpty) continue;
    // DEVECO_SDK_HOME 通常指向 <DevEco>/sdk，往上一层就是安装根目录。
    roots.add(p.dirname(p.normalize(value)));
    roots.add(value);
  }
  if (Platform.isWindows) {
    roots.addAll(const <String>[
      r'D:\ProgramFiles\Huawei\DevEco Studio',
      r'C:\Program Files\Huawei\DevEco Studio',
    ]);
  } else if (Platform.isMacOS) {
    roots.add('/Applications/DevEco-Studio.app/Contents');
  }
  return roots;
}

String? _findOhpmCli() {
  for (final root in _devEcoRoots()) {
    final candidate = p.join(root, 'tools', 'ohpm', 'bin', 'pm-cli.js');
    if (File(candidate).existsSync()) return candidate;
  }
  return null;
}

String? _findNode() {
  for (final root in _devEcoRoots()) {
    final candidate = p.join(root, 'tools', 'node', 'node.exe');
    if (File(candidate).existsSync()) return candidate;
  }
  // 退而求其次：DevEco 之外的 node 也能跑 pm-cli.js。
  return Platform.isWindows ? 'node.exe' : 'node';
}

/// 复制骨架。`lib/`、`test/`、`pubspec.yaml` 与 `native/` 都不抄，
/// 前三个下面会重新生成，`native/` 是 C 版专有的 picoc 桥。
///
/// 手工递归而不是 `listSync(recursive: true)`：构建目录里存在 ohpm 缓存留下的
/// 带 `*` 的路径，递归列举会先撞上它再抛异常——必须在**下探之前**就跳过。
int _copyTree(Directory from, Directory to) {
  var count = 0;

  void walk(Directory dir, List<String> segments) {
    final List<FileSystemEntity> entries;
    try {
      entries = dir.listSync(followLinks: false);
    } on FileSystemException {
      // 某个子目录读不动（权限/残留）不该让整个生成失败。
      return;
    }
    for (final entity in entries) {
      final name = p.basename(entity.path);
      final path = [...segments, name];

      if (_skipDirs.contains(name)) continue;
      if (path.length == 1 &&
          (name == 'native' || name == 'lib' || name == 'test')) {
        continue;
      }
      if (_skipFiles.contains(name)) continue;

      if (entity is Directory) {
        walk(entity, path);
      } else if (entity is File) {
        if (path.length == 1 && name == 'pubspec.yaml') continue;
        final target = File(p.joinAll([to.path, ...path]));
        target.parent.createSync(recursive: true);
        entity.copySync(target.path);
        count++;
      }
    }
  }

  walk(from, const <String>[]);
  return count;
}

/// 把平台工程里的品牌信息整体替换掉。
///
/// 用「全局文本替换 + 长串优先」而不是逐文件逐字段改：平台工程里有太多地方
/// 顺手写死了包名和产品名（包括注释），逐个列举必然漏。长串优先是为了让
/// `qfli_c_runtime` 先于 `qfli_c` 被替换、`QFLIStudio+ C 版` 先于
/// `QFLIStudio+ C`。
void _brand(_Spec spec, Directory dest) {
  final replacements = <String, String>{
    // 越长的键越先替换。
    'com.azurekiln.qflistudio.c': spec.ohosBundleName,
    'com.example.qflistudio.c': spec.androidAppId,
    'com.azurekiln.qfli.c': spec.ohosBundleName,
    'QFLIForge': spec.title,
    r'QFLIStudio+ C \u7248': spec.cppEscapedTitle,
    'QFLIStudio+ C 版': spec.title,
    'QFLIStudio+ C': spec.macName,
    'qfli_c_runtime': spec.runtimePackage,
    'qfli_c': 'qfli_${spec.id}',
    // web/index.html 里的描述句子带语言名，单独换掉（只换后缀句，
    // 产品名前缀由模板自带）。
    '手机上的 C 语言 IDE，本地解释执行。': spec.htmlDescription,
  };
  final keys = replacements.keys.toList()
    ..sort((a, b) => b.length.compareTo(a.length));

  for (final entity in dest.listSync(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    if (!_isTextFile(entity.path)) continue;

    final String text;
    try {
      text = entity.readAsStringSync();
    } on FileSystemException {
      continue;
    }

    var updated = text;
    for (final key in keys) {
      if (updated.contains(key)) {
        updated = updated.replaceAll(key, replacements[key]!);
      }
    }
    if (updated != text) entity.writeAsStringSync(updated);
  }
}

/// 只改文本文件，跳过图标等二进制资源。
bool _isTextFile(String path) {
  const textExtensions = <String>{
    '.dart',
    '.yaml',
    '.yml',
    '.kts',
    '.gradle',
    '.xml',
    '.plist',
    '.json',
    '.json5',
    '.cpp',
    '.cc',
    '.h',
    '.txt',
    '.html',
    '.xcconfig',
    '.properties',
    '.cmake',
    '.swift',
    '.m',
    '.js',
    '.ts',
    '.ets',
    '.md',
    '.lock',
  };
  final name = p.basename(path);
  if (name == 'CMakeLists.txt') return true;
  return textExtensions.contains(p.extension(path).toLowerCase());
}

/// 写这个 App 真正独有的三个文件。
void _writeSources(_Spec spec, Directory dest) {
  _write(p.join(dest.path, 'pubspec.yaml'), _pubspec(spec));
  _write(p.join(dest.path, 'lib', 'main.dart'), _mainDart(spec));
  if (spec.runnerClass != null) {
    // 目前所有需要后端的语言，解释器都还在开发中，统一用占位后端。
    // 解释器落地后，在这里按 spec 分派到真实实现。
    assert(spec.pendingRunner, '${spec.id} 需要真实后端实现');
    _write(
      p.join(dest.path, 'lib', '${spec.id}_runner.dart'),
      _pendingRunner(spec),
    );
  }
  _write(
    p.join(dest.path, 'test', '${spec.id}_app_test.dart'),
    spec.id == 'web' ? _webTest(spec) : _pendingRunnerTest(spec),
  );
}

void _write(String path, String content) {
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(content);
}

String _pubspec(_Spec spec) {
  // 解释器还没落地，先不依赖运行时包——免得 pub get 直接失败。
  // 解释器写好之后，在这里加回 qfli_<id>_runtime 并在 runner 里 import。
  return '''
name: qfli_${spec.id}
description: "${spec.description}"
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: ^3.11.5

dependencies:
  flutter:
    sdk: flutter

  qfli_studio_core:
    path: ../qfli_studio_core

  cupertino_icons: ^1.0.8

dependency_overrides:
  re_editor:
    path: ../qfli_studio_core/vendor/re_editor

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0

flutter:
  uses-material-design: true
  assets:
    - assets/app_icon.png
''';
}

String _mainDart(_Spec spec) {
  final runnerLine = spec.runnerClass == null
      ? '''
  // 本版不注入运行后端：`.html` 交给内核已有的分流逻辑——它会起一个本地静态
  // 服务器、注入调试桥，并把 console 输出回传到编辑器。也就是说 Web 版的
  // 「运行」能力内核已经具备，这里少写一行反而是完整的。
'''
      : '  runner: ${spec.runnerClass}(),\n';

  final importRunner = spec.runnerClass == null
      ? ''
      : "\nimport '${spec.id}_runner.dart';\n";

  return '''
import 'dart:async';

import 'package:flutter/material.dart';

import 'package:qfli_studio_core/app.dart';
import 'package:qfli_studio_core/services/project_templates.dart';
import 'package:qfli_studio_core/services/studio_profile.dart';
import 'package:qfli_studio_core/splash_screen.dart';
import 'package:qfli_studio_core/store/auth_store.dart';
import 'package:qfli_studio_core/store/project_store.dart';
import 'package:qfli_studio_core/store/settings_store.dart';
$importRunner
/// 本 App 的产品名。窗口标题、任务切换器和应用内顶栏都读它。
const String _appTitle = '${spec.title}';

/// ${spec.displayName} 版档位：同一套内核 UI，收窄成只服务 ${spec.displayName}。
///
/// 单独提出来是为了让测试能直接断言档位，而不必为了一个常量去跑 `main()`。
const StudioProfile ${spec.id}Profile = StudioProfile(
  id: '${spec.id}',
  appTitle: _appTitle,
  templates: [ProjectTemplate.empty, ProjectTemplate.${spec.template}],
  isOffline: true,
$runnerLine  // ${spec.entryFileNames.first} 排在默认入口表前面，保证本版一定先命中它。
  entryFileNames: [${spec.entryList}],
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 在 runApp 之前定档。
  StudioProfile.current = ${spec.id}Profile;

  final store = ProjectStore();
  final auth = AuthStore();
  final settings = SettingsStore();
  final ready = ValueNotifier<bool>(false);
  // 先 runApp 品牌启动页（与原生遮罩同色，无白屏），数据后台并行加载。
  runApp(QfliApp(store: store, auth: auth, settings: settings, ready: ready));
  // 首帧提交后再做磁盘/插件初始化，避免与首帧构建争用主 isolate。
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(
      AppBootstrap.run(
        store: store,
        auth: auth,
        settings: settings,
        ready: ready,
      ),
    );
  });
}
''';
}

/// 解释器还没落地时的后端。
String _pendingRunner(_Spec spec) {
  final exts = spec.sourceExtensions.map((e) => "'$e'").join(', ');
  return '''
import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:qfli_studio_core/services/studio_profile.dart';

/// ${spec.displayName} 版 App 的运行后端。
///
/// 目标形态是**应用内 ${spec.displayName} 子集解释器（纯 Dart）**。
/// 之所以是解释而不是编译：鸿蒙的普通应用被 SELinux 挡在 `exec` 之外，既调不动
/// 设备上的编译器，也拉不起打包进 HAP 的可执行文件（HNP 那条路要求应用具备
/// 生产力应用资格）。但沙箱从来不限制应用解释自己的数据，所以「自带解释器、
/// 在当前进程里跑自己的源码」是普通应用唯一走得通的路。
///
/// C 版的 `qfli_c_runtime` 已经把这条路走通并交付（词法 → 预处理 → 语法 →
/// 解释，约 7000 行纯 Dart），本版是同一个模式的接入点。
///
/// 解释器落地之前，[run] 明确返回「还不能运行」，而不是给一个看起来像结果的
/// 东西——那比报错更糟。
///
/// **接入方式**：把 [_notReady] 换成真实解释器的调用（返回一个带
/// stdout/stderr/exitCode 的 [ProgramRunResult]）。档位、入口识别、终端输出、
/// 退出码这些接线都不用动。
class ${spec.runnerClass} implements ProgramRunner {
  const ${spec.runnerClass}();

  /// 本后端接管的源码后缀。
  static const Set<String> _sourceExtensions = {$exts};

  @override
  Future<ProgramRunResult?> run({
    required String projectPath,
    required String entryFile,
  }) async {
    // 不是本语言的文件交回内核（返回 null），内核会走自己的分流逻辑。
    if (!_sourceExtensions.contains(p.extension(entryFile).toLowerCase())) {
      return null;
    }
    return _notReady(p.basename(entryFile));
  }

  /// 解释器还没接上时的占位结果。
  ProgramRunResult _notReady(String fileName) {
    final controller = StreamController<String>();
    scheduleMicrotask(() {
      controller
        ..add('${spec.displayName} 版的运行后端还在开发中（应用内纯 Dart 解释器）。')
        ..add('现在已经可用的：编辑器、语法高亮、项目模板、${spec.displayName} 入门教程。')
        ..add('内置 ${spec.displayName} 解释器完成后即可在本 App 内运行这段代码。')
        ..close();
    });
    return ProgramRunResult(
      title: '运行 \$fileName（${spec.displayName} 解释器开发中）',
      stdout: controller.stream,
      stderr: const Stream<String>.empty(),
      exitCode: Future<int>.value(kProgramNotRunExitCode),
    );
  }
}
''';
}

String _pendingRunnerTest(_Spec spec) {
  final entry = spec.entryFileNames.first;
  final ext = spec.sourceExtensions.first;
  final otherExt = spec.id == 'python' ? '.c' : '.py';
  final languages = _specs.map((s) => "'${s.displayName}'").join(', ');

  return '''
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:qfli_${spec.id}/main.dart' show ${spec.id}Profile;
import 'package:qfli_studio_core/services/project_templates.dart';
import 'package:qfli_studio_core/services/runner_service.dart';
import 'package:qfli_studio_core/services/studio_profile.dart';

/// ${spec.displayName} 版 App 的接线测试。
///
/// 覆盖的正是「一个语言一个 App」的全部接缝：内核怎么知道该显示哪个模板、
/// 该跑哪个入口文件、以及运行后端有没有正确接管/交回。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory project;
  late StudioProfile? previousProfile;

  setUp(() {
    previousProfile = StudioProfile.current;
    StudioProfile.current = ${spec.id}Profile;
    project = Directory.systemTemp.createTempSync('qfli_${spec.id}_app_test');
  });

  tearDown(() {
    StudioProfile.current = previousProfile;
    if (project.existsSync()) project.deleteSync(recursive: true);
  });

  void write(String relative, String content) {
    final file = File(p.join(project.path, relative));
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
  }

  group('档位收窄', () {
    test('新建项目只放行「空项目」和 ${spec.displayName}', () {
      expect(
        ${spec.id}Profile.filterTemplates(ProjectTemplate.values),
        [ProjectTemplate.empty, ProjectTemplate.${spec.template}],
      );
    });

    test('默认模板是 ${spec.displayName} 而不是空项目', () {
      expect(${spec.id}Profile.defaultTemplate,
          ProjectTemplate.${spec.template});
    });

    test('语言筛选芯片只剩 ${spec.displayName}', () {
      // 首页传给档位的候选本来就不含「空项目」——它不是一门语言。
      const all = [$languages];
      expect(${spec.id}Profile.filterLanguages(all), ['${spec.displayName}']);
    });

    test('产品名带 ${spec.displayName} 版后缀', () {
      expect(${spec.id}Profile.appTitle, '${spec.title}');
    });

    test('档位只使用本地能力', () {
      expect(${spec.id}Profile.isOffline, isTrue);
    });
  });

  group('入口文件识别', () {
    test('优先命中 $entry', () {
      write('$entry', '// $ext');
      write('other.txt', 'x');
      expect(
        RunnerService.findEntry(project.path),
        p.join(project.path, '$entry'),
      );
    });

    test('入口表覆盖了模板自带的入口文件', () {
      // 这是「一个语言一个 App」最容易出错的地方：模板统一把源码放在 src/ 下，
      // 而入口表要是只写了根目录的文件名，新建项目后点运行就会找不到入口。
      final mainFile = ProjectTemplate.${spec.template}.mainFile;
      expect(mainFile, isNotNull, reason: '模板里没有文件');
      expect(${spec.id}Profile.entryFileNames, contains(mainFile));
    });

    test('模板把源码放在 src/ 下时也能找到入口', () {
      final mainFile = ProjectTemplate.${spec.template}.mainFile!;
      write(mainFile, '// 示例');
      expect(
        RunnerService.findEntry(project.path),
        p.join(project.path, mainFile),
      );
    });
  });

  group('运行后端', () {
    test('本语言文件被接管，并说明解释器还在开发中', () async {
      write('$entry', '// 示例');
      final result = await ${spec.id}Profile.runner!.run(
        projectPath: project.path,
        entryFile: p.join(project.path, '$entry'),
      );
      expect(result, isNotNull, reason: '运行后端没有接管本语言文件');
      expect(result!.title, contains('${spec.displayName} 解释器开发中'));
      expect(await result.stdout.toList(), isNotEmpty);
      expect(await result.exitCode, kProgramNotRunExitCode);
    });

    test('别的语言文件交回内核', () async {
      write('main$otherExt', 'x');
      final result = await ${spec.id}Profile.runner!.run(
        projectPath: project.path,
        entryFile: p.join(project.path, 'main$otherExt'),
      );
      expect(result, isNull);
    });
  });

  group('运行按钮分流', () {
    test('点运行拿到结果，而不是掉进「移动端跑不了」的兜底提示', () async {
      write('$entry', '// 示例');
      final result = await RunnerService.runProject(
        projectPath: project.path,
        entryFile: p.join(project.path, '$entry'),
      );
      expect(result, isNotNull);
      expect(result!.hint, isNull, reason: '后端接管了就不该走兜底提示');
      expect(result.title, contains('${spec.displayName} 解释器开发中'));
    });
  });
}
''';
}

String _webTest(_Spec spec) {
  return '''
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:qfli_web/main.dart' show webProfile;
import 'package:qfli_studio_core/services/project_templates.dart';
import 'package:qfli_studio_core/services/runner_service.dart';
import 'package:qfli_studio_core/services/studio_profile.dart';

/// Web 版 App 的接线测试。
///
/// Web 版是五个语言里唯一「不用自带解释器就能跑」的：内核的 RunnerService 会用
/// LocalWebServer 起一个本地静态服务器，把项目目录当网站serve出去，并往页面里
/// 注入调试桥（劫持 console.log / window.onerror 回传）。所以这里的重点不是
/// 「后端接管」，而是「内核那条路真的通」——起服务器、拿到 URL、页面里能看到
/// 项目内容、调试桥被注入了。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory project;
  late StudioProfile? previousProfile;

  setUp(() {
    previousProfile = StudioProfile.current;
    StudioProfile.current = webProfile;
    project = Directory.systemTemp.createTempSync('qfli_web_app_test');
  });

  tearDown(() {
    StudioProfile.current = previousProfile;
    if (project.existsSync()) project.deleteSync(recursive: true);
  });

  void write(String relative, String content) {
    final file = File(p.join(project.path, relative));
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
  }

  group('档位收窄', () {
    test('新建项目只放行「空项目」和 Web', () {
      expect(
        webProfile.filterTemplates(ProjectTemplate.values),
        [ProjectTemplate.empty, ProjectTemplate.${spec.template}],
      );
    });

    test('默认模板是 Web', () {
      expect(webProfile.defaultTemplate, ProjectTemplate.${spec.template});
    });

    test('语言筛选芯片只剩 Web', () {
      const all = ['C', 'Python', 'Java', 'Web', 'Dart'];
      expect(webProfile.filterLanguages(all), ['Web']);
    });

    test('不注入运行后端，交给内核的静态服务器', () {
      expect(webProfile.runner, isNull);
    });

    test('产品名带 Web 版后缀', () {
      expect(webProfile.appTitle, '${spec.title}');
    });
  });

  group('入口文件识别', () {
    test('优先命中 index.html', () {
      write('index.html', '<html></html>');
      write('src/index.html', '<html></html>');
      expect(
        RunnerService.findEntry(project.path),
        p.join(project.path, 'index.html'),
      );
    });

    test('index.html 在 src/ 下也能找到', () {
      write('src/index.html', '<html></html>');
      expect(
        RunnerService.findEntry(project.path),
        p.join(project.path, 'src/index.html'),
      );
    });

    test('入口表覆盖了模板自带的入口文件', () {
      // 模板统一把源码放在 src/ 下，入口表必须包含它，否则新建项目后点运行
      // 会找不到入口。
      final mainFile = ProjectTemplate.html.mainFile;
      expect(mainFile, isNotNull, reason: '模板里没有文件');
      expect(webProfile.entryFileNames, contains(mainFile));
    });
  });

  group('运行按钮', () {
    test('起本地服务器并返回可访问的 URL', () async {
      write('index.html', '<html><body><h1>你好</h1></body></html>');
      final result = await RunnerService.runProject(
        projectPath: project.path,
        entryFile: p.join(project.path, 'index.html'),
      );
      expect(result, isNotNull);
      expect(result!.webServer, isNotNull, reason: '没有起静态服务器');
      expect(result.hint, isNull);
      expect(result.title, startsWith('http://127.0.0.1:'));

      final server = result.webServer!;
      addTearDown(server.stop);
      // 服务器必须真的在服务这个项目目录，而不是只返回了一个字符串。
      final body = await _get(server.url);
      expect(body, contains('你好'));
    });

    test('页面里被注入了调试桥，console.log 能回传', () async {
      write('index.html', '<html><body>hi</body></html>');
      final result = await RunnerService.runProject(
        projectPath: project.path,
        entryFile: p.join(project.path, 'index.html'),
      );
      final server = result!.webServer!;
      addTearDown(server.stop);

      final body = await _get(server.url);
      expect(body, contains('/__debug'), reason: '页面里没有调试桥');
    });

    test('子目录资源按路径取得到', () async {
      write('index.html', '<html><body>root</body></html>');
      write('css/site.css', 'body { color: red; }');
      final result = await RunnerService.runProject(
        projectPath: project.path,
        entryFile: p.join(project.path, 'index.html'),
      );
      final server = result!.webServer!;
      addTearDown(server.stop);

      final base = server.url.substring(0, server.url.lastIndexOf('/') + 1);
      expect(await _get('\${base}css/site.css'), contains('color: red'));
    });
  });
}

/// 直接取一次 HTTP 响应体。
///
/// 两个坑：
/// - flutter_test 会装一个 HttpOverrides，把所有请求拦成空响应（免得用例误连
///   外网）。这里要连的是**本进程刚起的**预览服务器，所以必须临时把 overrides
///   摘掉，否则拿到的永远是空 body。
/// - 解码要用 utf8：SystemEncoding 在 Windows 上是 ANSI 代码页，会把页面里的
///   中文解成乱码。
Future<String> _get(String url) async {
  final saved = HttpOverrides.current;
  HttpOverrides.global = null;
  final client = HttpClient();
  try {
    final request = await client.getUrl(Uri.parse(url));
    final response = await request.close();
    return await response.transform(utf8.decoder).join();
  } finally {
    client.close();
    HttpOverrides.global = saved;
  }
}
''';
}

/// 从工作目录往上找到主 App 仓库。
String _findRepoRoot() {
  var dir = Directory.current;
  for (var i = 0; i < 6; i++) {
    final pubspec = File(p.join(dir.path, 'pubspec.yaml'));
    if (pubspec.existsSync() &&
        RegExp(r'^name:\s*qflistudio\s*$', multiLine: true)
            .hasMatch(pubspec.readAsStringSync())) {
      return dir.path;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  throw StateError('没找到 qflistudio 主 App 仓库');
}
