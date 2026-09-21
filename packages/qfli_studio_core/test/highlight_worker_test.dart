import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/languages/css.dart';
import 'package:re_highlight/re_highlight.dart';

class _ObserveHighlight extends HLPlugin {
  _ObserveHighlight(this.port, {this.delayMs = 250});
  final SendPort port;
  final int delayMs;
  @override
  void beforeHighlight(BeforeHighlightContext context) {
    port.send('start:${context.code}');
    // 在高亮 isolate 模拟慢解析，不能阻塞输入所在的 UI isolate。
    sleep(Duration(milliseconds: delayMs));
  }

  @override
  void afterHighlight(HighlightResult result) =>
      port.send('end:${result.code}');
}

Future<void> _until(WidgetTester tester, bool Function() done) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!done()) {
    if (DateTime.now().isAfter(deadline)) throw TimeoutException('高亮任务未按时完成');
    await tester.pump(const Duration(milliseconds: 10));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
}

void main() {
  testWidgets('工作线程超时后立即停止，编辑和退出仍然可用', (tester) async {
    final port = ReceivePort();
    final messages = <String>[];
    final subscription = port.listen((event) => messages.add(event as String));
    final controller = CodeLineEditingController.fromText(
      '.slow { color: red; }',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CodeEditor(
            controller: controller,
            style: CodeEditorStyle(
              codeTheme: CodeHighlightTheme(
                language: 'css',
                languages: {'css': CodeHighlightThemeMode(mode: langCss)},
                theme: const {},
                plugins: [_ObserveHighlight(port.sendPort, delayMs: 3000)],
              ),
            ),
          ),
        ),
      ),
    );
    await _until(
      tester,
      () => messages.any((message) => message.startsWith('start:')),
    );
    await tester.pump(const Duration(seconds: 3));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 80)),
    );
    expect(messages.any((message) => message.startsWith('end:')), isFalse);
    controller.text = '.still-editable { color: blue; }';
    await tester.pump(const Duration(milliseconds: 110));
    expect(controller.text, '.still-editable { color: blue; }');
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    await tester.runAsync(() async {
      await subscription.cancel();
      port.close();
    });
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('快速修改后的查找和代码折叠使用最新快照', (tester) async {
    final controller = CodeLineEditingController.fromText(
      'void demo() {\n  old();\n}',
    );
    final chunks = CodeChunkController(
      controller,
      const DefaultCodeChunkAnalyzer(),
    );
    final find = CodeFindController(controller);
    find.findMode();
    find.findInputController.text = 'latest';
    for (var i = 0; i < 20; i++) {
      controller.text = 'void demo$i() {\n  latest();\n  latest();\n}';
    }
    await _until(
      tester,
      () =>
          find.value?.result?.matches.length == 2 &&
          chunks.value.any((chunk) => chunk.index == 0 && chunk.end == 3),
    );
    final text = controller.text;
    chunks.collapse(0);
    expect(controller.codeLines.length, lessThan(4));
    chunks.expand(0);
    expect(controller.text, text);
    find.dispose();
    chunks.dispose();
    controller.dispose();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('慢高亮期间快速输入只处理最新快照，选区变化不触发解析', (tester) async {
    final port = ReceivePort();
    final messages = <String>[];
    final subscription = port.listen((event) => messages.add(event as String));
    final controller = CodeLineEditingController.fromText(
      '.initial { color: red; }',
    );
    final theme = CodeHighlightTheme(
      languages: {
        'css': CodeHighlightThemeMode(mode: langCss, maxLineLength: 2048),
      },
      language: 'css',
      theme: const {'attribute': TextStyle(color: Colors.blue)},
      plugins: [_ObserveHighlight(port.sendPort)],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CodeEditor(
            controller: controller,
            style: CodeEditorStyle(codeTheme: theme),
          ),
        ),
      ),
    );
    await _until(
      tester,
      () => messages.any((message) => message.startsWith('end:')),
    );
    await tester.pump();
    messages.clear();

    controller.text = '.first { color: red; }';
    await tester.pump(const Duration(milliseconds: 110));
    await _until(
      tester,
      () => messages.any((message) => message.startsWith('start:')),
    );
    for (var i = 0; i < 20; i++) {
      controller.text = '.latest$i { color: blue; }';
      await tester.pump(const Duration(milliseconds: 5));
    }
    await tester.pump(const Duration(milliseconds: 110));
    await _until(
      tester,
      () => messages.contains('end:.latest19 { color: blue; }'),
    );
    await tester.pump();
    final starts = messages
        .where((message) => message.startsWith('start:'))
        .toList();
    expect(starts.length, lessThanOrEqualTo(2));
    expect(starts.last, 'start:.latest19 { color: blue; }');
    expect(controller.text, '.latest19 { color: blue; }');

    messages.clear();
    controller.selection = const CodeLineSelection.collapsed(
      index: 0,
      offset: 3,
    );
    await tester.pump(const Duration(milliseconds: 150));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 80)),
    );
    expect(messages, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    await tester.runAsync(() async {
      await subscription.cancel();
      port.close();
    });
    await tester.pump();
  });

  testWidgets('超长行在调用解析器前降级，内容仍可编辑', (tester) async {
    final port = ReceivePort();
    final messages = <String>[];
    final subscription = port.listen((event) => messages.add(event as String));
    final controller = CodeLineEditingController.fromText('x' * 4096);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CodeEditor(
            controller: controller,
            style: CodeEditorStyle(
              codeTheme: CodeHighlightTheme(
                language: 'css',
                languages: {
                  'css': CodeHighlightThemeMode(
                    mode: langCss,
                    maxSize: 256 * 1024,
                    maxLineLength: 2048,
                  ),
                },
                theme: const {},
                plugins: [_ObserveHighlight(port.sendPort)],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 400)),
    );
    await tester.pump();
    expect(messages, isEmpty);
    controller.text = '${controller.text}y';
    expect(controller.text.length, 4097);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 150));
    expect(tester.takeException(), isNull);
    controller.dispose();
    await tester.runAsync(() async {
      await subscription.cancel();
      port.close();
    });
  });
}
