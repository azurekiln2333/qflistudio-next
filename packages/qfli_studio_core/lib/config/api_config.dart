/// QFLI 官方服务的唯一地址配置。切换部署域名后重新构建应用即可。
/// 账号、社区、云端项目和在线终端都通过这里访问同一服务。
abstract final class ApiConfig {
  static const String baseUrl = 'https://qfli.lqsxm666.top';
  static const Duration requestTimeout = Duration(seconds: 25);

  static Uri endpoint(String path, [Map<String, Object>? query]) {
    if (!path.startsWith('/api/') || path.contains('://')) {
      throw ArgumentError.value(path, 'path', '需要 /api/ 开头的服务路径');
    }
    return Uri.parse('$baseUrl$path').replace(
      queryParameters: query == null || query.isEmpty
          ? null
          : query.map((key, value) => MapEntry(key, value.toString())),
    );
  }

  static String get origin => Uri.parse(baseUrl).origin;

  /// 旧版本可保存任意服务器。只接受同一来源的登录态，避免跨站发送令牌。
  static bool ownsSession(String? source) {
    if (source == null) return false;
    final uri = Uri.tryParse(source);
    return uri != null &&
        uri.hasAuthority &&
        uri.userInfo.isEmpty &&
        uri.origin == origin;
  }
}
