import 'package:flutter/material.dart';

import '../../community/community_widgets.dart';
import '../../community/models.dart';
import '../../services/api_client.dart';
import '../../store/auth_store.dart';
import 'post_detail_page.dart';
import 'publish_page.dart';

/// 帖子列表页：教程 / 讨论共用。
/// 专区筛选 + 标签筛选 + 搜索 + 分页。
class PostListPage extends StatefulWidget {
  const PostListPage({super.key, required this.type, required this.auth});

  /// 'tutorial' 或 'discussion'。
  final String type;
  final AuthStore auth;

  @override
  State<PostListPage> createState() => PostListPageState();
}

class PostListPageState extends State<PostListPage> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  List<Zone> _zones = [];
  List<TagCount> _tags = [];
  final List<Post> _posts = [];

  int? _selectedZone;
  String? _selectedTag;
  String _keyword = '';
  bool _searchOpen = false;
  int _page = 1;
  int _total = 0;
  bool _loading = false;
  bool _loadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialLoad());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels <
        _scrollController.position.maxScrollExtent - 300) {
      return;
    }
    if (_loadingMore || _loading || _posts.length >= _total) return;
    _loadMore();
  }

  Future<void> _initialLoad() async {
    if (!mounted) return;
    await _refresh();
  }

  Future<void> _refresh() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final client = ApiClient.instance;
      final results = await Future.wait([
        client.zones(),
        client.tags(type: widget.type, zoneId: _selectedZone),
        client.posts(
          type: widget.type,
          zoneId: _selectedZone,
          tag: _selectedTag,
          keyword: _keyword,
          token: widget.auth.token,
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _zones = results[0] as List<Zone>;
        _tags = results[1] as List<TagCount>;
        final postsResult = results[2] as ({List<Post> items, int total});
        _posts
          ..clear()
          ..addAll(postsResult.items);
        _total = postsResult.total;
        _page = 1;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (!mounted) return;
    setState(() => _loadingMore = true);
    try {
      final result = await ApiClient.instance.posts(
        type: widget.type,
        zoneId: _selectedZone,
        tag: _selectedTag,
        keyword: _keyword,
        page: _page + 1,
        token: widget.auth.token,
      );
      if (!mounted) return;
      setState(() {
        _posts.addAll(result.items);
        _total = result.total;
        _page += 1;
        _loadingMore = false;
      });
    } on ApiException {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  Future<void> _setZone(int? zoneId) async {
    setState(() => _selectedZone = zoneId);
    await _refresh();
  }

  Future<void> _setTag(String? tag) async {
    setState(() => _selectedTag = tag);
    await _refresh();
  }

  Future<void> _setKeyword(String keyword) async {
    _keyword = keyword;
    await _refresh();
  }

  Future<void> _publish() async {
    if (widget.auth.isLoggedIn) {
      final created = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => PublishPage(type: widget.type, auth: widget.auth),
        ),
      );
      if (created == true) await _refresh();
      return;
    }
    _promptLogin();
  }

  void _promptLogin() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('请先到「我的」页登录')));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isTutorial = widget.type == 'tutorial';
    return Scaffold(
      appBar: AppBar(
        leading: _searchOpen
            ? IconButton(
                tooltip: '退出搜索',
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    _searchOpen = false;
                    _keyword = '';
                    _searchController.clear();
                  });
                  _setKeyword('');
                },
              )
            : null,
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: _searchOpen
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: '搜索${isTutorial ? '教程' : '讨论'}标题与内容',
                  prefixIcon: const Icon(Icons.search),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                onSubmitted: _setKeyword,
              )
            : Text(isTutorial ? '教程' : '讨论'),
        actions: [
          if (!_searchOpen)
            IconButton(
              tooltip: '搜索',
              icon: const Icon(Icons.search),
              onPressed: () => setState(() => _searchOpen = true),
            ),
          if (widget.auth.isLoggedIn)
            IconButton(
              tooltip: '发布',
              icon: const Icon(Icons.add_circle_outline),
              onPressed: _publish,
            )
          else
            IconButton(
              tooltip: '登录后可发布',
              icon: const Icon(Icons.add_circle_outline),
              onPressed: _promptLogin,
            ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: widget.auth.isLoggedIn
          ? FloatingActionButton.extended(
              onPressed: _publish,
              icon: const Icon(Icons.edit_note_outlined),
              label: Text(isTutorial ? '写教程' : '发起讨论'),
            )
          : null,
      body: Column(
        children: [
          if (_zones.isNotEmpty) _buildZoneChips(context),
          if (_tags.isNotEmpty) _buildTagRow(context),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(
                    Icons.cloud_off_outlined,
                    size: 48,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 12),
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton.tonal(
                    onPressed: _refresh,
                    child: const Text('重试'),
                  ),
                ],
              ),
            )
          else
            Expanded(child: _buildList(context)),
        ],
      ),
    );
  }

  Widget _buildZoneChips(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: [
          ChoiceChip(
            label: const Text('全部'),
            selected: _selectedZone == null,
            onSelected: (_) => _setZone(null),
          ),
          for (final zone in _zones) ...[
            const SizedBox(width: 8),
            ChoiceChip(
              label: Text(zone.name),
              selected: _selectedZone == zone.id,
              onSelected: (_) => _setZone(zone.id),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTagRow(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          Icon(Icons.tag, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: 2),
          for (final t in _tags) ...[
            ActionChip(
              label: Text(t.tag),
              labelStyle: Theme.of(context).textTheme.labelSmall,
              visualDensity: VisualDensity.compact,
              onPressed: () => _setTag(_selectedTag == t.tag ? null : t.tag),
            ),
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_posts.isEmpty) {
      final keywordEmpty =
          _keyword.isNotEmpty || _selectedTag != null || _selectedZone != null;
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              keywordEmpty ? Icons.search_off : Icons.post_add_outlined,
              size: 56,
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(keywordEmpty ? '没有匹配的内容' : '还没有内容，发布第一篇吧'),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
        itemCount: _posts.length + (_posts.length < _total ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          if (i >= _posts.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final post = _posts[i];
          return PostCard(
            post: post,
            onOpen: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      PostDetailPage(postId: post.id, auth: widget.auth),
                ),
              );
              await _refresh();
            },
          );
        },
      ),
    );
  }
}
