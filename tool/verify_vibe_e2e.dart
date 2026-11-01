// Vibe Coding 验收的运维入口。
//
// 只做三件事：准备环境变量、调度驱动、把报告读成表格。
// 脚本本身不构造 HTTP 请求，也不保存任何凭据。
//
// 用法（在 qflistudio 目录）：
//   dart run tool/verify_vibe_e2e.dart                      # 全场景
//   dart run tool/verify_vibe_e2e.dart --scenario web_search
//   dart run tool/verify_vibe_e2e.dart --env-file <路径>     # 仅在本次子进程生效
//   dart run tool/verify_vibe_e2e.dart --report <报告路径>   # 只读已有报告
//   dart run tool/verify_vibe_e2e.dart --dry-run            # 只查环境与工具链
//
// 退出码：0 通过或跳过，1 有失败场景，2 用法或环境错误。
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// 驱动脚本相对本仓库的位置。
const String _driverRelative = '../qfli_studio_core/tool/vibe_e2e.dart';

/// 首次运行前必须导出的三个变量名，不含值。
const List<String> _requiredVariables = [
  'QFLI_DEBUG_BASE_URL',
  'QFLI_DEBUG_API_KEY',
  'QFLI_DEBUG_MODEL',
];

Future<void> main(List<String> args) async {
  final options = _Options.parse(args);
  if (options.help) {
    stdout.writeln(_usage);
    return;
  }

  if (options.report != null) {
    final status = _printReport(File(options.report!));
    if (status != null) exitCode = status;
    return;
  }

  final repoRoot = _repositoryRoot();
  final coreRoot = p.normalize(p.join(repoRoot, '..', 'qfli_studio_core'));
  final driver = File(p.normalize(p.join(repoRoot, _driverRelative)));

  final checks = _environmentChecks(
    repoRoot: repoRoot,
    coreRoot: coreRoot,
    driver: driver,
    envFile: options.envFile,
  );
  _printChecks(checks);
  if (options.dryRun) {
    stdout.writeln(
      checks.every((check) => check.ok) ? '结论: 环境就绪' : '结论: 环境未就绪',
    );
    return;
  }
  if (!driver.existsSync()) {
    stderr.writeln('找不到驱动 ${driver.path}');
    exitCode = 2;
    return;
  }

  final environment = Map<String, String>.from(Platform.environment);
  if (options.envFile != null) {
    final parsed = _readEnvFile(File(options.envFile!));
    if (parsed.isEmpty) {
      stderr.writeln('--env-file 没有解析出任何变量：${options.envFile}');
    }
    environment.addAll(parsed);
  }
  final missing = [
    for (final name in _requiredVariables)
      if ((environment[name] ?? '').trim().isEmpty) name,
  ];
  if (missing.isNotEmpty) {
    stdout.writeln('缺少变量 ${missing.join('、')}，驱动会全部跳过。');
  }

  final liveArgs = <String>[
    'test',
    '--no-pub',
    '--concurrency=1',
    'test/vibe_live_e2e_test.dart',
  ];
  stdout.writeln(
    '运行 flutter test ${p.join(coreRoot, 'test', 'vibe_live_e2e_test.dart')}',
  );
  final hint = scenarioHint(options.scenario);
  if (hint.isNotEmpty) stdout.writeln(hint);
  final flutter = Platform.isWindows ? 'flutter.bat' : 'flutter';
  final Process child;
  try {
    child = await Process.start(
      flutter,
      liveArgs,
      workingDirectory: coreRoot,
      environment: environment,
      runInShell: Platform.isWindows,
    );
  } on ProcessException catch (error) {
    stderr.writeln('无法启动 flutter：${error.message}');
    exitCode = 2;
    return;
  }
  // 原样转发驱动的输出；驱动从不打印凭据，因此这里不会泄漏。
  await Future.wait([child.stdout.pipe(stdout), child.stderr.pipe(stderr)]);
  final code = await child.exitCode;
  if (code != 0) exitCode = code;
}

/// 提示一处限制：实时宿主一次性跑完三个场景，单独跑一个场景请直接用
/// `flutter test --no-pub --plain-name`。
String scenarioHint(String? scenario) => scenario == null
    ? ''
    : '\n提示：--scenario 在实时宿主下忽略；单独跑场景请用\n'
          '  (cd ../qfli_studio_core && flutter test --no-pub --plain-name "<场景>")\n';

class _Check {
  const _Check(this.name, this.ok, this.detail);

  final String name;
  final bool ok;
  final String detail;
}

List<_Check> _environmentChecks({
  required String repoRoot,
  required String coreRoot,
  required File driver,
  required String? envFile,
}) {
  final checks = <_Check>[];
  checks.add(_Check('仓库根', true, repoRoot));
  checks.add(_Check('共享内核', Directory(coreRoot).existsSync(), coreRoot));
  checks.add(_Check('驱动脚本', driver.existsSync(), driver.path));

  final sdk = Process.runSync('dart', ['--version'], runInShell: false);
  checks.add(
    _Check(
      'Dart SDK',
      sdk.exitCode == 0,
      sdk.exitCode == 0
          ? (sdk.stdout as String).trim().split('\n').last.trim()
          : '找不到 dart',
    ),
  );
  checks.add(
    _Check(
      'Flutter SDK',
      true,
      '驱动依赖 qfli_studio_core，其中含 flutter 依赖。'
          '纯 dart run 无法加载 dart:ui，实跑需要 flutter test 或 SDK 侧适配。',
    ),
  );

  final base = (Platform.environment['QFLI_DEBUG_BASE_URL'] ?? '').trim();
  checks.add(_Check('调试上游主机', true, base.isEmpty ? '未设置' : _hostOf(base)));
  for (final name in _requiredVariables.skip(1)) {
    final present = (Platform.environment[name] ?? '').trim().isNotEmpty;
    checks.add(
      _Check(
        name,
        true,
        present
            ? '已设置（长度 ${Platform.environment[name]!.trim().length}）'
            : '未设置',
      ),
    );
  }
  if (envFile != null) {
    checks.add(_Check('凭据文件', File(envFile).existsSync(), envFile));
  }
  return checks;
}

void _printChecks(List<_Check> checks) {
  for (final check in checks) {
    stdout.writeln(
      '${check.ok ? 'ok  ' : 'fail'}  ${check.name}: ${check.detail}',
    );
  }
}

String _hostOf(String baseUrl) => Uri.tryParse(baseUrl)?.host ?? '无法解析为 URL';

/// 解析 `KEY=VALUE` 行；不写回 shell，不落盘。
Map<String, String> _readEnvFile(File file) {
  final result = <String, String>{};
  if (!file.existsSync()) return result;
  for (final raw in file.readAsLinesSync()) {
    var line = raw.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    if (line.startsWith('export ')) line = line.substring(7).trim();
    final index = line.indexOf('=');
    if (index <= 0) continue;
    final key = line.substring(0, index).trim();
    var value = line.substring(index + 1).trim();
    if (value.length >= 2 &&
        ((value.startsWith('"') && value.endsWith('"')) ||
            (value.startsWith("'") && value.endsWith("'")))) {
      value = value.substring(1, value.length - 1);
    }
    if (key.isEmpty) continue;
    result[key] = value;
  }
  return result;
}

/// 报告顶层状态；有失败场景时必须是 failed，不能被 skipped 掩盖。
String _topLevelStatus(Object? declared, List<Object?> scenarios) {
  var failed = false;
  var passed = false;
  var seen = false;
  for (final scenario in scenarios) {
    if (scenario is! Map) continue;
    seen = true;
    switch (scenario['status']) {
      case 'failed':
        failed = true;
      case 'passed':
        passed = true;
    }
  }
  if (failed) return 'failed';
  if (declared is String && declared.isNotEmpty && !passed) return declared;
  return seen && !passed ? 'skipped' : 'passed';
}

/// 打印已有报告；返回需要设置的退出码，报告不可读时返回 2。
int? _printReport(File file) {
  if (!file.existsSync()) {
    stderr.writeln('报告不存在：${file.path}');
    return 2;
  }
  final Object? decoded;
  try {
    decoded = jsonDecode(file.readAsStringSync());
  } on FormatException catch (error) {
    stderr.writeln('报告不是有效 JSON：${error.message}');
    return 2;
  }
  if (decoded is! Map<String, Object?>) {
    stderr.writeln('报告顶层必须是对象');
    return 2;
  }
  final environment = decoded['environment'];
  if (environment is Map) {
    stdout.writeln(
      '环境: ${environment['baseHost'] ?? '未知主机'} · '
      '${environment['model'] ?? '未知模型'} · '
      '${environment['protocol'] ?? 'backend_default'} · '
      'key ${environment['keyPresent'] == true ? '已设置' : '未设置'}',
    );
  }
  final scenarios = decoded['scenarios'];
  if (scenarios is List) {
    for (final scenario in scenarios) {
      if (scenario is! Map) continue;
      stdout.writeln(
        '${_pad('${scenario['key']}', 18)}'
        '${_pad('${scenario['status']}', 9)}'
        '${_pad('${scenario['phase']}', 11)}'
        '${scenario['durationMs'] ?? 0}ms',
      );
      final skipReason = scenario['skipReason'];
      if (skipReason != null) stdout.writeln('  跳过：$skipReason');
      final lastError = scenario['lastError'];
      if (lastError != null) stdout.writeln('  错误：$lastError');
      final assertions = scenario['assertions'];
      if (assertions is List) {
        for (final assertion in assertions) {
          if (assertion is! Map) continue;
          final mark = assertion['ok'] == true ? 'ok  ' : 'fail';
          stdout.writeln(
            '  $mark ${assertion['name']}'
            '${assertion['detail'] == null ? '' : ' — ${assertion['detail']}'}',
          );
        }
      }
      final tools = scenario['tools'];
      if (tools is List) {
        for (final tool in tools) {
          if (tool is! Map) continue;
          final exitCode = tool['exitCode'];
          stdout.writeln(
            '    · ${tool['name']} ${tool['status']}'
            '${exitCode == null ? '' : ' exit=$exitCode'}'
            '${tool['summary'] == null ? '' : ' ${tool['summary']}'}',
          );
        }
      }
    }
  }
  final status = _topLevelStatus(
    decoded['status'],
    scenarios is List ? scenarios : const [],
  );
  stdout.writeln('结论: $status');
  return status == 'failed' ? 1 : 0;
}

String _pad(String value, int width) =>
    value.length >= width ? '$value ' : value.padRight(width);

String _repositoryRoot() {
  final resolved = File.fromUri(Platform.script).parent.parent;
  return resolved.path;
}

class _Options {
  const _Options({
    this.scenario,
    this.out,
    this.envFile,
    this.report,
    this.transport,
    this.protocol,
    this.searchTools = false,
    this.dryRun = false,
    this.help = false,
  });

  final String? scenario;
  final String? out;
  final String? envFile;
  final String? report;
  final String? transport;
  final String? protocol;
  final bool searchTools;
  final bool dryRun;
  final bool help;

  static _Options parse(List<String> args) {
    String? scenario;
    String? out;
    String? envFile;
    String? report;
    String? transport;
    String? protocol;
    var searchTools = false;
    var dryRun = false;
    var help = false;
    for (var i = 0; i < args.length; i++) {
      String? next() => i + 1 < args.length ? args[++i] : null;
      switch (args[i]) {
        case '--scenario':
          scenario = next();
        case '--out':
          out = next();
        case '--env-file':
          envFile = next();
        case '--report':
          report = next();
        case '--transport':
          transport = next();
        case '--protocol':
          protocol = next();
        case '--search-tools':
          searchTools = true;
        case '--dry-run':
          dryRun = true;
        case '--help':
        case '-h':
          help = true;
        default:
          stderr.writeln('忽略未知参数 ${args[i]}');
      }
    }
    return _Options(
      scenario: scenario,
      out: out,
      envFile: envFile,
      report: report,
      transport: transport,
      protocol: protocol,
      searchTools: searchTools,
      dryRun: dryRun,
      help: help,
    );
  }
}

const String _usage =
    'dart run tool/verify_vibe_e2e.dart [选项]\n\n'
    '  --env-file <路径>   从文件读取 QFLI_DEBUG_*，只作用于本次子进程\n'
    '  --report <路径>     只读已有报告，不跑驱动\n'
    '  --dry-run           只检查环境\n\n'
    '实时场景在 qfli_studio_core 里用 flutter test 宿主运行：\n'
    '  flutter test --no-pub test/vibe_live_e2e_test.dart\n\n'
    '凭据永不打印。缺少变量时全部场景跳过，退出码 0。';
