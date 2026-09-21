import 'package:flutter/material.dart';

import '../../community/community_widgets.dart';
import '../../community/models.dart';
import '../../services/api_client.dart';
import '../../services/share_service.dart';
import '../../store/auth_store.dart';

/// 帖子详情：内容 + 点赞 + 分享 + 树形评论与回复。
class PostDetailPage extends StatefulWidget {
  const PostDetailPage({super.key, required this.postId, required this.auth});

  final int postId;
  final AuthStore auth;

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  Post? _post;
  List<Comment> _comments = [];
  final _commentController = TextEditingController();
  Comment? _replyTo;
  bool _loading = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final client = ApiClient.instance;
      final results = await Future.wait([
        client.postDetail(widget.postId, token: widget.auth.token),
        client.comments(widget.postId),
      ]);
      if (!mounted) return;
      setState(() {
        _post = results[0] as Post;
        _comments = results[1] as List<Comment>;
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

  Future<void> _toggleLike() async {
    final token = widget.auth.token;
    if (token == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先登录')));
      return;
    }
    try {
      final result = await ApiClient.instance.toggleLike(token, widget.postId);
      if (!mounted) return;
      setState(() {
        _post = Post(
          id: _post!.id,
          type: _post!.type,
          title: _post!.title,
          excerpt: _post!.excerpt,
          content: _post!.content,
          tags: _post!.tags,
          zoneId: _post!.zoneId,
          zoneName: _post!.zoneName,
          author: _post!.author,
          likeCount: result.likeCount,
          commentCount: _post!.commentCount,
          liked: result.liked,
          createdAt: _post!.createdAt,
        );
      });
    } on ApiException catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _share() async {
    final post = _post!;
    final shared = await ShareService.shareText(
      title: '【${post.type == 'tutorial' ? '教程' : '讨论'}】${post.title}',
      text:
          '【${post.type == 'tutorial' ? '教程' : '讨论'}】${post.title}\n'
          '作者：${post.author.nickname}\n'
          '${post.content}',
    );
    if (!shared && mounted) {
      copyWithToast(
        context,
        '【${post.type == 'tutorial' ? '教程' : '讨论'}】${post.title}\n'
        '作者：${post.author.nickname}\n'
        '${post.content}',
      );
    }
  }

  void _setReplyTo(Comment comment) {
    setState(() => _replyTo = comment);
    FocusScope.of(context).unfocus();
  }

  Future<void> _sendComment() async {
    final token = widget.auth.token;
    if (token == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先登录')));
      return;
    }
    final text = _commentController.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ApiClient.instance.addComment(
        token,
        widget.postId,
        content: text,
        parentId: _replyTo?.id,
      );
      if (!mounted) return;
      setState(() {
        _replyTo = null;
        _commentController.clear();
      });
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _deletePost() async {
    final token = widget.auth.token;
    if (token == null || _post == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除这篇内容？'),
        content: const Text('删除后无法恢复。'),
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
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiClient.instance.deletePost(token, _post!.id);
      if (!mounted) return;
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (_loading) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null || _post == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error ?? '内容不存在'),
              const SizedBox(height: 12),
              FilledButton.tonal(onPressed: _load, child: const Text('重试')),
            ],
          ),
        ),
      );
    }
    final post = _post!;
    final isMine = widget.auth.user?.id == post.author.id;
    return Scaffold(
      appBar: AppBar(
        title: Text(post.type == 'tutorial' ? '教程详情' : '讨论详情'),
        actions: [
          IconButton(
            tooltip: '分享',
            onPressed: _share,
            icon: const Icon(Icons.share_outlined),
          ),
          if (isMine)
            IconButton(
              tooltip: '删除',
              onPressed: _deletePost,
              icon: const Icon(Icons.delete_outline),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  post.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Avatar(
                      name: post.author.nickname,
                      color: post.author.avatarColor,
                      size: 36,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            post.author.nickname,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '${post.zoneName} · ${relativeTime(post.createdAt)}',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SelectableText(
                  post.content,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(height: 1.7),
                ),
                const SizedBox(height: 16),
                if (post.tags.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final tag in post.tags)
                        TagChip(tag: tag, onTap: () {}),
                    ],
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: _toggleLike,
                      icon: Icon(
                        post.liked ? Icons.favorite : Icons.favorite_border,
                        size: 18,
                        color: post.liked ? scheme.error : null,
                      ),
                      label: Text('${post.likeCount}'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: _share,
                      icon: const Icon(Icons.share_outlined, size: 18),
                      label: const Text('分享'),
                    ),
                  ],
                ),
                const Divider(height: 32),
                Text(
                  '评论 (${post.commentCount})',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                CommentTree(
                  comments: _comments,
                  onReply: _setReplyTo,
                  currentUserId: widget.auth.user?.id,
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
          SafeArea(
            child: Container(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                border: Border(top: BorderSide(color: scheme.outlineVariant)),
              ),
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_replyTo != null)
                          Row(
                            children: [
                              Text(
                                '回复 ${_replyTo!.author.nickname}',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(color: scheme.primary),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                onPressed: () =>
                                    setState(() => _replyTo = null),
                                icon: const Icon(Icons.close, size: 14),
                              ),
                            ],
                          ),
                        TextField(
                          controller: _commentController,
                          minLines: 1,
                          maxLines: 4,
                          style: Theme.of(context).textTheme.bodyMedium,
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: widget.auth.isLoggedIn
                                ? '写下你的评论…'
                                : '登录后参与讨论',
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: scheme.surfaceContainerHighest
                                .withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: '发送',
                    onPressed: _sending || !widget.auth.isLoggedIn
                        ? null
                        : _sendComment,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send, size: 18),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
