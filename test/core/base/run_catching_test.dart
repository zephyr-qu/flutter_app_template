import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/base/failure.dart';
import 'package:my_app/core/base/run_catching.dart';

void main() {
  group('runCatching', () {
    test('成功时返回 Result.success', () async {
      final result = await runCatching(() async => 42);

      expect(result.isSuccess, isTrue);
      expect(result.when(success: (v) => v, failure: (_) => -1), 42);
    });

    test('DioException 交给 handleDioError 映射', () async {
      final requestOptions = RequestOptions(path: '/articles');
      final result = await runCatching<int>(
        () async => throw DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.badResponse,
          response: Response<void>(
            requestOptions: requestOptions,
            statusCode: 404,
          ),
        ),
      );

      expect(result.isFailure, isTrue);
      expect(
        result.when(success: (_) => null, failure: (f) => f.code),
        FailureCode.notFound,
      );
    });

    test('非 Dio 异常转为 unknown，且不携带异常文本', () async {
      final result = await runCatching<int>(
        () async => throw StateError('内部字段 accessToken=secret 不该出现'),
      );

      expect(result.isFailure, isTrue);
      final failure = result.when(success: (_) => null, failure: (f) => f);
      expect(failure, isA<UnknownFailure>());
      expect(failure!.code, FailureCode.unknown);
      expect(failure.toString(), isNot(contains('secret')));
    });

    test('类型错误也不会把堆栈暴露出去', () async {
      // 模拟解析错误：把 String 当 int 用
      final result = await runCatching<int>(() async {
        const dynamic decoded = 'not-a-number';
        return decoded as int;
      });

      expect(result.isFailure, isTrue);
      expect(
        result.when(success: (_) => null, failure: (f) => f.code),
        FailureCode.unknown,
      );
    });
  });
}
