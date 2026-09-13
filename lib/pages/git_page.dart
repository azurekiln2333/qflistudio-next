import 'dart:io';

import 'package:flutter/material.dart';

import '../models/project.dart';
import '../services/api_client.dart';
import '../services/cloud_sync_service.dart';
import '../services/git_service.dart';
import '../store/auth_store.dart';

/// Git 页：本地项目（桌面）走本机 git CLI；云端项目走服务器 git。
class GitPage extends StatefulWidget {
  const GitPage({super.key, required this.project, required this.auth});

  final Project project;
  final AuthStore auth;

  @override
  State<GitPage> createState() => _GitPageState();
}

class _GitPageState extends State<GitPage> {
  CloudSyncService? _cloud;
  final List<_TermLine> _lines = [];
  final _listController = ScrollController();
  final _commitController = TextEditingController();
  final _remoteController = TextEditingController();
  bool _busy = false;

  bool get _cloudMode => widget.project.isCloud;

  @override
  void dispose() {
    _cloud?.dispose();
    _commitController.dispose();
    _remoteController.dispose();
    _listController.dispose();
    super.dispose();
  }

  void _append(String text, {bool isError = false}) {
    setState(() {
      _lines.add(_TermLine(text: text, isError: isError));
      if (_lines.length > 400) _lines.removeRange(0, _lines.length - 400);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_listController.hasClients) {
        _listController.jumpTo(_listController.position.maxScrollExtent);
      }
    });
  }

  Future<void> _runLocal(String label, Future<GitResult> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    _append('\$ git $label');
    final result = await action();
    if (result.stdout.trim().isNotEmpty) _append(result.stdout.trimRight());
    if (result.stderr.trim().isNotEmpty) {
      _append(result.stderr.trimRight(), isError: true);
    }
    _append(result.exitCode == 0 ? '（完成）' : '（退出码 ${result.exitCode}）');
    setState(() => _busy = false);
  }

  Future<void> _runCloud(String action, {String? message, String? url}) async {
    if (_busy) return;
    final token = widget.auth.token;
    if (token == null) {
      _append('云端 git 需要先登录', isError: true);
      return;
    }
    setState(() => _busy = true);
    final suffix = message == null ? '' : ' "$message"';
    _append('git $action$suffix');
    try {
      _cloud ??= await CloudSyncService.open(
        cloudId: int.parse(widget.project.cloudId!),
        name: widget.project.name,
      );
      final result = await _cloud!.git(token, action, message: message, url: url);
      if (result.stdout.trim().isNotEmpty) _append(result.stdout.trimRight());
      if (result.stderr.trim().isNotEmpty) {
        _append(result.stderr.trimRight(), isError: true);
      }
      _append(result.exitCode == 0 ? '（完成）' : '（退出码 ${result.exitCode}）');
    } on ApiException catch (e) {
      _append(e.message, isError: true);
    } on FileSystemException catch (e) {
      _append('本地镜像打开失败：${e.message}', isError: true);
    }
    setState(() => _busy = false);
  }

  Future<void> _commitDialog() async {
    final message = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('提交到 Git'),
        content: TextField(
          controller: _commitController,
          autofocus: true,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: '提交信息',
            prefixIcon: Icon(Icons.edit_note_outlined),
          ),
          onSubmitted: (v) => Navigator.of(context).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_commitController.text),
            child: const Text('提交'),
          ),
        ],
      ),
    );
    if (message == null || message.trim().isEmpty) return;
    if (_cloudMode) {
      await _runCloud('addAll');
      await _runCloud('commit', message: message.trim());
    } else {
      await _runLocal('git add -A', () => GitService.run(widget.project.path, ['add', '-A']));
      await _runLocal(
        'git commit -m "${message.trim()}"',
        () => GitService.run(widget.project.path, ['commit', '-m', message.trim()]),
      );
    }
    _commitController.clear();
  }

  Future<void> _remoteDialog() async {
    final url = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('设置远程仓库'),
        content: TextField(
          controller: _remoteController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '仓库地址（https）',
            prefixIcon: Icon(Icons.link_outlined),
            hintText: 'https://github.com/user/repo.git',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_remoteController.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (url == null || url.trim().isEmpty) return;
    if (_cloudMode) {
      await _runCloud('remote', url: url.trim());
    } else {
      await _runLocal(
        'git remote add origin',
        () => GitService.setRemote(widget.project.path, url.trim()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final desktop = GitService.isSupported;
    final canLocalGit = !_cloudMode && desktop;
    final canGit = _cloudMode || canLocalGit;
    return Scaffold(
      appBar: AppBar(
        title: Text('Git · ${widget.project.name}'),
        actions: [
          if (!_cloudMode && !desktop)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Icon(Icons.warning_amber_outlined),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Row(
              children: [
                Text(
                  _cloudMode ? '云端项目 · 服务器执行 git' : (desktop ? '本地项目 · 本机 git' : '当前平台无 git，请使用在线终端'),
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (canGit) ...[
                  FilledButton.tonalIcon(
                    onPressed: _busy ? null : _commitDialog,
                    icon: const Icon(Icons.commit_outlined, size: 18),
                    label: const Text('提交'),
                  ),
                  OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => _cloudMode
                            ? _runCloud('status')
                            : _runLocal('git status', () => GitService.status(widget.project.path)),
                    child: const Text('状态'),
                  ),
                  OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => _cloudMode
                            ? _runCloud('log')
                            : _runLocal('git log', () => GitService.log(widget.project.path)),
                    child: const Text('历史'),
                  ),
                  OutlinedButton(
                    onPressed: _busy ? null : _remoteDialog,
                    child: const Text('远程仓库'),
                  ),
                  OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => _cloudMode
                            ? _runCloud('push')
                            : _runLocal('git push', () => GitService.push(widget.project.path)),
                    child: const Text('推送'),
                  ),
                  OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => _cloudMode
                            ? _runCloud('pull')
                            : _runLocal('git pull', () => GitService.pull(widget.project.path)),
                    child: const Text('拉取'),
                  ),
                  if (!_cloudMode)
                    OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () => _runLocal('git init', () => GitService.init(widget.project.path)),
                      child: const Text('init'),
                    ),
                ],
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: scheme.outlineVariant),
          Expanded(
            child: _lines.isEmpty
                ? Center(
                    child: Text(
                      canGit ? '选择上面的 git 操作，输出会显示在这里' : '此平台无法本地使用 git',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  )
                : ListView.builder(
                    controller: _listController,
                    padding: const EdgeInsets.all(12),
                    itemCount: _lines.length,
                    itemBuilder: (context, i) => SelectableText(
                      _lines[i].text,
                      style: TextStyle(
                        fontFamily: 'Consolas',
                        fontFamilyFallback: const ['Courier New', 'monospace'],
                        fontSize: 12.5,
                        height: 1.45,
                        color: _lines[i].isError ? scheme.error : scheme.onSurface,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _TermLine {
  const _TermLine({required this.text, required this.isError});

  final String text;
  final bool isError;
}
