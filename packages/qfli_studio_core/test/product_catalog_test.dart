import 'package:flutter_test/flutter_test.dart';
import 'package:qfli_studio_core/services/studio_profile.dart';

void main() {
  test('产品目录固定为十二个可安装产品', () {
    expect(StudioProductCatalog.products, {
      StudioProductCatalog.qfliStudioKey: StudioProductCatalog.qfliStudio,
      StudioProductCatalog.scriptKey: StudioProductCatalog.script,
      StudioProductCatalog.rustCoreKey: StudioProductCatalog.rustCore,
      StudioProductCatalog.goShiftKey: StudioProductCatalog.goShift,
      StudioProductCatalog.jvmxKey: StudioProductCatalog.jvmx,
      StudioProductCatalog.webForgeKey: StudioProductCatalog.webForge,
      StudioProductCatalog.pyFlowKey: StudioProductCatalog.pyFlow,
      StudioProductCatalog.forgeKey: StudioProductCatalog.forge,
      StudioProductCatalog.dartWingKey: StudioProductCatalog.dartWing,
      StudioProductCatalog.sqlabKey: StudioProductCatalog.sqlab,
      StudioProductCatalog.jsonKey: StudioProductCatalog.json,
      StudioProductCatalog.noteKey: StudioProductCatalog.note,
    });
    expect(StudioProductCatalog.products, hasLength(12));
  });

  test('所有产品包名都使用统一前缀', () {
    for (final key in StudioProductCatalog.products.keys) {
      expect(
        StudioProductCatalog.packageName(key),
        startsWith('com.azurekiln.qfli.'),
      );
    }
  });

  test('C 与 C++ 归属于同一个 Forge 产品', () {
    expect(StudioProductCatalog.forLanguage('c'), StudioProductCatalog.forge);
    expect(
      StudioProductCatalog.forLanguage('cpp'),
      StudioProductCatalog.forge,
    );
  });
}
