import 'project_templates.dart';

/// 产品线名称登记表。语言 App 的 UI 标题从这里取，后续新增产品时不必散落硬编码。
abstract final class StudioProductCatalog {
  static const qfliStudioKey = 'qflistudio';
  static const scriptKey = 'script';
  static const rustCoreKey = 'rustcore';
  static const goShiftKey = 'goshift';
  static const jvmxKey = 'jvmx';
  static const webForgeKey = 'webforge';
  static const pyFlowKey = 'pyflow';
  static const forgeKey = 'forge';
  static const dartWingKey = 'dartwing';
  static const sqlabKey = 'sqlab';
  static const jsonKey = 'json';
  static const noteKey = 'note';

  static const qfliStudio = 'QFLIStudio+';
  static const qfliStudioDescription = '多语言编辑器（暂定）';
  static const script = 'QFLIScript';
  static const rustCore = 'QFLIRustCore';
  static const goShift = 'QFLIGoShift';
  static const jvmx = 'QFLIJVMX';
  static const webForge = 'QFLIWebForge';
  static const pyFlow = 'QFLIPyFlow';
  static const forge = 'QFLIForge';
  static const dartWing = 'QFLIDartWing';
  static const sqlab = 'QFLISQLab';
  static const json = 'QFLIJson';
  static const note = 'QFLINote';

  /// The only installable products. Keep this list as the product identity source.
  static const products = <String, String>{
    qfliStudioKey: qfliStudio,
    scriptKey: script,
    rustCoreKey: rustCore,
    goShiftKey: goShift,
    jvmxKey: jvmx,
    webForgeKey: webForge,
    pyFlowKey: pyFlow,
    forgeKey: forge,
    dartWingKey: dartWing,
    sqlabKey: sqlab,
    jsonKey: json,
    noteKey: note,
  };

  static const packagePrefix = 'com.azurekiln.qfli';

  static String packageName(String key) => '$packagePrefix.$key';

  /// Product name by source language/type. This is also used for tutorial labels.
  static const languageProducts = <String, String>{
    'lua': script,
    'javascript': script,
    'typescript': script,
    'shell': script,
    'java': jvmx,
    'web': webForge,
    'python': pyFlow,
    'c': forge,
    'cpp': forge,
    'rust': rustCore,
    'go': goShift,
    'dart': dartWing,
    'sql': sqlab,
    'json': json,
    'markdown': note,
  };

  static String forLanguage(String language) =>
      languageProducts[language.toLowerCase()] ?? qfliStudio;
}

/// 语言专属 App 的「档位」。
///
/// 共享内核默认是全能版（所有模板 + 桌面端原生工具链）。各语言 App 在
/// `main()` 里设置一次 [current]，即可把同一套 UI 收窄成该语言的专用产品：
/// 新建项目只出现本语言的模板，运行按钮交给该语言自己的本地运行时。
///
/// 之所以用可变的静态字段而不是 InheritedWidget：档位在 `runApp` 之前就确定，
/// 全程不变，且要在 `ProjectStore` / `RunnerService` 这类非 Widget 代码里读取。
class StudioProfile {
  const StudioProfile({
    required this.id,
    required this.appTitle,
    required this.templates,
    this.runner,
    this.entryFileNames = const [],
    this.isOffline = false,
    this.productKey = StudioProductCatalog.qfliStudioKey,
    this.showHomeTabs = true,
  });

  /// 档位标识，同时用于项目元数据里记录「由哪个 App 创建」。
  final String id;

  /// 产品名：窗口标题、任务切换器和应用内顶栏都用它，
  /// 例如联网全能版 `QFLIStudio+`、C/C++ 工具 `QFLIForge`。
  final String appTitle;

  /// Stable product key used by platform identifiers and exported metadata.
  final String productKey;

  /// 新建项目时可选的模板。空列表表示不限制。
  final List<ProjectTemplate> templates;

  /// 本地运行后端。null 表示沿用 [RunnerService] 的默认行为。
  final ProgramRunner? runner;

  /// 额外识别的入口文件名（优先于默认列表），例如 `'main.c'`。
  final List<String> entryFileNames;

  /// 是否为不接入社区、认证、云端项目和在线终端的本地语言 App。
  ///
  /// 根工程不设置档位，因此保持联网全能版；各语言 App 显式设置为 true。
  final bool isOffline;

  /// Whether homepage project-scope and language tabs are shown.
  final bool showHomeTabs;

  /// 当前生效的档位。为 null 时即全能版。
  static StudioProfile? current;

  /// 该模板在本档位下是否可选。
  bool allowsTemplate(ProjectTemplate template) =>
      templates.isEmpty || templates.contains(template);

  /// 新建对话框的默认模板：档位里第一个真实语言模板。
  ProjectTemplate get defaultTemplate => templates.firstWhere(
    (t) => t != ProjectTemplate.empty,
    orElse: () => ProjectTemplate.empty,
  );

  /// 按档位过滤模板列表。
  List<ProjectTemplate> filterTemplates(Iterable<ProjectTemplate> source) =>
      source.where(allowsTemplate).toList(growable: false);

  /// 按档位过滤语言标签（首页语言筛选芯片）。
  List<String> filterLanguages(Iterable<String> source) {
    if (templates.isEmpty) return source.toList(growable: false);
    final allowed = templates.map((t) => t.language).toSet();
    return source.where(allowed.contains).toList(growable: false);
  }
}

/// 当前档位下可选的模板。未设置档位时即全部模板。
List<ProjectTemplate> availableTemplates() =>
    StudioProfile.current?.filterTemplates(ProjectTemplate.values) ??
    ProjectTemplate.values;

/// 当前档位新建对话框的默认模板。
ProjectTemplate defaultTemplate() =>
    StudioProfile.current?.defaultTemplate ?? ProjectTemplate.empty;

/// 语言 App 提供的本地运行后端。
///
/// 实现方只需负责「把源码跑起来并吐出输出行」，终端面板的呈现交给内核。
abstract interface class ProgramRunner {
  /// 运行 [entryFile]。返回 null 表示本后端不接管这种文件，交回默认逻辑。
  Future<ProgramRunResult?> run({
    required String projectPath,
    required String entryFile,
  });
}

/// 「程序根本没跑起来」时应该用的退出码。
///
/// 终端面板会把非 0 一律渲染成「（运行结束，退出码 N）」
/// （见 `lib/editor/terminal_pane.dart`）。所以只要后端没起来，就**不能**回 1：
/// 「运行结束，退出码 1」读起来是「程序自己跑完、报错退出 1」，而真相是
/// 程序一行都没执行。真机上真实误导过人一次（Python 版后端没打进 HAP 时）。
///
/// 借 shell 的约定 127 = command not found。任何正常程序都不会主动返回它，
/// 于是终端上的两句话一眼就能分开：
///   - 退出码 127 → 是 App / 后端的问题，程序没跑；
///   - 其它退出码 → 程序真的跑了，这是它自己的退出码。
///
/// 所有语言 App 的「后端不可用 / 运行前失败」分支都必须用它。
const int kProgramNotRunExitCode = 127;

/// 一次本地运行的输出。stdout / stderr 均为按行切分的字符串流。
class ProgramRunResult {
  const ProgramRunResult({
    required this.title,
    required this.stdout,
    required this.stderr,
    required this.exitCode,
    this.cancel,
  });

  /// 终端首行显示的标题，例如 `运行 main.c（本地解释器）`。
  final String title;

  final Stream<String> stdout;
  final Stream<String> stderr;
  final Future<int> exitCode;

  /// Cancels an external or native run when the editor is disposed.
  final Future<void> Function()? cancel;
}
