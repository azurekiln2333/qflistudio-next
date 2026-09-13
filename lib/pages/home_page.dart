import 'dart:io';

import 'package:flutter/material.dart';

import '../editor/editor_page.dart';
import '../models/project.dart';
import '../services/app_paths.dart';
import '../community/community_widgets.dart';
import '../services/api_client.dart';
import '../services/cloud_sync_service.dart';
import '../services/project_templates.dart';
import '../store/auth_store.dart';
import '../store/project_store.dart';
import '../store/settings_store.dart';
import 'auth/login_page.dart';
import 'community/post_list_page.dart';
import 'tasks_page.dart';
import '../widgets/project_card.dart';
import '../widgets/project_dialogs.dart';
import 'my_posts_page.dart';
import 'audit_page.dart';
import 'settings_page.dart';

/// 应用外壳：底部 4 个 Tab（主页 / 教程 / 讨论 / 我的）。
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          HomeTab(
            store: widget.store,
            auth: widget.auth,
            settings: widget.settings,
          ),
          TutorialsTab(auth: widget.auth),
          DiscussionTab(auth: widget.auth),
          ProfileTab(auth: widget.auth, settings: widget.settings),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: '主页',
          ),
          NavigationDestination(
            icon: Icon(Icons.school_outlined),
            selectedIcon: Icon(Icons.school),
            label: '教程',
          ),
          NavigationDestination(
            icon: Icon(Icons.forum_outlined),
            selectedIcon: Icon(Icons.forum),
            label: '讨论',
          ),
          NavigationDestination(
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
  late final TabController _projectTabs = TabController(
    length: _ProjectScope.values.length,
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
                'QFLIStudio+',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: const Color(0xFF2196F3),
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
                    if (widget.auth.isLoggedIn)
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
        listenable: widget.store,
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
                tabs: const [
                  Tab(height: 36, text: '全部项目'),
                  Tab(height: 36, text: '历史项目'),
                  Tab(height: 36, text: '收藏项目'),
                  Tab(height: 36, text: '云端项目'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _projectTabs,
                  children: [
                    for (final scope in _ProjectScope.values)
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
    final all = widget.store.projects;
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
        for (final lang in ProjectLanguages.all.where((l) => l != '空项目'))
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
          ? (searching
                ? const _EmptySearchResult()
                : _EmptyState(onCreate: () => _createProject(context)))
          : _buildGridOrList(context, projects);
      return Column(
        children: [
          // 高度随内容收缩；左右 12 与卡片外边距、TabBar labelPadding 对齐。
          // 下边距为 0：下方列表自带 8 的顶部内边距，避免叠成 16 的双倍空隙。
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(children: chipList),
          ),
          Expanded(child: body),
        ],
      );
    }
    if (projects.isEmpty) {
      return switch (scope) {
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
    }
    return _buildGridOrList(context, projects);
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
        var template = ProjectTemplate.empty;
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
                    for (final t in ProjectTemplate.values)
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

/// 我的 Tab：背景图个人头部（左头像右昵称）+ 统计 + 少量入口。
class ProfileTab extends StatefulWidget {
  const ProfileTab({
    super.key,
    required this.auth,
    required this.settings,
  });

  final AuthStore auth;
  final SettingsStore settings;

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  int? _postCount;

  @override
  void initState() {
    super.initState();
    widget.auth.addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    widget.auth.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    if (widget.auth.isLoggedIn) {
      _loadStats();
    } else {
      if (mounted) setState(() => _postCount = null);
    }
  }

  Future<void> _loadStats() async {
    final token = widget.auth.token;
    if (token == null || ApiClient.instance == null) return;
    try {
      final result = await ApiClient.instance!.meWithStats(token);
      if (!mounted) return;
      setState(() => _postCount = result.posts);
    } on ApiException {
      // 网络异常不打断页面。
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListenableBuilder(
        listenable: Listenable.merge([widget.auth, widget.settings]),
        builder: (context, _) {
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              _buildHeader(context),
              const SizedBox(height: 12),
              if (widget.auth.isLoggedIn) ...[
                _buildEntry(
                  context,
                  icon: Icons.local_fire_department_outlined,
                  title: '签到任务',
                  subtitle:
                      '已连签 ${widget.auth.user!.checkinStreak} 天',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => TasksPage(auth: widget.auth)),
                  ),
                ),
                _buildEntry(
                  context,
                  icon: Icons.article_outlined,
                  title: '我的帖子',
                  subtitle: _postCount == null ? '' : '共 $_postCount 篇',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => MyPostsPage(auth: widget.auth)),
                  ),
                ),
                if (widget.auth.user!.isAdmin)
                  _buildEntry(
                    context,
                    icon: Icons.history_outlined,
                    title: '操作审计',
                    subtitle: '全平台敏感操作日志（管理员）',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => AuditPage(auth: widget.auth)),
                    ),
                  ),
              ],
              _buildEntry(
                context,
                icon: Icons.settings_outlined,
                title: '设置',
                subtitle: '外观 · AI 接口 · 服务器 · 存储',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SettingsPage(
                      settings: widget.settings,
                      auth: widget.auth,
                    ),
                  ),
                ),
              ),
              if (widget.auth.isLoggedIn)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: scheme(context).error,
                      side: BorderSide(
                          color: scheme(context).error.withValues(alpha: 0.4)),
                    ),
                    onPressed: () => _confirmSignOut(context),
                    icon: const Icon(Icons.logout),
                    label: const Text('退出登录'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  ColorScheme scheme(BuildContext context) => Theme.of(context).colorScheme;

  /// 顶部背景区：渐变背景图位 + 左头像右昵称 + 统计行。
  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final loggedIn = widget.auth.isLoggedIn;
    final user = widget.auth.user;
    return Container(
      decoration: BoxDecoration(
        // 背景图位：暂用品牌渐变，之后可换成用户自定义封面图。
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary,
            scheme.tertiary.withValues(alpha: 0.9),
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: loggedIn ? () => _editProfile(context) : null,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.35),
                      ),
                      child: loggedIn
                          ? Avatar(
                              name: user!.nickname,
                              color: user.avatarColor,
                              size: 64,
                            )
                          : CircleAvatar(
                              radius: 32,
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.3),
                              child: const Icon(
                                Icons.person_outline,
                                size: 36,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: loggedIn ? () => _editProfile(context) : null,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            loggedIn ? user!.nickname : '未登录',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            loggedIn ? '@${user!.username}' : '点击头像登录账号',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (!loggedIn)
                    FilledButton.tonal(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.25),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => LoginPage(auth: widget.auth)),
                      ),
                      child: const Text('登录'),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              // 统计行
              Row(
                children: [
                  _stat(context, '积分', loggedIn ? '${user!.points}' : '-'),
                  _statDivider(),
                  _stat(context,
                      '连签', loggedIn ? '${user!.checkinStreak} 天' : '-'),
                  _statDivider(),
                  _stat(context, '发帖',
                      loggedIn ? '${_postCount ?? 0}' : '-'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(BuildContext context, String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.8),
                ),
          ),
        ],
      ),
    );
  }

  Widget _statDivider() {
    return Container(
      width: 1,
      height: 24,
      color: Colors.white.withValues(alpha: 0.3),
    );
  }

  Widget _buildEntry(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Card.filled(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          leading: Icon(icon, color: scheme.primary),
          title: Text(title),
          subtitle:
              subtitle.isEmpty ? null : Text(subtitle, maxLines: 1),
          trailing:
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
          onTap: onTap,
        ),
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('退出登录？'),
        content: const Text('本地项目与草稿不受影响。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('退出'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.auth.signOut();
    }
  }

  Future<void> _editProfile(BuildContext context) async {
    final user = widget.auth.user!;
    final nickname = TextEditingController(text: user.nickname);
    final bio = TextEditingController(text: user.bio);
    final updated = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑资料'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nickname,
              maxLength: 24,
              decoration: const InputDecoration(
                labelText: '昵称',
                prefixIcon: Icon(Icons.badge_outlined),
                counterText: '',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: bio,
              maxLength: 200,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: '个性签名',
                alignLabelWithHint: true,
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (updated != true) return;
    try {
      await widget.auth.updateProfile(nickname: nickname.text, bio: bio.text);
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }
}
