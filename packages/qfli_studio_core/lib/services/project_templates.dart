import 'package:flutter/material.dart';

/// 新建项目时可选择的初始模板文件。
class TemplateFile {
  const TemplateFile(this.path, this.content);

  final String path;
  final String content;
}

/// 支持的项目语言（用于模板与筛选）。
abstract final class ProjectLanguages {
  static const List<String> all = [
    '空项目',
    'Java',
    'Python',
    'C',
    'C++',
    'Web',
    'Dart',
    'Lua',
    'JavaScript',
    'TypeScript',
    'JSON',
    'Markdown',
    'SQL',
    'Kotlin',
    'Go',
    'Rust',
    'C#',
    'PHP',
    'Ruby',
  ];
}

/// 项目模板：创建项目时写入对应的初始 demo 代码（统一放在 src/ 目录）。
enum ProjectTemplate {
  empty('空项目', Icons.folder_open_outlined, '空项目', []),
  java('Java', Icons.coffee_outlined, 'Java', [
    TemplateFile('src/Main.java', _javaMain),
  ]),
  python('Python', Icons.terminal_outlined, 'Python', [
    TemplateFile('src/main.py', _pythonMain),
  ]),
  c('C', Icons.code_outlined, 'C', [
    TemplateFile('src/main.c', _cMain),
  ]),
  cpp('C++', Icons.code, 'C++', [
    TemplateFile('src/main.cpp', _cppMain),
  ]),
  html('Web', Icons.web_outlined, 'Web', [
    TemplateFile('src/index.html', _htmlIndex),
    TemplateFile('src/style.css', _htmlCss),
    TemplateFile('src/main.js', _htmlJs),
  ]),
  dart('Dart', Icons.flutter_dash, 'Dart', [
    TemplateFile('src/main.dart', _dartMain),
  ]),
  lua('Lua', Icons.terminal, 'Lua', [
    TemplateFile('src/main.lua', _luaMain),
  ]),
  javascript('JavaScript', Icons.javascript_outlined, 'JavaScript', [
    TemplateFile('src/main.js', _jsMain),
  ]),
    typescript('TypeScript', Icons.javascript, 'TypeScript', [
    TemplateFile('src/main.ts', _tsMain),
  ]),
  json('JSON', Icons.data_object, 'JSON', [
    TemplateFile('src/data.json', _jsonData),
  ]),
  markdown('Markdown', Icons.article_outlined, 'Markdown', [
    TemplateFile('README.md', _markdownReadme),
  ]),
  sql('SQL', Icons.storage_outlined, 'SQL', [
    TemplateFile('src/main.sql', _sqlMain),
  ]),
  kotlin('Kotlin', Icons.code_off_outlined, 'Kotlin', [
    TemplateFile('src/main.kt', _kotlinMain),
  ]),
  go('Go', Icons.bolt_outlined, 'Go', [
    TemplateFile('src/main.go', _goMain),
  ]),
  rust('Rust', Icons.settings_suggest_outlined, 'Rust', [
    TemplateFile('src/main.rs', _rustMain),
  ]),
  csharp('C#', Icons.grid_on_outlined, 'C#', [
    TemplateFile('src/main.cs', _csharpMain),
  ]),
  php('PHP', Icons.language_outlined, 'PHP', [
    TemplateFile('src/main.php', _phpMain),
  ]),
  ruby('Ruby', Icons.auto_awesome_outlined, 'Ruby', [
    TemplateFile('src/main.rb', _rubyMain),
  ]);

  const ProjectTemplate(this.label, this.icon, this.language, this.files);

  final String label;
  final IconData icon;

  /// 语言标注（写入项目，供筛选）。
  final String language;
  final List<TemplateFile> files;

  /// Stable JSON/type discriminator for project metadata and examples.
  String get type => switch (this) {
    ProjectTemplate.empty => 'empty',
    ProjectTemplate.java => 'java',
    ProjectTemplate.python => 'python',
    ProjectTemplate.c => 'c',
    ProjectTemplate.cpp => 'cpp',
    ProjectTemplate.html => 'web',
    ProjectTemplate.dart => 'dart',
    ProjectTemplate.lua => 'lua',
    ProjectTemplate.javascript => 'javascript',
    ProjectTemplate.typescript => 'typescript',
    ProjectTemplate.json => 'json',
    ProjectTemplate.markdown => 'markdown',
    ProjectTemplate.sql => 'sql',
    ProjectTemplate.kotlin => 'kotlin',
    ProjectTemplate.go => 'go',
    ProjectTemplate.rust => 'rust',
    ProjectTemplate.csharp => 'csharp',
    ProjectTemplate.php => 'php',
    ProjectTemplate.ruby => 'ruby',
  };

  static ProjectTemplate? fromType(String value) {
    final normalized = value.trim().toLowerCase();
    for (final template in values) {
      if (template.type == normalized) return template;
    }
    return null;
  }

  /// 创建完成后自动打开的主文件；空项目为 null。
  String? get mainFile => files.isEmpty ? null : files.first.path;
}

const String _javaMain = '''
public class Main {
    public static void main(String[] args) {
        System.out.println("Hello, QFLIStudio+!");
    }
}
''';

const String _pythonMain = '''
def main():
    print("Hello, QFLIStudio+!")


if __name__ == "__main__":
    main()
''';

const String _cMain = '''
#include <stdio.h>

int main(void) {
    printf("Hello, QFLIStudio+!\\n");
    return 0;
}
''';

const String _cppMain = '''
#include <iostream>

int main() {
    std::cout << "Hello, QFLIStudio+!" << std::endl;
    return 0;
}
''';

const String _htmlIndex = '''
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>QFLIStudio+</title>
    <link rel="stylesheet" href="style.css">
</head>
<body>
    <h1>Hello, QFLIStudio+!</h1>
    <p>由 QFLIStudio+ 创建的初始页面。</p>
    <script src="main.js"></script>
</body>
</html>
''';

const String _htmlCss = '''
body {
    font-family: system-ui, sans-serif;
    background: #f6f8fa;
    color: #1f2328;
    display: grid;
    place-items: center;
    min-height: 100vh;
}
''';

const String _htmlJs = '''
console.log('Hello, QFLIStudio+!');
''';

const String _dartMain = '''
void main() {
  print('Hello, QFLIStudio+!');
}
''';

const String _luaMain = '''
print("Hello, QFLIStudio+!")
''';

const String _jsMain = '''
console.log('Hello, QFLIStudio+!');
''';

const String _tsMain = '''
const greet = (name: string): string => `Hello, QFLIStudio+! \${name}`;

console.log(greet('world'));
''';

const String _jsonData = '''
{
  "name": "QFLI project",
  "version": 1
}
''';

const String _markdownReadme = '''
# QFLI project

Edit this document and switch to preview to see the rendered Markdown.
''';

const String _sqlMain = '''
CREATE TABLE IF NOT EXISTS notes (
    id INTEGER PRIMARY KEY,
    body TEXT NOT NULL
);

SELECT name FROM sqlite_master WHERE type = 'table';
''';

const String _kotlinMain = '''
fun main() {
    println("Hello, QFLIStudio+!")
}
''';

const String _goMain = '''
package main

import "fmt"

func main() {
    fmt.Println("Hello, QFLIStudio+!")
}
''';

const String _rustMain = '''
fn main() {
    println!("Hello, QFLIStudio+!");
}
''';

const String _csharpMain = '''
using System;

class Program {
    static void Main() {
        Console.WriteLine("Hello, QFLIStudio+!");
    }
}
''';

const String _phpMain = '''
<?php
echo "Hello, QFLIStudio+!\n";
''';

const String _rubyMain = '''
puts 'Hello, QFLIStudio+!'
''';
