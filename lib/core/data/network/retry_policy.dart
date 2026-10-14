import 'package:dio/dio.dart';

/// 值得重试的状态码。
///
/// 必须自带这份清单：`dio_smart_retry` 的 `retryEvaluator` 与
/// `retryableExtraStatuses` **互斥**（同时传会抛 `ArgumentError`），
/// 只传 evaluator 而不带清单，会让 5xx 重试静默消失。
const Set<int> retryableStatuses = <int>{408, 429, 500, 502, 503, 504};

/// 这次失败要不要重试（传给 `RetryInterceptor` 的 `retryEvaluator`）。
///
/// 只重试**幂等方法**（GET / HEAD）：写请求超时后重发可能重复副作用
/// （下单、提交），成功率换安全。其余判据沿用库的默认语义 —— 状态码命中
/// [retryableStatuses]，或传输层错误（连接 / 发送 / 接收超时、connectionError）。
///
/// 401 不在可重试之列：它要原样穿给 `AuthInterceptor` 去刷新令牌，
/// 顺序理由见 data/network-guidelines.md「拦截器顺序」。
bool shouldRetryRequest(DioException error, int attempt) {
  final method = error.requestOptions.method.toUpperCase();
  if (method != 'GET' && method != 'HEAD') return false;

  if (error.type == DioExceptionType.badResponse) {
    final statusCode = error.response?.statusCode;
    // 拿不到状态码时保持库的默认（重试），不擅自收紧
    return statusCode == null || retryableStatuses.contains(statusCode);
  }

  return error.type != DioExceptionType.cancel &&
      error.error is! FormatException;
}
