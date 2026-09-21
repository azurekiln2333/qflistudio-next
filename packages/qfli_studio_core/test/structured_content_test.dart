import 'package:flutter_test/flutter_test.dart';
import 'package:qfli_studio_core/services/structured_content_service.dart';

void main() {
  test('JSON analysis formats valid documents and exposes the root value', () {
    final result = JsonDocumentService.analyze('{"items":[1,true]}');

    expect(result.valid, isTrue);
    expect(result.formatted, contains('\n'));
    expect(JsonDocumentService.nodeLabel(result.value), 'object');
  });

  test('JSON analysis returns an actionable invalid result', () {
    final result = JsonDocumentService.analyze('{"items":]');

    expect(result.valid, isFalse);
    expect(result.error, isNotEmpty);
    expect(result.formatted, '{"items":]');
  });
}
