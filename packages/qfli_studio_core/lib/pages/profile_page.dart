import 'dart:async';

import 'package:flutter/material.dart';

import '../community/community_widgets.dart';
import '../services/api_client.dart';
import '../store/auth_store.dart';
import '../store/settings_store.dart';
import '../widgets/settings_section.dart';
import 'audit_page.dart';
import 'auth/login_page.dart';
import 'my_posts_page.dart';
import 'settings_page.dart';
import 'tasks_page.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key, required this.auth, required this.settings});

  final AuthStore auth;
  final SettingsStore settings;

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  int? _postCount;
  String? _lastToken;
  Future<void>? _statsRequest;

  @override
  void initState() {
    super.initState();
    _lastToken = widget.auth.token;
    widget.auth.addListener(_onAuthChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_loadStats());
    });
  }

  @override
  void dispose() {
    widget.auth.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    if (_lastToken == widget.auth.token) return;
    _lastToken = widget.auth.token;
    setState(() => _postCount = null);
    unawaited(_loadStats());
  }

  Future<void> _loadStats() async {
    // 旧账号请求完成后再加载当前账号，避免连续刷新产生重复请求。
    if (_statsRequest != null) await _statsRequest;
    final token = widget.auth.token;
    if (token == null || !mounted) return;
    final request = _fetchStats(token);
    _statsRequest = request;
    await request;
    if (identical(_statsRequest, request)) _statsRequest = null;
  }

  Future<void> _fetchStats(String token) async {
    try {
      final result = await ApiClient.instance.meWithStats(token);
      if (!mounted || widget.auth.token != token) return;
      setState(() => _postCount = result.posts);
    } on ApiException {
      // 离线时保留已有统计，未加载过的数据用占位符表示。
    }
  }

  Future<void> _refresh() async {
    await Future.wait([widget.auth.refreshMe(), _loadStats()]);
  }

  Future<void> _login() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => LoginPage(auth: widget.auth)),
    );
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            SettingsPage(settings: widget.settings, auth: widget.auth),
      ),
    );
  }

  Future<void> _openAccountPage(Widget Function() page) async {
    if (!widget.auth.isLoggedIn) await _login();
    if (!mounted || !widget.auth.isLoggedIn) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page()));
    if (mounted) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的'),
        actions: [
          IconButton(
            tooltip: '设置',
            onPressed: _openSettings,
            icon: const Icon(Icons.settings_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListenableBuilder(
        listenable: widget.auth,
        builder: (context, _) => Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 840),
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  _profileCard(context),
                  const SizedBox(height: 16),
                  if (widget.auth.isLoggedIn) ...[
                    _statistics(context),
                    const SizedBox(height: 24),
                  ],
                  SettingsSection(
                    title: '创作与成长',
                    children: [
                      _entry(
                        icon: Icons.task_alt_outlined,
                        title: '签到任务',
                        subtitle: widget.auth.isLoggedIn
                            ? '已连续签到 ${widget.auth.user!.checkinStreak} 天'
                            : '记录进步，积累积分',
                        onTap: () => _openAccountPage(
                          () => TasksPage(auth: widget.auth),
                        ),
                      ),
                      _entry(
                        icon: Icons.article_outlined,
                        title: '我的帖子',
                        subtitle: '管理发布的教程与讨论',
                        onTap: () => _openAccountPage(
                          () => MyPostsPage(auth: widget.auth),
                        ),
                      ),
                    ],
                  ),
                  SettingsSection(
                    title: '偏好与支持',
                    children: [
                      _entry(
                        icon: Icons.tune_rounded,
                        title: '设置',
                        subtitle: '外观、代码高亮、AI 与存储',
                        onTap: _openSettings,
                      ),
                      _entry(
                        icon: Icons.info_outline,
                        title: '关于 QFLIStudio+',
                        subtitle: '一个轻量、专注的编程空间',
                        onTap: () => showQfliAbout(context),
                      ),
                    ],
                  ),
                  if (widget.auth.user?.isAdmin == true)
                    SettingsSection(
                      title: '管理',
                      children: [
                        _entry(
                          icon: Icons.policy_outlined,
                          title: '操作审计',
                          subtitle: '查看平台操作记录',
                          onTap: () => _openAccountPage(
                            () => AuditPage(auth: widget.auth),
                          ),
                        ),
                      ],
                    ),
                  if (widget.auth.isLoggedIn)
                    Center(
                      child: TextButton.icon(
                        onPressed: _confirmSignOut,
                        icon: const Icon(Icons.logout, size: 18),
                        label: const Text('退出登录'),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    'QFLIStudio+',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _profileCard(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final user = widget.auth.user;
    final loggedIn = widget.auth.isLoggedIn;
    return Card.filled(
      margin: EdgeInsets.zero,
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (loggedIn)
                  Avatar(
                    name: user!.nickname,
                    color: user.avatarColor,
                    size: 60,
                  )
                else
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: scheme.surface,
                    foregroundColor: scheme.primary,
                    child: const Icon(Icons.person_outline, size: 32),
                  ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loggedIn ? user!.nickname : '未登录',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        loggedIn ? '@${user!.username}' : '让灵感与代码同行',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
                if (loggedIn)
                  IconButton(
                    tooltip: '编辑资料',
                    onPressed: _editProfile,
                    color: scheme.onPrimaryContainer,
                    icon: const Icon(Icons.edit_outlined),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              loggedIn
                  ? (user!.bio.isEmpty ? '今天，也写一点喜欢的代码。' : user.bio)
                  : '登录后同步云端项目，分享教程，参与开发者讨论。',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onPrimaryContainer,
              ),
            ),
            if (!loggedIn) ...[
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: _login,
                  icon: const Icon(Icons.login),
                  label: const Text('登录 / 注册'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statistics(BuildContext context) {
    final user = widget.auth.user!;
    return Card.filled(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
        child: Row(
          children: [
            _stat(context, '${user.points}', '积分'),
            _stat(context, '${user.checkinStreak}', '连续签到'),
            _stat(context, '${_postCount ?? '—'}', '发布内容'),
          ],
        ),
      ),
    );
  }

  Widget _stat(BuildContext context, String value, String label) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(value, style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _entry({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) => ListTile(
    leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
    title: Text(title),
    subtitle: Text(subtitle),
    trailing: const Icon(Icons.chevron_right),
    onTap: onTap,
  );

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('退出登录？'),
        content: const Text('本地项目与草稿将继续保留。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('退出'),
          ),
        ],
      ),
    );
    if (confirmed == true) await widget.auth.signOut();
  }

  Future<void> _editProfile() async {
    final user = widget.auth.user!;
    final nickname = TextEditingController(text: user.nickname);
    final bio = TextEditingController(text: user.bio);
    final updated = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑资料'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nickname,
                maxLength: 24,
                decoration: const InputDecoration(labelText: '昵称'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bio,
                maxLength: 200,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: '个性签名',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    final name = nickname.text.trim();
    final signature = bio.text.trim();
    // Dialog 的反向动画完成后再释放输入控制器。
    await Future<void>.delayed(const Duration(milliseconds: 250));
    nickname.dispose();
    bio.dispose();
    if (updated != true || !mounted) return;
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('昵称不能为空')));
      return;
    }
    try {
      await widget.auth.updateProfile(nickname: name, bio: signature);
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }
}
