import 'package:flutter/material.dart';

import '../../community/models.dart';
import '../../services/api_client.dart';
import '../../store/auth_store.dart';

/// 发布页：教程 / 讨论共用。支持 # 标签（最多 5 个）。
class PublishPage extends StatefulWidget {
  const PublishPage({super.key, required this.type, required this.auth});

  final String type;
  final AuthStore auth;

  @override
  State<PublishPage> createState() => _PublishPageState();
}

class _PublishPageState extends State<PublishPage> {
  final _title = TextEditingController();
  final _content = TextEditingController();
  final _tagInput = TextEditingController();
  final _tags = <String>[];
  List<Zone> _zones = [];
  Zone? _zone;
  bool _publishing = false;
  String? _error;

  bool get _isTutorial => widget.type == 'tutorial';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadZones());
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    _tagInput.dispose();
    super.dispose();
  }

  Future<void> _loadZones() async {
    try {
      final zones = await ApiClient.instance.zones();
      if (!mounted) return;
      setState(() {
        _zones = zones;
        _zone = zones.isNotEmpty ? zones.first : null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    }
  }

  void _addTag(String raw) {
    final tag = raw.replaceFirst('#', '').trim();
    if (tag.isEmpty) return;
    if (_tags.contains(tag) || _tags.length >= 5) return;
    if (tag.length > 16) {
      setState(() => _error = '标签最长 16 个字符');
      return;
    }
    setState(() {
      _error = null;
      _tags.add(tag);
      _tagInput.clear();
    });
  }

  Future<void> _submit() async {
    if (_publishing) return;
    final token = widget.auth.token;
    if (token == null) return;
    if (_title.text.trim().length < 2) {
      setState(() => _error = '标题至少 2 个字');
      return;
    }
    if (_content.text.trim().length < 5) {
      setState(() => _error = '内容至少 5 个字');
      return;
    }
    if (_zone == null) {
      setState(() => _error = '请选择专区');
      return;
    }
    setState(() {
      _publishing = true;
      _error = null;
    });
    try {
      await ApiClient.instance.createPost(
        token: token,
        type: widget.type,
        zoneId: _zone!.id,
        title: _title.text.trim(),
        content: _content.text.trim(),
        tags: _tags,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _publishing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isTutorial ? '写教程' : '发起讨论'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              onPressed: _publishing ? null : _submit,
              child: Text(_publishing ? '发布中…' : '发布'),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'tutorial', label: Text('教程')),
              ButtonSegment(value: 'discussion', label: Text('讨论')),
            ],
            selected: {widget.type},
            onSelectionChanged: (_) {}, // 类型由入口决定，这里只展示
            showSelectedIcon: false,
          ),
          const SizedBox(height: 16),
          DropdownMenu<Zone>(
            initialSelection: _zone,
            expandedInsets: EdgeInsets.zero,
            label: const Text('专区'),
            onSelected: (value) => setState(() => _zone = value),
            dropdownMenuEntries: [
              for (final z in _zones)
                DropdownMenuEntry(value: z, label: z.name),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _title,
            maxLength: 80,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: '标题',
              prefixIcon: Icon(Icons.title_outlined),
              counterText: '',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _content,
            minLines: 8,
            maxLines: 16,
            decoration: InputDecoration(
              labelText: _isTutorial ? '教程正文' : '讨论内容',
              alignLabelWithHint: true,
              hintText: _isTutorial ? '分享你的教程，支持多行文本…' : '描述你的问题或想法…',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _tagInput,
            decoration: InputDecoration(
              labelText: '标签（回车添加，最多 5 个）',
              prefixIcon: const Icon(Icons.tag),
              helperText: '如：Java / 入门 / 报错求助',
              suffixIcon: IconButton(
                tooltip: '添加标签',
                icon: const Icon(Icons.add),
                onPressed: () => _addTag(_tagInput.text),
              ),
            ),
            onSubmitted: _addTag,
          ),
          const SizedBox(height: 8),
          if (_tags.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final tag in _tags)
                  InputChip(
                    label: Text('#$tag'),
                    onDeleted: () => setState(() => _tags.remove(tag)),
                  ),
              ],
            ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.error),
            ),
          ],
        ],
      ),
    );
  }
}
