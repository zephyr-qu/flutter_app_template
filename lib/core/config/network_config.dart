import 'package:flutter/foundation.dart';

/// 网络配置。不可变值对象，由 `NetworkModule.networkConfig()` 注入
/// （见 backend/network-guidelines.md「配置：只有一个来源」）。
@immutable
class NetworkConfig {
  const new({
    required this.baseUrl,
    this.isMock = false,
    this.connectTimeout = 10000,
    this.receiveTimeout = 10000,
    this.retries = 3,
  });

  /// 从编译期常量构造（`--dart-define` / `--dart-define-from-file`）。
  ///
  /// 注入为空时退回 [NetworkConfig.fromEnv] 的默认值：真实启动路径上 `bootstrap()` 已经拦过
  /// 缺 `BASE_URL` 的情况，这里的兜底只为让「没注入」的测试环境有确定行为。
  factory fromEnvironment() {
    const baseUrl = String.fromEnvironment('BASE_URL');
    const useMock = String.fromEnvironment('USE_MOCK', defaultValue: 'false');
    return NetworkConfig.fromEnv({
      if (baseUrl.isNotEmpty) 'BASE_URL': baseUrl,
      'USE_MOCK': useMock,
    });
  }

  /// 从一组键值构造。纯函数，可直接单测。
  factory fromEnv(Map<String, String> env) => NetworkConfig(
    baseUrl: env['BASE_URL'] ?? 'https://api.example.com',
    isMock: (env['USE_MOCK'] ?? 'false').toLowerCase() == 'true',
  );

  /// API 基础 URL（来自 `BASE_URL`）
  final String baseUrl;

  /// 本地 Mock 开关（来自 `USE_MOCK`）；为 true 时不发真实请求，直接返回注册的 mock 响应
  final bool isMock;

  /// 连接超时（毫秒）
  final int connectTimeout;

  /// 接收超时（毫秒）
  final int receiveTimeout;

  /// 最大重试次数
  final int retries;

  /// 默认请求头
  Map<String, String> get defaultHeaders => const {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
}
