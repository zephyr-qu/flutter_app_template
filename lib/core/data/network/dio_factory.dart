import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:dio_smart_retry/dio_smart_retry.dart';
import 'package:flutter/foundation.dart';
import 'package:msw_dio_interceptor/msw_dio_interceptor.dart';
import 'package:my_app/core/config/network_config.dart';
import 'package:my_app/core/data/network/auth_interceptor.dart';
import 'package:my_app/core/data/network/token_refresher.dart';
import 'package:my_app/core/data/network/token_store.dart';
import 'package:my_app/core/logging/log_redactor.dart';
import 'package:my_app/core/logging/logging.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

/// 构造全 App 共用的 Dio（拦截器栈 + 可选 Mock）。
///
/// **必须单例**（理由见 backend/network-guidelines.md）。
///
/// **不依赖状态管理与 DI**：`enableDebugLogging` 与 [registerMockRules] 都由调用方
/// 传入，所以本函数不知道任何业务端点，也不知道 signals / Riverpod 的存在。
/// 它只负责「怎么造」，「谁来提供」归各分支的装配层（见 design 6.5）。
///
/// [registerMockRules] 仅在 [isMock] 为 true 时调用。
Dio createDio({
  required NetworkConfig config,
  required TokenStore tokenStore,
  required bool enableDebugLogging,
  required bool isMock,
  void Function()? registerMockRules,
}) {
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
    AuthInterceptor(tokenStore, TokenRefresher(tokenStore, dio), dio),
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
  if (isMock) {
    const mockEngine = MockHttpEngine();
    dio.interceptors.add(MockInterceptor(engine: mockEngine));
    registerMockRules?.call();
  }

  if (kDebugMode && enableDebugLogging) {
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
