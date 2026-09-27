import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import 'package:msw_dio_interceptor/msw_dio_interceptor.dart';
import 'package:my_app/core/config/network_config.dart';
import 'package:my_app/core/config/user_preferences.dart';
import 'package:my_app/core/data/network/dio_factory.dart';
import 'package:my_app/core/data/storage/auth_storage.dart';

/// Dio 与 NetworkConfig 的 DI 装配。
///
/// 拦截器栈本身在 [createDio] 里（那层与状态管理 / DI 无关）；
/// 本层只做三件 signals / DI 专属的事：
/// 1. 取编译期环境值（`--dart-define` / `--dart-define-from-file` 注入）
/// 2. 从 `UserPreferences` 取 `enableDebugLogging`
/// 3. 注册本应用专属的 Mock 规则
@module
abstract class NetworkModule {
  /// 全项目唯一构造 `NetworkConfig` 的地方。
  @lazySingleton
  NetworkConfig networkConfig() => NetworkConfig.fromEnvironment();

  /// 整个 App 共用一个 Dio（必须单例，理由见 backend/network-guidelines.md）。
  @lazySingleton
  Dio dio(
    UserPreferences preferences,
    AuthStorage authStorage,
    NetworkConfig config,
  ) => createDio(
    config: config,
    tokenStore: authStorage,
    enableDebugLogging: preferences.enableDebugLogging.value,
    isMock: config.isMock,
    registerMockRules: _registerMockRules,
  );
}

/// 注册内置 Mock 规则。
///
/// 规则留在这里而不是 `dio_factory.dart`：它们是本应用的具体端点，
/// 通用 Dio 装配不该知道 `/articles` / `/login` 这类业务路径。
///
/// 必须用 `MockRule.regex` 且锚定 URL 结尾 —— `MockRule(path: ...)` 永远打不中，
/// 会静默失效并打到真实网络（原因见 backend/network-guidelines.md）。
void _registerMockRules() {
  MockRegistry.register(
    MockRule.regex(
      pattern: r'/articles$',
      method: 'GET',
      handler: (_) => MockResponse.text(
        '''
[
  {"id": 1, "title": "Flutter 3.44 新特性解析", "body": "Flutter 3.44 新特性详情..."},
  {"id": 2, "title": "Dart 3.12 模式匹配实战", "body": "Dart 3.12 模式匹配详解..."}
]''',
        headers: {'content-type': 'application/json'},
      ),
    ),
  );
  MockRegistry.register(
    MockRule.regex(
      pattern: r'/articles/\d+$',
      method: 'GET',
      handler: (_) => MockResponse.text(
        '{"id":1,"title":"Flutter 3.44 新特性解析","body":"Flutter 3.44 新特性详情..."}',
        headers: {'content-type': 'application/json'},
      ),
    ),
  );
  MockRegistry.register(
    MockRule.regex(
      pattern: r'/login$',
      method: 'POST',
      handler: (_) => MockResponse.json({
        'user': {'id': 1, 'name': '开发者'},
        'accessToken': 'mock-access-token',
        'refreshToken': 'mock-refresh-token',
        'expiresIn': 3600,
      }),
    ),
  );
  MockRegistry.register(
    MockRule.regex(
      pattern: r'/refresh$',
      method: 'POST',
      handler: (_) => MockResponse.json({
        'accessToken': 'mock-access-token-refreshed',
        'refreshToken': 'mock-refresh-token-rotated',
        'expiresIn': 3600,
      }),
    ),
  );
}
