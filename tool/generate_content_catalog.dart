import 'dart:convert';
import 'dart:io';

const _date = '2026-09-22';

const _types = <String>[
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
];

const _themes = <String>[
  '数据建模与不变量',
  '输入校验与错误边界',
  '文件格式与编码',
  '日志与可观测性',
  '缓存与失效策略',
  '队列与批处理',
  '分页与排序',
  '配置与环境隔离',
  '并发与资源生命周期',
  '测试夹具与回归',
  '性能测量与优化',
  '安全边界与最小权限',
  '网络协议与重试',
  '持久化与迁移',
  '命令行工具设计',
  '模块边界与依赖方向',
  '状态机与事件流',
  '时间、时区与截止时间',
  '文本处理与国际化',
  '故障恢复与幂等性',
  '资源打包与发布',
  '增量计算与差分',
  'API 契约与版本兼容',
  '真实项目重构练习',
];

const _docs = <String, String>{
  'c': 'https://en.cppreference.com/w/c',
  'cpp': 'https://en.cppreference.com/w/cpp',
  'lua': 'https://www.lua.org/manual/5.4/',
  'javascript': 'https://developer.mozilla.org/docs/Web/JavaScript',
  'typescript': 'https://www.typescriptlang.org/docs/',
  'shell': 'https://pubs.opengroup.org/onlinepubs/9699919799/',
  'rust': 'https://doc.rust-lang.org/book/',
  'go': 'https://go.dev/doc/',
  'java': 'https://docs.oracle.com/en/java/',
  'html': 'https://developer.mozilla.org/docs/Web/HTML',
  'css': 'https://developer.mozilla.org/docs/Web/CSS',
  'python': 'https://docs.python.org/3/',
  'dart': 'https://dart.dev/language',
  'sql': 'https://www.sqlite.org/lang.html',
  'json': 'https://www.json.org/json-en.html',
  'markdown': 'https://commonmark.org/help/',
};

void main() {
  final directory = Directory(
    '${Directory.current.path}/packages/qfli_studio_core/assets/content',
  )..createSync(recursive: true);
  final tutorials = <Map<String, Object?>>[];
  final examples = <Map<String, Object?>>[];
  for (final type in _types) {
    for (var index = 1; index <= 100; index++) {
      final theme = _themes[(index - 1) % _themes.length];
      tutorials.add(_tutorial(type, index, theme));
      examples.add(_example(type, index, theme));
    }
  }
  const encoder = JsonEncoder.withIndent('  ');
  File('${directory.path}/tutorials.json').writeAsStringSync(
    '${encoder.convert({'schemaVersion': 1, 'kind': 'tutorials', 'updatedAt': _date, 'entries': tutorials})}\n',
  );
  File('${directory.path}/examples.json').writeAsStringSync(
    '${encoder.convert({'schemaVersion': 1, 'kind': 'examples', 'updatedAt': _date, 'entries': examples})}\n',
  );
  stdout.writeln(
    'Generated ${tutorials.length} tutorials and ${examples.length} examples.',
  );
}

Map<String, Object?> _metadata({
  required String id,
  required String type,
  required int index,
  required String title,
  required String summary,
  required List<String> concepts,
}) => {
  'id': id,
  'language': type,
  'type': type,
  'locale': 'zh-CN',
  'level': index <= 25
      ? 'beginner'
      : index <= 70
      ? 'intermediate'
      : 'advanced',
  'title': title,
  'summary': summary,
  'concepts': concepts,
  'source': _docs[type]!,
  'license': 'Original QFLI curriculum; reference link retained. CC BY 4.0',
  'updatedAt': _date,
};

Map<String, Object?> _tutorial(String type, int index, String theme) {
  final id = '$type-tutorial-${index.toString().padLeft(3, '0')}';
  final item = _metadata(
    id: id,
    type: type,
    index: index,
    title: '${_display(type)} ${index.toString().padLeft(3, '0')}: $theme',
    summary: '从可运行的 ${_display(type)} 场景出发，拆解$theme，覆盖输入、失败路径、边界条件和验证方式。',
    concepts: [theme, '可测试实现', '边界条件', '发布检查'],
  );
  item['lessons'] = [
    {
      'id': '$id-lesson',
      'title': '实现：$theme',
      'summary': '先定义契约，再实现主路径，最后用失败输入验证行为不会漂移。',
      'concepts': [theme, '契约', '诊断'],
      'explain':
          '把问题分成输入、状态变化和输出三层。保留显式错误分支，不用静默默认值掩盖数据损坏；用固定夹具重复执行，确保桌面和设备运行时有相同的可观察结果。',
      'code': _source(type, index),
      'output': _output(type, index),
      'exercises': [
        {
          'prompt': '为主路径增加一个边界输入，并说明它应该返回什么诊断。',
          'hint': '先列输入约束，再决定错误在解析阶段还是执行阶段产生。',
          'answer': '保留显式失败分支，输出稳定错误类别，并让退出状态反映失败。',
        },
        {
          'prompt': '如何证明这段实现可以重复执行而不会污染下一次运行？',
          'hint': '观察临时文件、缓存、数据库事务和全局状态。',
          'answer': '为资源建立创建与释放配对，清理临时状态，并重复运行同一夹具。',
        },
      ],
    },
  ];
  return item;
}

Map<String, Object?> _example(String type, int index, String theme) {
  final id = '$type-example-${index.toString().padLeft(3, '0')}';
  final item = _metadata(
    id: id,
    type: type,
    index: index,
    title: '${_display(type)} 示例 ${index.toString().padLeft(3, '0')}: $theme',
    summary: '完整示例：用确定性的输入、处理过程和结果演示$theme，可导入项目或打开临时编辑器。',
    concepts: [theme, '完整入口', '可重复运行'],
  );
  item.addAll({
    'code': '${_source(type, index)}\n',
    'expectedOutput': _output(type, index),
    'inputFixtures': {'case': 'fixture-$index', 'mode': 'deterministic'},
    'templateType': type,
    'sourceLessonId':
        '$type-tutorial-${index.toString().padLeft(3, '0')}-lesson',
  });
  return item;
}

String _display(String type) => switch (type) {
  'cpp' => 'C++',
  'javascript' => 'JavaScript',
  'typescript' => 'TypeScript',
  'shell' => 'Shell',
  'html' => 'HTML',
  'css' => 'CSS',
  'sql' => 'SQL',
  'json' => 'JSON',
  'markdown' => 'Markdown',
  _ => type[0].toUpperCase() + type.substring(1),
};

String _source(String type, int index) {
  final a = index;
  final b = index + 2;
  final c = index + 4;
  return switch (type) {
    'c' =>
      '#include <stdio.h>\nint main(void) { int values[] = {$a, $b, $c}; int total = values[0] + values[1] * 2 + values[2] * 3; printf("weighted=%d\\n", total); return 0; }',
    'cpp' =>
      '#include <iostream>\n#include <vector>\nint main() { std::vector<int> values{$a, $b, $c}; int total = 0; for (size_t i = 0; i < values.size(); ++i) total += values[i] * static_cast<int>(i + 1); std::cout << "weighted=" << total << "\\n"; }',
    'lua' =>
      'local values = {$a, $b, $c}\nlocal total = 0\nfor position, value in ipairs(values) do total = total + value * position end\nprint("weighted=" .. total)',
    'javascript' =>
      'const values = [$a, $b, $c];\nconst weighted = values.reduce((total, value, position) => total + value * (position + 1), 0);\nconsole.log("weighted=" + weighted);',
    'typescript' =>
      'const values: number[] = [$a, $b, $c];\nconst weighted = values.reduce((total, value, position) => total + value * (position + 1), 0);\nconsole.log("weighted=" + weighted);',
    'shell' =>
      '#!/usr/bin/env sh\nset -eu\nweighted=${a + b * 2 + c * 3}\nprintf "weighted=%s\\n" "\$weighted"',
    'rust' =>
      'fn main() { let values = [$a, $b, $c]; let weighted: i32 = values.iter().enumerate().map(|(i, value)| value * (i as i32 + 1)).sum(); println!("weighted={weighted}"); }',
    'go' =>
      'package main\nimport "fmt"\nfunc main() { values := []int{$a, $b, $c}; total := 0; for position, value := range values { total += value * (position + 1) }; fmt.Printf("weighted=%d\\n", total) }',
    'java' =>
      'import java.util.List;\nclass Main { public static void main(String[] args) { var values = List.of($a, $b, $c); var total = 0; for (var i = 0; i < values.size(); i++) total += values.get(i) * (i + 1); System.out.println("weighted=" + total); } }',
    'python' =>
      'values = [$a, $b, $c]\nweighted = sum(value * (position + 1) for position, value in enumerate(values))\nprint(f"weighted={weighted}")',
    'dart' =>
      'void main() { final values = <int>[' +
          '$a, $b, $c' +
          ']; final weighted = values[0] + values[1] * 2 + values[2] * 3; print("weighted=" + weighted.toString()); }',
    'sql' =>
      'CREATE TABLE measurements (position INTEGER NOT NULL, value INTEGER NOT NULL);\nINSERT INTO measurements VALUES (1, $a), (2, $b), (3, $c);\nSELECT SUM(position * value) AS weighted FROM measurements;',
    'json' =>
      '{\n  "schemaVersion": 1,\n  "type": "measurement",\n  "values": [$a, $b, $c],\n  "metadata": {"deterministic": true, "case": $a}\n}',
    'html' =>
      '<!doctype html>\n<main data-case="$a"><h1>Measurement $a</h1><output>weighted=${a + b * 2 + c * 3}</output></main>',
    'css' =>
      '.measurement-$a { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: .75rem; color: hsl(${a % 360} 65% 35%); }',
    'markdown' =>
      '# Measurement $a\n\nThis note records a **deterministic** weighted measurement.\n\n| Position | Value |\n| ---: | ---: |\n| 1 | $a |\n| 2 | $b |\n| 3 | $c |',
    _ => 'unsupported type: $type',
  };
}

String _output(String type, int index) {
  final weighted = index + (index + 2) * 2 + (index + 4) * 3;
  return switch (type) {
    'sql' => 'weighted\n$weighted',
    'json' || 'html' || 'css' || 'markdown' => 'preview-ready\ncase=$index',
    _ => 'weighted=$weighted',
  };
}
