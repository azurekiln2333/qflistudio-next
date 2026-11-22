import 'package:flutter/material.dart';

import 'package:qfli_studio_core/harness/ui/agents_entry.dart';
import 'package:qfli_studio_core/pages/tools_grid.dart';
import 'package:qfli_studio_core/remote_control/remote_computer_page.dart';
import 'package:qfli_studio_core/services/studio_profile.dart';
import 'package:qfli_studio_core/store/auth_store.dart';
import 'package:qfli_studio_core/store/project_store.dart';
import 'package:qfli_studio_core/store/settings_store.dart';

/// App 级服务句柄，供工具页这类只拿到 [ProjectStore] 的构建器使用。
///
/// `StudioProfile.toolsTabBuilder` 的签名只传项目仓库和终端回调，而打开
/// 编辑器需要账号与设置。与其改共享内核的档位类型，这里由主 App 在 `main()`
/// 里登记一次；其它产品不设置这些字段，也就看不到这个入口。
({AuthStore auth, SettingsStore settings})? studioAppServices;

/// Tools tab body for the main Studio product.
///
/// Wired through `StudioProfile.toolsTabBuilder`, the existing host extension
/// point for product-owned tools content. That builder replaces the whole
/// `FunctionsTab` body, so this function reproduces what the shared default grid
/// renders and then adds exactly one card:
///
/// * 终端 — the 快捷入口 card from [onOpenTerminal] (`ToolsGrid` adds it itself);
/// * Agents — the single new entry, gated on
///   [RemoteComputerPage.isSupported];
/// * 通用 — the shared offline group (`ToolsGrid` adds it itself).
///
/// The 远程电脑 card used to open the CloudTerminal-derived standalone home
/// (`RemoteComputerPage`). Session management now belongs to the editor page's
/// Agents surface, so the card opens that surface instead; pairing, binding and
/// revoke moved to 设置 → 设备与远程. `RemoteComputerPage` stays exported and
/// unchanged for hosts and tests that still mount it directly.
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
          title: 'Agents',
          icon: Icons.smart_toy_outlined,
          tools: [
            ToolDefinition(
              icon: Icons.smart_toy_outlined,
              title: 'Agents 会话',
              description: '本机、Herdr 和已绑定电脑的 AI 会话都在编辑器的 Agents 面板里',
              builder: (_) => _AgentsEntryRedirect(store: store),
            ),
          ],
        ),
    ],
  );
}

/// 工具页的 Agents 卡片：进编辑器页的 Agents 面板。
///
/// 远程电脑的配对设置不在这个卡片里，已经搬到 设置 → 设备与远程。
class _AgentsEntryRedirect extends StatefulWidget {
  const _AgentsEntryRedirect({required this.store});

  final ProjectStore store;

  @override
  State<_AgentsEntryRedirect> createState() => _AgentsEntryRedirectState();
}

class _AgentsEntryRedirectState extends State<_AgentsEntryRedirect> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final services = studioAppServices;
      if (services == null) return;
      openAgentsSurface(
        context,
        auth: services.auth,
        store: widget.store,
        settings: services.settings,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final services = studioAppServices;
    if (services == null) {
      final theme = Theme.of(context);
      return Scaffold(
        appBar: AppBar(title: const Text('Agents')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Agents 面板在编辑器里。请先在主页打开一个项目。',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Agents 会话')),
      body: const Center(child: CircularProgressIndicator()),
    );
  }
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
