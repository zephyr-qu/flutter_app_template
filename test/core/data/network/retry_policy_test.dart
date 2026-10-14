import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/data/network/retry_policy.dart';

/// [shouldRetryRequest] 的判据表。
///
/// 重点在两条**写请求必须为 false**：库的默认 evaluator 不看 HTTP 方法，
/// 写请求超时会被重发（`dio_smart_retry` 的默认语义），这里把它收窄。
DioException _error({
  required String method,
  DioExceptionType type = DioExceptionType.connectionTimeout,
  int? statusCode,
  Object? error,
}) {
  final options = RequestOptions(path: '/x', method: method);
  return DioException(
    requestOptions: options,
    type: type,
    error: error,
    response: statusCode == null
        ? null
        : Response<dynamic>(requestOptions: options, statusCode: statusCode),
  );
}

void main() {
  group('shouldRetryRequest — 幂等方法', () {
    test('GET 传输层超时：重试', () {
      expect(shouldRetryRequest(_error(method: 'GET'), 1), isTrue);
    });

    test('HEAD 传输层超时：重试', () {
      expect(shouldRetryRequest(_error(method: 'HEAD'), 1), isTrue);
    });

    test('GET 连接错误：重试', () {
      expect(
        shouldRetryRequest(
          _error(method: 'GET', type: DioExceptionType.connectionError),
          1,
        ),
        isTrue,
      );
    });

    test('GET 的 408 / 429 / 5xx：重试', () {
      for (final statusCode in retryableStatuses) {
        expect(
          shouldRetryRequest(
            _error(
              method: 'GET',
              type: DioExceptionType.badResponse,
              statusCode: statusCode,
            ),
            1,
          ),
          isTrue,
          reason: '状态码 $statusCode 应在可重试清单里',
        );
      }
    });

    test('GET 的 401：不重试（穿给 AuthInterceptor）', () {
      expect(
        shouldRetryRequest(
          _error(
            method: 'GET',
            type: DioExceptionType.badResponse,
            statusCode: 401,
          ),
          1,
        ),
        isFalse,
      );
    });

    test('GET 的其它 4xx：不重试', () {
      expect(
        shouldRetryRequest(
          _error(
            method: 'GET',
            type: DioExceptionType.badResponse,
            statusCode: 404,
          ),
          1,
        ),
        isFalse,
      );
    });

    test('主动取消与 FormatException：不重试', () {
      expect(
        shouldRetryRequest(
          _error(method: 'GET', type: DioExceptionType.cancel),
          1,
        ),
        isFalse,
      );
      expect(
        shouldRetryRequest(
          _error(method: 'GET', error: const FormatException('bad json')),
          1,
        ),
        isFalse,
      );
    });
  });

  group('shouldRetryRequest — 写请求', () {
    test('POST 传输层超时：不重试（避免重复副作用）', () {
      expect(shouldRetryRequest(_error(method: 'POST'), 1), isFalse);
    });

    test('POST 的 5xx：也不重试', () {
      expect(
        shouldRetryRequest(
          _error(
            method: 'POST',
            type: DioExceptionType.badResponse,
            statusCode: 503,
          ),
          1,
        ),
        isFalse,
      );
    });

    test('PUT / PATCH / DELETE 同样不重试', () {
      for (final method in ['PUT', 'PATCH', 'DELETE']) {
        expect(
          shouldRetryRequest(_error(method: method), 1),
          isFalse,
          reason: '$method 不是幂等方法',
        );
      }
    });

    test('方法名大小写不敏感（get 也当 GET）', () {
      expect(shouldRetryRequest(_error(method: 'get'), 1), isTrue);
      expect(shouldRetryRequest(_error(method: 'post'), 1), isFalse);
    });
  });
}
