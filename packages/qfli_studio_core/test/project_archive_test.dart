import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qfli_studio_core/models/project.dart';
import 'package:qfli_studio_core/services/project_archive_service.dart';
import 'package:qfli_studio_core/services/project_config.dart';

void main() {
  test('project archive round-trips text, binary and type metadata', () async {
    final source = await Directory.systemTemp.createTemp('qfli_archive_source');
    final target = await Directory.systemTemp.createTemp('qfli_archive_target');
    addTearDown(() async {
      await source.delete(recursive: true);
      await target.delete(recursive: true);
    });
    await File('${source.path}/src/main.cpp').create(recursive: true);
    await File('${source.path}/src/main.cpp').writeAsString('int main() {}');
    await File('${source.path}/assets/icon.bin').create(recursive: true);
    await File('${source.path}/assets/icon.bin').writeAsBytes([0, 1, 255]);
    await ProjectConfig.write(
      projectRoot: source.path,
      name: 'Forge demo',
      language: 'C++',
      type: 'cpp',
    );
    final project = Project.create(
      name: 'Forge demo',
      path: source.path,
      language: 'C++',
      type: 'cpp',
    );

    final archive = await ProjectArchiveService.exportProject(project);
    final decoded = jsonDecode(archive) as Map<String, dynamic>;
    expect(decoded['type'], 'cpp');
    expect(decoded['files'], hasLength(3));

    await ProjectArchiveService.restoreProject(
      source: archive,
      targetDirectory: target.path,
    );
    expect(
      await File('${target.path}/src/main.cpp').readAsString(),
      'int main() {}',
    );
    expect(
      await File('${target.path}/assets/icon.bin').readAsBytes(),
      [0, 1, 255],
    );
    expect(ProjectConfig.readType(target.path), 'cpp');
  });

  test('archive rejects traversal and duplicate paths', () async {
    final target = await Directory.systemTemp.createTemp('qfli_archive_invalid');
    addTearDown(() => target.delete(recursive: true));
    Future<void> expectRejected(Map<String, dynamic> data) async {
      await expectLater(
        ProjectArchiveService.restoreProject(
          source: jsonEncode(data),
          targetDirectory: target.path,
        ),
        throwsA(isA<ProjectArchiveException>()),
      );
    }
    await expectRejected({
      'files': [
        {'path': '../escape.txt', 'encoding': 'utf8', 'content': 'x'},
      ],
    });
    await expectRejected({
      'files': [
        {'path': 'same.txt', 'encoding': 'utf8', 'content': 'x'},
        {'path': 'same.txt', 'encoding': 'utf8', 'content': 'y'},
      ],
    });
  });
}
