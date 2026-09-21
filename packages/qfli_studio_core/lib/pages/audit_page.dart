import 'package:flutter/material.dart';

import '../community/community_widgets.dart';
import '../services/api_client.dart';
import '../store/auth_store.dart';

/// 操作审计（仅管理员）：分页倒序查看全部敏感操作日志。
class AuditPage extends StatefulWidget {
  const AuditPage({super.key, required this.auth});

  final AuthStore auth;

  @override
  State<AuditPage> createState() => _AuditPageState();
}

class _AuditPageState extends State<AuditPage> {
  final _scrollController = ScrollController();
  final _items = <Map<String, dynamic>>[];
  int _page = 1;
  int _total = 0;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels <
        _scrollController.position.maxScrollExtent - 300) {
      return;
    }
    if (_loading || _items.length >= _total) return;
    _load(loadMore: true);
  }

  Future<void> _load({bool loadMore = false}) async {
    final token = widget.auth.token;
    if (token == null) {
      setState(() => _error = '请先登录');
      return;
    }
    setState(() {
      if (loadMore) {
        _loading = true;
      } else {
        _loading = true;
        _error = null;
      }
    });
    try {
      final result = await ApiClient.instance.auditLogs(
        token,
        page: loadMore ? _page + 1 : 1,
      );
      if (!mounted) return;
      setState(() {
        if (loadMore) {
          _items.addAll(result.items);
          _page += 1;
        } else {
          _items
            ..clear()
            ..addAll(result.items);
          _page = 1;
        }
        _total = result.total;
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

  IconData _iconFor(String action) {
    if (action.startsWith('auth.')) return Icons.vpn_key_outlined;
    if (action.startsWith('terminal.')) return Icons.terminal_outlined;
    if (action.startsWith('cloud.git')) return Icons.account_tree_outlined;
    if (action.startsWith('cloud.')) return Icons.cloud_outlined;
    if (action.startsWith('post.')) return Icons.article_outlined;
    if (action.startsWith('comment.')) return Icons.chat_bubble_outline;
    if (action.startsWith('user.')) return Icons.person_outline;
    return Icons.history;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('操作审计（$_total）'),
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: () => _load(),
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 48,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 12),
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton.tonal(
                    onPressed: () => _load(),
                    child: const Text('重试'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: () => _load(),
              child: ListView.separated(
                controller: _scrollController,
                padding: const EdgeInsets.all(12),
                itemCount: _items.length + (_items.length < _total ? 1 : 0),
                separatorBuilder: (_, _) => const SizedBox(height: 6),
                itemBuilder: (context, i) {
                  if (i >= _items.length) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final log = _items[i];
                  final action = log['action'] as String? ?? '';
                  final detail = log['detail'] as String? ?? '';
                  return Card.filled(
                    margin: EdgeInsets.zero,
                    child: ListTile(
                      leading: Icon(
                        _iconFor(action),
                        size: 22,
                        color: scheme.primary,
                      ),
                      title: Text(
                        action,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontFamily: 'Consolas',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (detail.isNotEmpty)
                            Text(
                              detail,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(fontFamily: 'Consolas'),
                            ),
                          Text(
                            '${log['username'] ?? '-'} · '
                            '${log['ip'] ?? ''} · '
                            '${relativeTime(log['createdAt'] as String? ?? '')}',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
