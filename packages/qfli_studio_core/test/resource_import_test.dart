import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qfli_studio_core/services/picker_service.dart';
import 'package:qfli_studio_core/services/resource_import_service.dart';

void main() {
  test('resource import copies bytes and requires an explicit conflict choice', () async {
    final root = await Directory.systemTemp.createTemp('qfli_resource_import_');
    addTearDown(() => root.delete(recursive: true));
    final source = File('${root.path}${Platform.pathSeparator}asset.bin');
    final destination = Directory('${root.path}${Platform.pathSeparator}assets');
    await source.writeAsBytes([0, 1, 2, 255]);

    final first = await ResourceImportService.importDocuments(
      documents: [PickedDocument(path: source.path, name: 'asset.bin')],
      destinationDirectory: destination.path,
      resolveConflict: (_) async => false,
    );
    expect(first.imported, 1);
    expect(await File('${destination.path}${Platform.pathSeparator}asset.bin')
        .readAsBytes(), [0, 1, 2, 255]);

    await source.writeAsBytes([9, 8, 7]);
    final skipped = await ResourceImportService.importDocuments(
      documents: [PickedDocument(path: source.path, name: 'asset.bin')],
      destinationDirectory: destination.path,
      resolveConflict: (_) async => false,
    );
    expect(skipped.skipped, 1);
    expect(await File('${destination.path}${Platform.pathSeparator}asset.bin')
        .readAsBytes(), [0, 1, 2, 255]);

    final replaced = await ResourceImportService.importDocuments(
      documents: [PickedDocument(path: source.path, name: 'asset.bin')],
      destinationDirectory: destination.path,
      resolveConflict: (_) async => true,
    );
    expect(replaced.imported, 1);
    expect(await File('${destination.path}${Platform.pathSeparator}asset.bin')
        .readAsBytes(), [9, 8, 7]);
  });
}
