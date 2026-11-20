import 'package:flutter/material.dart';

import 'package:qfli_studio_core/pages/tools_grid.dart';
import 'package:qfli_studio_core/remote_control/remote_computer_page.dart';
import 'package:qfli_studio_core/services/studio_profile.dart';
import 'package:qfli_studio_core/store/project_store.dart';

/// Tools tab body for the main Studio product.
///
/// Wired through `StudioProfile.toolsTabBuilder`, the existing host extension
/// point for product-owned tools content. That builder replaces the whole
/// `FunctionsTab` body, so this function reproduces what the shared default grid
/// renders and then adds exactly one card:
///
/// * 终端 — the 快捷入口 card from [onOpenTerminal] (`ToolsGrid` adds it itself);
/// * 远程电脑 — the single new entry, gated on
///   [RemoteComputerPage.isSupported];
/// * 通用 — the shared offline group (`ToolsGrid` adds it itself).
///
/// The shared grid also renders a 专用 group when the product is a content
/// product (`StudioProfile.toolsPageBuilder != null`, or productKey in
/// json/note/sqlab/webForge). This product is none of those, so no section is
/// lost. [_assertNotContentProduct] makes that assumption fail loudly in debug
/// instead of silently dropping the 专用 group if the profile changes.
///
/// Offline language products never set `toolsTabBuilder`, so they keep the
/// core's default grid and never see this online entry. The entry is also gated
/// on [RemoteComputerPage.isSupported]: a browser build has no socket and no
/// private storage backend for the module, so the card is not rendered there.
Widget buildStudioToolsTab(ProjectStore store, VoidCallback onOpenTerminal) {
  _assertNotContentProduct();
  return ToolsGrid(
    onOpenTerminal: onOpenTerminal,
    sections: [
      if (RemoteComputerPage.isSupported)
        ToolSection(
          title: '远程电脑',
          icon: Icons.desktop_windows_outlined,
          tools: [
            ToolDefinition(
              icon: Icons.desktop_windows_outlined,
              title: '远程电脑',
              description: '配对电脑后操作其终端、Herdr 与 AI 会话',
              builder: (_) => const RemoteComputerPage(),
            ),
          ],
        ),
    ],
  );
}

/// Debug tripwire for the 专用 group that [buildStudioToolsTab] does not render.
///
/// Keep in sync with `FunctionsTab._isContentProduct` in the shared core. If it
/// ever becomes true for this product, add the 专用 card here (push
/// `ContentToolsPage`) instead of deleting this assertion.
void _assertNotContentProduct() {
  assert(() {
    final profile = StudioProfile.current;
    final contentProduct =
        profile?.toolsPageBuilder != null ||
        switch (profile?.productKey) {
          StudioProductCatalog.jsonKey ||
          StudioProductCatalog.noteKey ||
          StudioProductCatalog.sqlabKey ||
          StudioProductCatalog.webForgeKey => true,
          _ => false,
        };
    if (contentProduct) {
      throw FlutterError(
        'buildStudioToolsTab 取代了 FunctionsTab 的默认内容，但当前产品是内容产品，'
        '默认网格里的「专用」分组会丢失。请在本构建器里补回「专用」卡片，'
        '或改回不设置 toolsTabBuilder。',
      );
    }
    return true;
  }());
}
