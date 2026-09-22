import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:dio_smart_retry/dio_smart_retry.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:injectable/injectable.dart';
import 'package:msw_dio_interceptor/msw_dio_interceptor.dart';
import 'package:my_app/core/config/network_config.dart';
import 'package:my_app/core/config/user_preferences.dart';
import 'package:my_app/core/data/network/auth_interceptor.dart';
import 'package:my_app/core/data/network/token_refresher.dart';
import 'package:my_app/core/data/storage/auth_storage.dart';
import 'package:my_app/core/logging/log_redactor.dart';
import 'package:my_app/core/logging/logging.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

@module
abstract class NetworkModule {
  /// 全项目唯一读 `dotenv` 的地方（环境变量在 `bootstrap()` 之后才加载）。
  @lazySingleton
  NetworkConfig networkConfig() => NetworkConfig.fromEnv(dotenv.env);

  /// 整个 App 共用一个 Dio（必须单例，理由见 backend/network-guidelines.md）。
  @lazySingleton
  Dio dio(
    UserPreferences preferences,
    AuthStorage authStorage,
    NetworkConfig config,
  ) {
    final dio = Dio(
      BaseOptions(
        baseUrl: config.baseUrl,
        connectTimeout: Duration(milliseconds: config.connectTimeout),
        receiveTimeout: Duration(milliseconds: config.receiveTimeout),
        headers: config.defaultHeaders,
      ),
    );

    // ── 拦截器顺序：Auth → 解码 → Retry → Mock ──
    // 顺序承载两条语义（Retry 不吞 401、重放走完整条链）。
    // 改之前先跑 test/core/data/network/interceptor_stack_test.dart，
    // 理由见 backend/network-guidelines.md。

    // 认证拦截器（附加访问令牌；401 时刷新令牌并重放原请求；刷新失败则登出）
    dio.interceptors.add(
      AuthInterceptor(authStorage, TokenRefresher(authStorage, dio), dio),
    );

    // 兜底解码：部分后端以 text/plain 返回 JSON 字符串，这里手动解析
    dio.interceptors.add(
      InterceptorsWrapper(
        onResponse: (response, handler) {
          final data = response.data;
          if (data is String) {
            try {
              response.data = json.decode(data);
            } catch (e) {
              Logging.warning('响应体不是合法 JSON，保留原始字符串: $e');
            }
          }
          handler.next(response);
        },
      ),
    );

    dio.interceptors.add(RetryInterceptor(dio: dio, retries: config.retries));

    // Mock 拦截器（仅在 isMock=true 时启用）
    if (config.isMock) {
      const mockEngine = MockHttpEngine();
      dio.interceptors.add(MockInterceptor(engine: mockEngine));
      _registerMockRules();
    }

    if (kDebugMode && preferences.enableDebugLogging.value) {
      // 逐行脱敏后再落控制台：登录请求体的 password、响应里的
      // accessToken / refreshToken 都不能进日志（理由见 log_redactor.dart）。
      // redactor 必须在拦截器外建好 —— 它要跨行记住「敏感值还没结束」。
      final redactor = LogRedactor();
      dio.interceptors.add(
        PrettyDioLogger(
          requestBody: true,
          logPrint: (object) => debugPrint(redactor.redact(object.toString())),
        ),
      );
    }

    return dio;
  }
}

/// 注册内置 Mock 规则。
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
