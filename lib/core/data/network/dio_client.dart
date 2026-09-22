import 'package:app_core/config/network_config.dart';
import 'package:app_core/data/network/dio_factory.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:msw_dio_interceptor/msw_dio_interceptor.dart';
import 'package:my_app/core/providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'dio_client.g.dart';

/// Dio 与 NetworkConfig 的装配（master 分支上这里是 `@module` + `@lazySingleton`）。
///
/// 拦截器栈本身在 `app_core` 的 [createDio] 里（与状态管理无关，两个栈共用）；
/// 本层只做三件本应用专属的事：
/// 1. 从 `dotenv` 取配置（环境变量在 `bootstrap()` 之后才加载）
/// 2. 读 `UserPreferences` 决定要不要挂调试日志
/// 3. 注册本应用专属的 Mock 规则

/// 全项目唯一读 `dotenv` 的地方。
///
/// `keepAlive` = 只算一次：`NetworkConfig` 是「配置只有一个来源」这条约定的载体
/// （见 backend/network-guidelines.md「配置：dotenv 只读一次」）。
@Riverpod(keepAlive: true)
NetworkConfig networkConfig(Ref ref) => NetworkConfig.fromEnv(dotenv.env);

/// 整个 App 共用一个 Dio（**必须单例**，理由见 backend/network-guidelines.md）。
///
/// 为什么读的是 `userPreferencesProvider` 而不是 `appSettingsProvider`：
/// 后者一变本 provider 就会被重建，而「Dio 必须单例」优先于「开关立刻生效」——
/// 重建会丢掉在飞请求、重放状态与 mock 注册。所以调试开关与 master 行为一致：
/// **下次创建 Dio（即重启 App）才生效**。
@Riverpod(keepAlive: true)
Dio dio(Ref ref) => createDio(
  config: ref.watch(networkConfigProvider),
  tokenStore: ref.watch(authStorageProvider),
  enableDebugLogging: ref.watch(userPreferencesProvider).enableDebugLogging,
  isMock: ref.watch(networkConfigProvider).isMock,
  registerMockRules: _registerMockRules,
);

/// 注册内置 Mock 规则。
///
/// 规则留在应用侧而不是 `app_core`：它们是本应用的具体端点，包不该知道
/// `/sample-items` / `/login` 这类业务路径（见 design 6.5）。
///
/// 必须用 `MockRule.regex` 且锚定 URL 结尾 —— `MockRule(path: ...)` 永远打不中，
/// 会静默失效并打到真实网络（原因见 backend/network-guidelines.md）。
void _registerMockRules() {
  MockRegistry.register(
    MockRule.regex(
      pattern: r'/sample-items$',
      method: 'GET',
      handler: (_) => MockResponse.text(
        '''
[
  {"id": 1, "title": "示例条目一", "body": "这是脚手架的金标准示例数据。"},
  {"id": 2, "title": "示例条目二", "body": "照它写新 feature 即可。"}
]''',
        headers: {'content-type': 'application/json'},
      ),
    ),
  );
  MockRegistry.register(
    MockRule.regex(
      pattern: r'/sample-items/\d+$',
      method: 'GET',
      handler: (_) => MockResponse.json({
        'id': 1,
        'title': '示例条目一',
        'body': '这是脚手架的金标准示例数据。',
      }),
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
