/// 入门教程的数据模型。
///
/// 教程以 JSON 形式随包分发（`assets/tutorials/<language>.json`），由
/// `TutorialService` 解析成这里的模型，再交给 UI 渲染。
///
/// 设计约定：
/// - 只解析「结构」，不校验教学内容的正确性；缺字段一律给空值而不是抛异常，
///   避免某个语言写错一个字段就让整本教程打不开。
/// - 解析阶段真正致命的只有「不是合法 JSON」和「不是 JSON 对象」。
library;

/// 单个语言的一整本教程。
class Tutorial {
  const Tutorial({
    required this.language,
    required this.type,
    required this.displayName,
    required this.schemaVersion,
    required this.updatedAt,
    required this.runtime,
    required this.chapters,
    required this.examples,
  });

  /// 语言标识，与 [StudioProfile.id] 同域，例如 `c` / `python`。
  final String language;

  /// Stable language/type discriminator used by filters and import actions.
  final String type;

  /// 展示名，例如 `C` / `Python`。
  final String displayName;

  /// 教程 JSON 的结构版本，用于将来做兼容迁移。
  final int schemaVersion;

  /// 内容更新日期（`YYYY-MM-DD`）。
  final String updatedAt;

  /// 该语言在设备上的运行能力说明。
  final TutorialRuntime runtime;

  final List<TutorialChapter> chapters;

  /// Explicit examples when supplied by JSON, otherwise lesson projections.
  final List<ExampleCode> examples;

  /// 全部课时数。
  int get lessonCount =>
      chapters.fold(0, (sum, chapter) => sum + chapter.lessons.length);

  /// 按顺序摊平的全部课时，便于「下一课」之类的线性导航。
  List<TutorialLesson> get allLessons =>
      [for (final chapter in chapters) ...chapter.lessons];

  /// 该语言当前是否已经能在设备上直接运行。
  bool get isRunnable => runtime.isAvailable;
}

/// 教程头部声明的运行能力。
///
/// 这本教程面向「鸿蒙普通应用」场景：系统不允许执行任意 ELF，所以能否运行
/// 取决于应用内是否自带解释器/服务器，[engine] 就是写给用户看的说明。
class TutorialRuntime {
  const TutorialRuntime({
    required this.kind,
    required this.status,
    required this.engine,
    this.stdin,
    this.stdout,
    this.limits,
    this.note,
  });

  /// 运行方式：`interpreter`（应用内解释器）/ `static-server`（本地静态服务器）等。
  final String kind;

  /// `available` 表示现在就能跑；`planned` 表示解释器仍在开发中。
  final String status;

  /// 引擎说明，直接展示给用户。
  final String engine;

  /// 标准输入怎么给（解释器类语言）。
  final String? stdin;

  /// 标准输出怎么呈现（静态服务器类语言）。
  final String? stdout;

  /// 运行限制说明。
  final String? limits;

  /// 其他补充说明。
  final String? note;

  /// 是否已可用。
  bool get isAvailable => status == 'available';
}

/// 一章（一个主题分组）。
class TutorialChapter {
  const TutorialChapter({
    required this.id,
    required this.title,
    required this.lessons,
  });

  final String id;
  final String title;
  final List<TutorialLesson> lessons;
}

/// 一课。
class TutorialLesson {
  const TutorialLesson({
    required this.id,
    required this.type,
    required this.title,
    required this.summary,
    required this.concepts,
    required this.explain,
    required this.code,
    required this.output,
    required this.tasks,
  });

  final String id;
  final String type;
  final String title;

  /// 一句话说明这一课要解决什么问题。
  final String summary;

  /// 涉及的知识点标签。
  final List<String> concepts;

  /// 正文讲解。
  final String explain;

  /// 可直接运行/粘贴的示例代码。
  final String code;

  /// 预期输出（含浏览器/调试面板里会看到什么）。
  final String output;

  /// 练习题。
  final List<TutorialTask> tasks;
}

/// A first-class example entry. It is intentionally separate from lessons so
/// editable example catalogs can evolve without changing tutorial chapters.
class ExampleCode {
  const ExampleCode({
    required this.id,
    required this.type,
    required this.title,
    required this.summary,
    required this.code,
    required this.output,
    this.sourceLessonId,
  });

  final String id;
  final String type;
  final String title;
  final String summary;
  final String code;
  final String output;
  final String? sourceLessonId;

  ExampleCode copyWith({String? code, String? summary}) => ExampleCode(
    id: id,
    type: type,
    title: title,
    summary: summary ?? this.summary,
    code: code ?? this.code,
    output: output,
    sourceLessonId: sourceLessonId,
  );
}

/// 一课里的一道练习题。
class TutorialTask {
  const TutorialTask({
    required this.prompt,
    required this.hint,
    required this.answer,
  });

  /// 题目要求。
  final String prompt;

  /// 提示。
  final String hint;

  /// 参考答案。
  final String answer;
}

/// 教程 JSON 结构不合法时抛出。
class TutorialFormatException implements Exception {
  const TutorialFormatException(this.language, this.message);

  final String language;
  final String message;

  @override
  String toString() => '教程 $language 解析失败：$message';
}
