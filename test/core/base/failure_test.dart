import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/base/failure.dart';

DioException _err({
  required DioExceptionType type,
  int? statusCode,
  String? statusMessage,
  String message = 'raw internal detail / 内部细节',
}) {
  final options = RequestOptions(path: '/articles');
  return DioException(
    requestOptions: options,
    type: type,
    message: message,
    response: statusCode == null
        ? null
        : Response<void>(
            requestOptions: options,
            statusCode: statusCode,
            statusMessage: statusMessage,
          ),
  );
}

void main() {
  group('handleDioError — 网络类', () {
    test('三种超时都映射为 NetworkFailure(timeout)', () {
      for (final type in [
        DioExceptionType.connectionTimeout,
        DioExceptionType.receiveTimeout,
        DioExceptionType.sendTimeout,
      ]) {
        final failure = handleDioError(_err(type: type));
        expect(failure, isA<NetworkFailure>());
        expect(failure.code, FailureCode.timeout);
      }
    });

    test('连接失败映射为 NetworkFailure(connection)', () {
      final failure = handleDioError(
        _err(type: DioExceptionType.connectionError),
      );
      expect(failure, isA<NetworkFailure>());
      expect(failure.code, FailureCode.connection);
    });

    test('证书校验失败映射为 NetworkFailure(badCertificate)', () {
      final failure = handleDioError(
        _err(type: DioExceptionType.badCertificate),
      );
      expect(failure, isA<NetworkFailure>());
      expect(failure.code, FailureCode.badCertificate);
    });
  });

  group('handleDioError — 状态码', () {
    Failure map(int code) => handleDioError(
      _err(type: DioExceptionType.badResponse, statusCode: code),
    );

    test('401 / 403 映射为 AuthFailure', () {
      expect(map(401), isA<AuthFailure>());
      expect(map(401).code, FailureCode.unauthorized);
      expect(map(403), isA<AuthFailure>());
      expect(map(403).code, FailureCode.forbidden);
    });

    test('常见 4xx 都有对应 code', () {
      expect(map(400).code, FailureCode.invalidRequest);
      expect(map(404).code, FailureCode.notFound);
      expect(map(408).code, FailureCode.timeout);
      expect(map(409).code, FailureCode.conflict);
      expect(map(422).code, FailureCode.invalidPayload);
      expect(map(429).code, FailureCode.tooManyRequests);
      expect(map(400), isA<ServerFailure>());
    });

    test('5xx 映射为 ServerFailure(serverError) 并保留状态码', () {
      for (final code in [500, 502, 503, 504]) {
        final failure = map(code);
        expect(failure, isA<ServerFailure>());
        expect(failure.code, FailureCode.serverError);
        expect(failure.statusCode, code);
      }
    });

    test('未逐一列举的 4xx 映射为 requestFailed 且保留状态码', () {
      final failure = map(418);

      expect(failure, isA<ServerFailure>());
      expect(failure.code, FailureCode.requestFailed);
      expect(failure.statusCode, 418);
    });

    test('badResponse 但没有状态码时落到 unexpected', () {
      final failure = handleDioError(_err(type: DioExceptionType.badResponse));

      expect(failure, isA<UnknownFailure>());
      expect(failure.code, FailureCode.unexpected);
    });
  });

  group('handleDioError — 其他', () {
    test('取消映射为 cancelled', () {
      final failure = handleDioError(_err(type: DioExceptionType.cancel));
      expect(failure, isA<UnknownFailure>());
      expect(failure.code, FailureCode.cancelled);
    });

    test('未分类异常映射为 unexpected', () {
      final failure = handleDioError(
        _err(
          type: DioExceptionType.unknown,
          message: 'SocketException: 内部地址 10.0.2.2:8080 拒绝连接',
        ),
      );

      expect(failure, isA<UnknownFailure>());
      expect(failure.code, FailureCode.unexpected);
    });
  });

  group('Failure 自身', () {
    test('不携带任何用户可见文案', () {
      // 服务端的 statusMessage 不应该有机会漏出去：
      // Failure 只记 code（+状态码），文案在展示层翻译
      final failure = handleDioError(
        _err(
          type: DioExceptionType.badResponse,
          statusCode: 418,
          statusMessage: 'I am a teapot',
        ),
      );

      expect(failure.toString(), isNot(contains('teapot')));
      expect(failure.toString(), contains('requestFailed'));
      expect(failure.toString(), contains('418'));
    });

    test('toString 只用于日志，包含 code 与状态码', () {
      expect(
        const NetworkFailure(code: FailureCode.timeout).toString(),
        'Failure(timeout)',
      );
      expect(
        const ServerFailure(
          code: FailureCode.serverError,
          statusCode: 500,
        ).toString(),
        'Failure(serverError, status: 500)',
      );
    });
  });
}
