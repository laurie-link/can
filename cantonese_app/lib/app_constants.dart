/// 应用级常量（粤语助手后端等）
class AppConstants {
  AppConstants._();

  /// 对外说明用的默认入口（含 Swagger `/docs`）；与 [backendApiRoot] 对应同一套服务。
  static const String defaultBackendUrl = 'https://can.aiexplorerxj.top/docs';

  /// 实际调用 `/api/jyutping`、`/api/audio` 时使用的 API 根地址（自动去掉 `/docs`）。
  static String get backendApiRoot {
    var u = defaultBackendUrl.trim();
    u = u.replaceAll(RegExp(r'/+$'), '');
    final lower = u.toLowerCase();
    if (lower.endsWith('/docs')) {
      u = u.substring(0, u.length - 5);
      u = u.replaceAll(RegExp(r'/+$'), '');
    }
    return u;
  }
}
