import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../services/ai_service.dart';
import '../store/settings_store.dart';

/// 打开 AI 设置对话框并在确认后保存到 [SettingsStore]。
/// 接口地址 / API Key / 模型全部支持自定义（任何 OpenAI 兼容服务）。
Future<void> editAiSettings(
  BuildContext context,
  SettingsStore settings,
) async {
  final baseUrl = TextEditingController(text: settings.aiBaseUrl);
  final apiKey = TextEditingController(text: settings.aiApiKey);
  final model = TextEditingController(text: settings.aiModel);
  final saved = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('AI 接口设置'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: baseUrl,
              decoration: const InputDecoration(
                labelText: '接口地址（OpenAI 兼容）',
                helperText: '如 https://api.deepseek.com 或 http://127.0.0.1:11434/v1',
                prefixIcon: Icon(Icons.dns_outlined),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: apiKey,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'API Key（本地服务可留空）',
                prefixIcon: Icon(Icons.key_outlined),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: model,
              decoration: const InputDecoration(
                labelText: '模型名称',
                helperText: '如 deepseek-chat / glm-4-flash / qwen2.5-coder:7b',
                prefixIcon: Icon(Icons.memory_outlined),
              ),
            ),
          ],
        ),
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
  if (saved == true) {
    await settings.saveAi(
      baseUrl: baseUrl.text.trim(),
      apiKey: apiKey.text.trim(),
      model: model.text.trim(),
    );
  }
}

/// AI 助手面板（编辑器底部）：流式对话 + 生成代码一键保存为项目文件。
class AiPanel extends StatefulWidget {
  const AiPanel({
    super.key,
    required this.projectPath,
    required this.projectName,
    required this.language,
    required this.settings,
    this.onClose,
    this.onCollapseChanged,
    this.onFileCreated,
  });

  final String projectPath;
  final String projectName;
  final String language;

  /// AI 接口配置（接口地址/密钥/模型）。
  final SettingsStore settings;

  final VoidCallback? onClose;
  final ValueChanged<bool>? onCollapseChanged;

  /// AI 生成的文件保存成功后回调（编辑器打开该文件）。
  final ValueChanged<String>? onFileCreated;

  @override
  State<AiPanel> createState() => AiPanelState();
}

class _ChatMessage {
  _ChatMessage.user(this.content)
      : isUser = true,
        generating = false;
  _ChatMessage.assistant(this.content, {this.generating = false})
      : isUser = false;

  final bool isUser;
  String content;
  bool generating;
}

class AiPanelState extends State<AiPanel> {
  final _messages = <_ChatMessage>[];
  final _inputController = TextEditingController();
  final _listController = ScrollController();
  bool _generating = false;
  bool _collapsed = false;

  bool get _configured =>
      widget.settings.aiBaseUrl.trim().isNotEmpty &&
      widget.settings.aiModel.trim().isNotEmpty;

  String get _systemPrompt =>
      '你是 QFLIStudio+ 内置的 AI 编程助手，运行在移动端代码编辑器中。'
      '当前项目：${widget.projectName}（语言：${widget.language.isEmpty ? "未指定" : widget.language}）。\n'
      '回答使用中文，简洁直接。需要创建或修改文件时，用如下格式给出完整文件内容：\n'
      '```语言:相对路径\n代码\n```\n'
      '例如：```python:src/main.py。路径相对项目根目录，推荐放在 src/ 下。'
      '文件内容必须完整，不要用省略号截断代码。';

  @override
  void dispose() {
    _inputController.dispose();
    _listController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _generating) return;
    _inputController.clear();
    setState(() {
      _messages.add(_ChatMessage.user(text));
      _messages.add(_ChatMessage.assistant('', generating: true));
      _generating = true;
    });
    _scrollToBottom();

    final requestMessages = <({String role, String content})>[
      for (final m in _messages)
        if (!m.generating && m.content.isNotEmpty)
          (role: m.isUser ? 'user' : 'assistant', content: m.content),
    ]..removeLast(); // 移除刚追加的空 assistant

    final assistant = _messages.last;
    final buffer = StringBuffer();
    try {
      await for (final piece in AiService.chat(
        baseUrl: widget.settings.aiBaseUrl,
        apiKey: widget.settings.aiApiKey,
        model: widget.settings.aiModel,
        messages: requestMessages,
        systemPrompt: _systemPrompt,
      )) {
        buffer.write(piece);
        if (mounted) {
          setState(() => assistant.content = buffer.toString());
        }
        _scrollToBottom();
      }
      assistant.generating = false;
    } on AiException catch (e) {
      assistant.generating = false;
      final note = '⚠ ${e.message}';
      assistant.content =
          assistant.content.isEmpty ? note : '${assistant.content}\n\n$note';
    } finally {
      if (mounted) {
        setState(() => _generating = false);
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_listController.hasClients) {
        _listController.jumpTo(_listController.position.maxScrollExtent);
      }
    });
  }

  /// 把 AI 代码块保存为项目内文件（路径安全校验）。
  Future<void> _saveBlock(AiSegment block) async {
    var relative = block.path;
    if (relative == null || relative.isEmpty) {
      if (!mounted) return;
      final name = await _askFileName();
      if (name == null || name.isEmpty || !mounted) return;
      relative = name;
    }
    relative = relative.replaceAll('\\', '/');
    if (relative.startsWith('/') || relative.split('/').contains('..')) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('路径非法')));
      return;
    }
    final fullPath = p.join(widget.projectPath, relative);
    try {
      await File(fullPath).parent.create(recursive: true);
      await File(fullPath).writeAsString(block.code ?? '', flush: true);
    } on FileSystemException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('保存失败：${e.message}')));
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已保存 $relative')),
    );
    widget.onFileCreated?.call(fullPath);
  }

  Future<String?> _askFileName() {
    final controller = TextEditingController(text: 'src/new_file.');
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('保存为文件'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '相对路径（含扩展名）',
            prefixIcon: Icon(Icons.edit_outlined),
          ),
          onSubmitted: (v) => Navigator.of(context).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (_collapsed) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() => _collapsed = false);
          widget.onCollapseChanged?.call(false);
        },
        child: Container(
          height: 36,
          color: scheme.surfaceContainerHigh,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(Icons.auto_awesome, size: 16, color: scheme.primary),
              const SizedBox(width: 8),
              Text(
                'AI 助手（已收起，点击展开）',
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const Spacer(),
              IconButton(
                tooltip: '关闭',
                visualDensity: VisualDensity.compact,
                onPressed: widget.onClose,
                icon: const Icon(Icons.close, size: 18),
              ),
            ],
          ),
        ),
      );
    }
    return ListenableBuilder(
      listenable: widget.settings,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            color: scheme.surfaceContainerHigh,
            child: Row(
              children: [
                Icon(Icons.auto_awesome, size: 16, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.settings.aiModel.isEmpty
                        ? 'AI 助手（未配置接口）'
                        : 'AI 助手 · ${widget.settings.aiModel}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
                IconButton(
                  tooltip: 'AI 接口设置',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => editAiSettings(context, widget.settings),
                  icon: const Icon(Icons.settings_outlined, size: 18),
                ),
                IconButton(
                  tooltip: '收起',
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    setState(() => _collapsed = true);
                    widget.onCollapseChanged?.call(true);
                  },
                  icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                ),
                IconButton(
                  tooltip: '关闭',
                  visualDensity: VisualDensity.compact,
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close, size: 18),
                ),
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: scheme.outlineVariant),
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Text(
                      _configured
                          ? '描述你想生成的代码或文件，例如：\n"写一个 Python 脚本，读取 numbers.txt 里的数字求平均值"'
                          : '先点右上角 ⚙ 配置 AI 接口（支持 DeepSeek / 智谱 /\nKimi / Ollama 等任何 OpenAI 兼容接口）',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            height: 1.6,
                          ),
                    ),
                  )
                : ListView.builder(
                    controller: _listController,
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length,
                    itemBuilder: (context, i) =>
                        _buildMessage(context, _messages[i]),
                  ),
          ),
          Divider(height: 1, thickness: 1, color: scheme.outlineVariant),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      minLines: 1,
                      maxLines: 4,
                      enabled: !_generating,
                      style: Theme.of(context).textTheme.bodyMedium,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: '描述要生成的代码或文件…',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor:
                            scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: _generating ? '生成中…' : '发送',
                    onPressed: _generating ? null : _send,
                    icon: _generating
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

  Widget _buildMessage(BuildContext context, _ChatMessage message) {
    final scheme = Theme.of(context).colorScheme;
    if (message.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10, left: 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: SelectableText(
            message.content,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: scheme.onPrimaryContainer),
          ),
        ),
      );
    }
    final segments = AiService.parseSegments(message.content);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, right: 24),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final segment in segments)
              if (segment.isCode)
                _buildCodeBlock(context, segment)
              else if (segment.text!.trim().isNotEmpty)
                SelectableText(
                  segment.text!,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
            if (message.generating)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '生成中…',
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCodeBlock(BuildContext context, AiSegment segment) {
    final scheme = Theme.of(context).colorScheme;
    final label = (segment.path != null && segment.path!.isNotEmpty)
        ? segment.path!
        : (segment.lang ?? '代码');
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(
              children: [
                Icon(Icons.code, size: 14, color: scheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
                IconButton(
                  tooltip: '复制代码',
                  visualDensity: VisualDensity.compact,
                  onPressed: () =>
                      Clipboard.setData(ClipboardData(text: segment.code ?? '')),
                  icon: const Icon(Icons.content_copy_outlined, size: 16),
                ),
                IconButton(
                  tooltip: '保存为项目文件',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _saveBlock(segment),
                  icon: const Icon(Icons.save_outlined, size: 16),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 140,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(8),
              child: SelectableText(
                segment.code ?? '',
                style: TextStyle(
                  fontFamily: 'Consolas',
                  fontFamilyFallback: const ['Courier New', 'monospace'],
                  fontSize: 12,
                  height: 1.45,
                  color: scheme.onSurface,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
