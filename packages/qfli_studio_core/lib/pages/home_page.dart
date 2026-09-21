import 'dart:io';

import 'package:flutter/material.dart';

import '../editor/editor_page.dart';
import '../models/project.dart';
import '../services/app_paths.dart';
import '../services/api_client.dart';
import '../services/cloud_sync_service.dart';
import '../services/project_templates.dart';
import '../services/studio_profile.dart';
import '../store/auth_store.dart';
import '../store/project_store.dart';
import '../store/settings_store.dart';
import 'local_content_pages.dart';
import 'community/post_list_page.dart';
import '../widgets/project_card.dart';
import '../widgets/project_dialogs.dart';
import 'profile_page.dart';

/// 应用外壳：联网版显示主页 / 教程 / 讨论 / 我的；离线语言版显示主页 / 教程 / 示例代码。
class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.store,
    required this.auth,
    required this.settings,
  });

  final ProjectStore store;
  final AuthStore auth;
  final SettingsStore settings;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  final Set<int> _visitedTabs = {0};

  @override
  Widget build(BuildContext context) {
    final profile = StudioProfile.current;
    final offline = profile?.isOffline == true;
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          HomeTab(
            store: widget.store,
            auth: widget.auth,
            settings: widget.settings,
          ),
          if (_visitedTabs.contains(1))
            TickerMode(
              enabled: _currentIndex == 1,
              child: offline
                  ? LocalTutorialsTab(language: profile!.id)
                  : TutorialsTab(auth: widget.auth),
            )
          else
            const SizedBox.shrink(),
          if (_visitedTabs.contains(2))
            TickerMode(
              enabled: _currentIndex == 2,
              child: offline
                  ? ExampleCodeTab(language: profile!.id)
                  : DiscussionTab(auth: widget.auth),
            )
          else
            const SizedBox.shrink(),
          if (!offline)
            if (_visitedTabs.contains(3))
              TickerMode(
                enabled: _currentIndex == 3,
                child: ProfileTab(auth: widget.auth, settings: widget.settings),
              )
            else
              const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() {
          _visitedTabs.add(index);
          _currentIndex = index;
        }),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: '主页',
          ),
          const NavigationDestination(
            icon: Icon(Icons.school_outlined),
            selectedIcon: Icon(Icons.school),
            label: '教程',
          ),
          NavigationDestination(
            icon: Icon(offline ? Icons.code_outlined : Icons.forum_outlined),
            selectedIcon: Icon(offline ? Icons.code : Icons.forum),
            label: offline ? '示例代码' : '讨论',
          ),
          if (!offline)
            const NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: '我的',
            ),
        ],
      ),
    );
  }
}

/// 主页 Tab：项目列表 + 搜索 + 更多操作。
/// 内部 4 个子页签：全部项目（首字母）/ 历史（最近打开）/ 收藏 / 云端。
class HomeTab extends StatefulWidget {
  const HomeTab({
    super.key,
    required this.store,
    required this.auth,
    required this.settings,
  });

  final ProjectStore store;
  final AuthStore auth;
  final SettingsStore settings;

  @override
  State<HomeTab> createState() => _HomeTabState();
}

enum _ProjectScope { all, history, favorite, cloud }

class _HomeTabState extends State<HomeTab>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final _searchController = TextEditingController();
  bool _searchOpen = false;
  String _query = '';
  String _languageFilter = '';
  Future<void>? _refreshRequest;
  late final List<_ProjectScope> _scopes =
      StudioProfile.current?.isOffline == true
      ? const [_ProjectScope.all, _ProjectScope.history, _ProjectScope.favorite]
      : _ProjectScope.values;
  late final TabController _projectTabs = TabController(
    length: _scopes.length,
    vsync: this,
  );

  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _projectTabs.dispose();
    super.dispose();
  }

  void _openSearch() {
    setState(() {
      _searchOpen = true;
      _query = '';
      _languageFilter = '';
      _searchController.clear();
    });
  }

  void _closeSearch() {
    setState(() {
      _searchOpen = false;
      _query = '';
      _searchController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        leading: _searchOpen
            ? IconButton(
                tooltip: '退出搜索',
                icon: const Icon(Icons.arrow_back),
                onPressed: _closeSearch,
              )
            : null,
        automaticallyImplyLeading: false,
        centerTitle: false,
        title: _searchOpen
            ? _buildSearchField()
            : Text(
                StudioProfile.current?.appTitle ?? 'QFLIStudio+',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
        actions: _searchOpen
            ? const [SizedBox(width: 8)]
            : [
                IconButton(
                  tooltip: '搜索项目',
                  icon: const Icon(Icons.search),
                  onPressed: _openSearch,
                ),
                PopupMenuButton<String>(
                  tooltip: '更多',
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) {
                    switch (value) {
                      case 'add_existing':
                        showAddExistingDialog(context, widget.store);
                      case 'remove_missing':
                        _removeMissingProjects(context);
                      case 'new_cloud':
                        _createCloudProject(context);
                    }
                  },
                  itemBuilder: (context) => [
                    if (AppPaths.isDesktop)
                      const PopupMenuItem(
                        value: 'add_existing',
                        child: Row(
                          children: [
                            Icon(Icons.folder_open_outlined, size: 20),
                            SizedBox(width: 12),
                            Text('添加现有项目'),
                          ],
                        ),
                      ),
                    if (StudioProfile.current?.isOffline != true &&
                        widget.auth.isLoggedIn)
                      const PopupMenuItem(
                        value: 'new_cloud',
                        child: Row(
                          children: [
                            Icon(Icons.cloud_upload_outlined, size: 20),
                            SizedBox(width: 12),
                            Text('新建云端项目'),
                          ],
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'remove_missing',
                      child: Row(
                        children: [
                          Icon(Icons.folder_delete_outlined, size: 20),
                          SizedBox(width: 12),
                          Text('移除失效项目'),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
              ],
      ),
      floatingActionButton: _searchOpen
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _createProject(context),
              icon: const Icon(Icons.create_new_folder_outlined),
              label: const Text('新建项目'),
            ),
      body: ListenableBuilder(
        listenable: Listenable.merge([widget.store, widget.auth]),
        builder: (context, _) {
          if (_searchOpen) {
            return _buildProjectList(
              context,
              scope: _ProjectScope.all,
              keyword: _query,
            );
          }
          return Column(
            children: [
              TabBar(
                controller: _projectTabs,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                dividerColor: Colors.transparent,
                labelPadding: const EdgeInsets.symmetric(horizontal: 12),
                tabs: [
                  const Tab(height: 36, text: '全部项目'),
                  const Tab(height: 36, text: '历史项目'),
                  const Tab(height: 36, text: '收藏项目'),
                  if (_scopes.contains(_ProjectScope.cloud))
                    const Tab(height: 36, text: '云端项目'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _projectTabs,
                  children: [
                    for (final scope in _scopes)
                      _buildProjectList(context, scope: scope),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSearchField() {
    final scheme = Theme.of(context).colorScheme;
    return TextField(
      controller: _searchController,
      autofocus: true,
      textAlign: TextAlign.center,
      onChanged: (value) => setState(() => _query = value),
      style: Theme.of(context).textTheme.bodyLarge,
      decoration: InputDecoration(
        hintText: '搜索项目名称或路径',
        suffixIcon: _query.isEmpty
            ? null
            : IconButton(
                tooltip: '清空',
                icon: const Icon(Icons.close, size: 20),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _query = '');
                },
              ),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding: EdgeInsets.zero,
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
      ),
    );
  }

  /// 按页签取项目列表。
  List<Project> _projectsFor(_ProjectScope scope) {
    final all = widget.store.projects
        .where(
          (project) =>
              StudioProfile.current?.isOffline != true || !project.isCloud,
        )
        .toList();
    switch (scope) {
      case _ProjectScope.all:
        final list = [
          ...all,
        ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        return list;
      case _ProjectScope.history:
        return [...all];
      case _ProjectScope.favorite:
        return all.where((p) => p.favorite).toList();
      case _ProjectScope.cloud:
        return all.where((p) => p.isCloud).toList();
    }
  }

  /// 语言筛选芯片的候选：语言专属 App 只列出自己那一门语言。
  List<String> get _languageChips {
    final profile = StudioProfile.current;
    final source = ProjectLanguages.all.where((l) => l != '空项目');
    if (profile == null) return source.toList(growable: false);
    return profile.filterLanguages(source);
  }

  Widget _buildProjectList(
    BuildContext context, {
    required _ProjectScope scope,
    String keyword = '',
  }) {
    var projects = _projectsFor(scope);
    final searching = keyword.isNotEmpty;
    if (searching) {
      final k = keyword.trim().toLowerCase();
      projects = projects
          .where(
            (p) =>
                p.name.toLowerCase().contains(k) ||
                p.path.toLowerCase().contains(k),
          )
          .toList();
    }
    if (scope == _ProjectScope.all) {
      // 语言筛选 chips（全部项目页签），始终显示全部语言。
      final chipList = [
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: FilterChip(
            label: const Text('全部语言'),
            selected: _languageFilter.isEmpty,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            onSelected: (_) => setState(() => _languageFilter = ''),
          ),
        ),
        for (final lang in _languageChips)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: FilterChip(
              label: Text(lang),
              selected: _languageFilter == lang,
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onSelected: (_) => setState(() {
                _languageFilter = _languageFilter == lang ? '' : lang;
              }),
            ),
          ),
      ];
      if (_languageFilter.isNotEmpty) {
        projects = projects
            .where((p) => p.language == _languageFilter)
            .toList();
      }
      final body = projects.isEmpty
          ? _emptyScrollable(
              searching || _languageFilter.isNotEmpty
                  ? const _EmptySearchResult()
                  : _EmptyState(onCreate: () => _createProject(context)),
            )
          : _buildGridOrList(context, projects);
      // 语言标签栏只在完整的 QFLI Studio 里出现；语言专属 App（只服务一门语言）
      // 显示这排芯片既没有筛选意义，也白占一行高度。
      final showLanguageChips =
          StudioProfile.current == null || chipList.length > 1;
      return Column(
        children: [
          if (showLanguageChips)
            // 高度随内容收缩；左右 12 与卡片外边距、TabBar labelPadding 对齐。
            // 下边距为 0：下方列表自带 8 的顶部内边距，避免叠成 16 的双倍空隙。
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(children: chipList),
            ),
          Expanded(child: _refreshable(scope, body)),
        ],
      );
    }
    if (projects.isEmpty) {
      final empty = switch (scope) {
        _ProjectScope.favorite => _buildSimpleEmpty(
          context,
          Icons.star_border_outlined,
          '还没有收藏的项目',
          '在项目卡片菜单中选择「收藏」',
        ),
        _ProjectScope.cloud => _buildSimpleEmpty(
          context,
          Icons.cloud_outlined,
          '还没有云端项目',
          '登录后在更多菜单中「新建云端项目」，源码自动同步到服务器',
        ),
        _ =>
          searching
              ? const _EmptySearchResult()
              : _EmptyState(onCreate: () => _createProject(context)),
      };
      return _refreshable(scope, _emptyScrollable(empty));
    }
    return _refreshable(scope, _buildGridOrList(context, projects));
  }

  Widget _refreshable(_ProjectScope scope, Widget child) =>
      RefreshIndicator(onRefresh: () => _refreshProjects(scope), child: child);

  Widget _emptyScrollable(Widget child) => CustomScrollView(
    physics: const AlwaysScrollableScrollPhysics(),
    slivers: [
      SliverFillRemaining(
        hasScrollBody: false,
        child: Padding(padding: const EdgeInsets.all(24), child: child),
      ),
    ],
  );

  Future<void> _refreshProjects(_ProjectScope scope) async {
    if (_refreshRequest != null) return _refreshRequest;
    final request = _reloadProjects(scope);
    _refreshRequest = request;
    try {
      await request;
    } finally {
      if (identical(_refreshRequest, request)) _refreshRequest = null;
    }
  }

  Future<void> _reloadProjects(_ProjectScope scope) async {
    try {
      await widget.store.refresh();
      if (StudioProfile.current?.isOffline == true) return;
      final token = widget.auth.token;
      if (token == null ||
          (scope != _ProjectScope.cloud && scope != _ProjectScope.all)) {
        return;
      }
      final remote = await ApiClient.instance.cloudProjects(token);
      if (!mounted || widget.auth.token != token) return;
      final projects = <Project>[];
      for (final item in remote) {
        final id = (item['id'] as num?)?.toInt();
        final name = item['name'] as String?;
        if (id == null || id <= 0 || name == null) continue;
        final mirror = await CloudSyncService.open(cloudId: id, name: name);
        projects.add(
          Project.create(name: name, path: mirror.localPath, cloudId: '$id'),
        );
        mirror.dispose();
      }
      if (!mounted || widget.auth.token != token) return;
      await widget.store.mergeCloudProjects(projects);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is ApiException
                ? '云端列表刷新失败：${error.message}'
                : '暂时无法刷新项目列表，请重试',
          ),
        ),
      );
    }
  }

  Widget _buildSimpleEmpty(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
  ) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 56,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridOrList(BuildContext context, List<Project> projects) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth > 720;
        const padding = EdgeInsets.fromLTRB(12, 8, 12, 96);
        if (wide) {
          return GridView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: padding,
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 420,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              mainAxisExtent: 90,
            ),
            itemCount: projects.length,
            itemBuilder: (context, i) => _buildCard(context, projects[i]),
          );
        }
        return ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: padding,
          itemCount: projects.length,
          itemBuilder: (context, i) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildCard(context, projects[i]),
          ),
        );
      },
    );
  }

  Widget _buildCard(BuildContext context, Project project) {
    return ProjectCard(
      project: project,
      onOpen: () => _openProject(context, project),
      onRemove: () => _deleteProject(context, project),
      onToggleFavorite: (value) => widget.store.setFavorite(project, value),
    );
  }

  Future<void> _createProject(BuildContext context) async {
    final result = await showCreateProjectDialog(context, widget.store);
    if (result != null && context.mounted) {
      await _openProject(
        context,
        result.project,
        initialOpenFile: result.openFile,
      );
    }
  }

  Future<void> _openProject(
    BuildContext context,
    Project project, {
    String? initialOpenFile,
  }) async {
    if (!project.isCloud && !Directory(project.path).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('项目目录不存在：${project.path}'),
          action: SnackBarAction(
            label: '从列表移除',
            onPressed: () => widget.store.remove(project),
          ),
        ),
      );
      return;
    }
    widget.store.touch(project);
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditorPage(
          project: project,
          auth: widget.auth,
          store: widget.store,
          settings: widget.settings,
          initialOpenPath: initialOpenFile,
        ),
      ),
    );
  }

  Future<void> _deleteProject(BuildContext context, Project project) async {
    final confirmed = await showDeleteProjectConfirm(context, project);
    if (!confirmed || !context.mounted) return;
    // 压缩备份可能耗时，显示进度提示。
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Expanded(child: Text('正在压缩备份并删除…')),
          ],
        ),
      ),
    );
    final error = await widget.store.deleteProject(project);
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error ?? '已删除“${project.name}”，备份可在应用数据 recyclebin/projects_bin 找回',
        ),
      ),
    );
  }

  /// 批量移除目录已不存在的项目记录（不涉及磁盘删除）。
  Future<void> _removeMissingProjects(BuildContext context) async {
    final missing = widget.store.projects
        .where((p) => !p.isCloud && !Directory(p.path).existsSync())
        .toList();
    if (missing.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('没有失效项目，列表一切正常')));
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('移除失效项目？'),
        content: Text(
          '以下 ${missing.length} 个项目的目录已不存在，将仅从列表移除：\n\n'
          '${missing.map((p) => '· ${p.name}').join('\n')}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('移除'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      for (final project in missing) {
        widget.store.remove(project);
      }
    }
  }

  Future<void> _createCloudProject(BuildContext context) async {
    final picked = await showDialog<(String, ProjectTemplate)>(
      context: context,
      builder: (context) {
        var template = defaultTemplate();
        final controller = TextEditingController();
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('新建云端项目'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: '项目名称',
                    prefixIcon: Icon(Icons.cloud_upload_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownMenu<ProjectTemplate>(
                  initialSelection: template,
                  expandedInsets: EdgeInsets.zero,
                  label: const Text('项目类型'),
                  onSelected: (value) {
                    if (value != null) setState(() => template = value);
                  },
                  dropdownMenuEntries: [
                    for (final t in availableTemplates())
                      DropdownMenuEntry(
                        value: t,
                        label: t.label,
                        leadingIcon: Icon(t.icon, size: 20),
                      ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(
                  controller.text.trim().isEmpty
                      ? null
                      : (controller.text.trim(), template),
                ),
                child: const Text('创建'),
              ),
            ],
          ),
        );
      },
    );
    if (picked == null || !context.mounted) return;
    final (name, template) = picked;
    if (RegExp(r'[\\/:*?"<>|]').hasMatch(name)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(r'名称不能包含 \ / : * ? " < > |')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('正在创建云端项目…'),
        duration: Duration(seconds: 1),
      ),
    );
    final created = await CloudSyncService.createCloudProject(
      token: widget.auth.token!,
      name: name,
      template: template,
    );
    if (!context.mounted) return;
    if (created.error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(created.error!)));
      return;
    }
    final service = await CloudSyncService.open(
      cloudId: created.id!,
      name: name,
    );
    final registered = await widget.store.addCloudProject(
      name: name,
      cloudId: '${created.id}',
      cachePath: service.localPath,
      language: template.language,
    );
    service.dispose();
    if (!context.mounted) return;
    if (registered.error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(registered.error!)));
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('云端项目已创建，编辑内容将自动同步到服务器')));
  }
}

class _EmptySearchResult extends StatelessWidget {
  const _EmptySearchResult();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 16),
          Text('未找到匹配的项目', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            '换个关键词试试，支持按名称和路径搜索',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.folder_off_outlined,
            size: 72,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 16),
          Text('还没有项目', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            AppPaths.isDesktop ? '创建一个新项目，或添加磁盘上已有的文件夹' : '点击下方按钮，创建你的第一个项目',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.create_new_folder_outlined),
            label: const Text('新建项目'),
          ),
        ],
      ),
    );
  }
}

/// 教程 Tab：社区教程内容（专区/标签/搜索/点赞/评论/分享）。
class TutorialsTab extends StatelessWidget {
  const TutorialsTab({super.key, required this.auth});

  final AuthStore auth;

  @override
  Widget build(BuildContext context) {
    return PostListPage(type: 'tutorial', auth: auth);
  }
}

/// 讨论 Tab：社区讨论内容。
class DiscussionTab extends StatelessWidget {
  const DiscussionTab({super.key, required this.auth});

  final AuthStore auth;

  @override
  Widget build(BuildContext context) {
    return PostListPage(type: 'discussion', auth: auth);
  }
}
