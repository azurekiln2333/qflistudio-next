import 'package:flutter/material.dart';

import '../community/community_widgets.dart';
import '../services/api_client.dart';
import '../store/auth_store.dart';
import 'community/post_detail_page.dart';

/// 我的帖子：最近 50 篇，点击进入详情。
class MyPostsPage extends StatefulWidget {
  const MyPostsPage({super.key, required this.auth});

  final AuthStore auth;

  @override
  State<MyPostsPage> createState() => _MyPostsPageState();
}

class _MyPostsPageState extends State<MyPostsPage> {
  List<Map<String, dynamic>>? _posts;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final token = widget.auth.token;
    if (token == null) {
      setState(() => _error = '请先登录');
      return;
    }
    try {
      final posts = await ApiClient.instance.myPosts(token);
      if (!mounted) return;
      setState(() => _posts = posts);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('我的帖子')),
      body: _posts == null && _error == null
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton.tonal(onPressed: _load, child: const Text('重试')),
                ],
              ),
            )
          : _posts!.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.post_add_outlined,
                    size: 56,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 12),
                  const Text('还没有发布过帖子'),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: _posts!.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final post = _posts![i];
                  return Card.filled(
                    margin: EdgeInsets.zero,
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      title: Text(
                        post['title'] as String? ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${post['type'] == 'tutorial' ? '教程' : '讨论'}'
                        ' · ${post['zoneName'] ?? ''}'
                        ' · ${relativeTime(post['createdAt'] as String? ?? '')}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(
                        Icons.chevron_right,
                        color: Colors.transparent,
                      ),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PostDetailPage(
                            postId: (post['id'] as num).toInt(),
                            auth: widget.auth,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
