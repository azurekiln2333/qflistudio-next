import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/api_client.dart';
import '../../store/auth_store.dart';
import 'register_page.dart';

/// 登录页：账号密码 + azurekiln-oauth2 网关 + 华为账号（仅鸿蒙设备）。
class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.auth});

  final AuthStore auth;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (_username.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = '请输入用户名和密码');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ApiClient.instance.login(
        _username.text.trim(),
        _password.text,
      );
      await widget.auth.signIn(result.token, result.user);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _oauth2Login() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final url = await ApiClient.instance.oauth2Url();
      if (!mounted) return;
      final code = await _showCodeInputDialog(url);
      if (code == null || code.isEmpty) return;
      final result = await ApiClient.instance.oauth2Complete(code.trim());
      await widget.auth.signIn(result.token, result.user);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 打开授权页说明，并让用户粘贴回调页展示的登录码。
  Future<String?> _showCodeInputDialog(String authorizeUrl) {
    return showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('AZK 账号登录'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '1. 复制授权页链接，在浏览器中打开并登录\n2. 授权后页面会显示一个登录码\n3. 将登录码填入下方',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      authorizeUrl,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '复制授权链接',
                    onPressed: () =>
                        Clipboard.setData(ClipboardData(text: authorizeUrl)),
                    icon: const Icon(Icons.copy, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: '登录码',
                  prefixIcon: Icon(Icons.password_outlined),
                ),
                textCapitalization: TextCapitalization.characters,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('登录'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _huaweiLogin() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      const channel = MethodChannel('qflistudio/huawei_account');
      final code = await channel.invokeMethod<String>('login');
      if (!mounted) return;
      if (code == null || code.isEmpty) {
        setState(() => _error = '华为账号登录未完成');
        return;
      }
      final result = await ApiClient.instance.huaweiLogin(code);
      await widget.auth.signIn(result.token, result.user);
      if (mounted) Navigator.of(context).pop(true);
    } on MissingPluginException {
      if (mounted) setState(() => _error = '华为账号登录仅支持鸿蒙设备');
    } on PlatformException catch (e) {
      if (mounted) setState(() => _error = '华为账号登录失败：${e.message}');
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('登录')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 36,
                    backgroundColor: scheme.primaryContainer,
                    foregroundColor: scheme.onPrimaryContainer,
                    child: const Icon(Icons.code_rounded, size: 36),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  '欢迎回到 QFLIStudio+',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _username,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: '用户名',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _password,
                  obscureText: true,
                  onSubmitted: (_) => _submit(),
                  decoration: const InputDecoration(
                    labelText: '密码',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
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
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(_busy ? '登录中…' : '登录'),
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () async {
                          final registered = await Navigator.of(context)
                              .push<bool>(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      RegisterPage(auth: widget.auth),
                                ),
                              );
                          if (registered == true && context.mounted) {
                            Navigator.of(context).pop(true);
                          }
                        },
                  child: const Text('没有账号？注册一个'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        '或',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _oauth2Login,
                  icon: const Icon(Icons.key_outlined),
                  label: const Text('AZK 账号登录（OAuth2）'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _huaweiLogin,
                  icon: const Icon(Icons.account_circle_outlined),
                  label: const Text('华为账号登录'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
