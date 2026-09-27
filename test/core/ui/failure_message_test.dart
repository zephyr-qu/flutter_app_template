import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/base/failure.dart';
import 'package:my_app/core/ui/failure_message.dart';

/// Failure 只带 code，文案在这里翻译；单语言形态下它只可能返回中文。
void main() {
  group('FailureMessage — 中文', () {
    test('每种 code 都有中文文案', () {
      expect(
        const NetworkFailure(code: FailureCode.timeout).localizedMessage(),
        '请求超时',
      );
      expect(
        const NetworkFailure(code: FailureCode.connection).localizedMessage(),
        '网络连接失败',
      );
      expect(
        const AuthFailure(code: FailureCode.unauthorized).localizedMessage(),
        '未授权，请登录',
      );
      expect(
        const AuthFailure(code: FailureCode.forbidden).localizedMessage(),
        '禁止访问',
      );
      expect(
        const ServerFailure(code: FailureCode.notFound).localizedMessage(),
        '资源不存在',
      );
      expect(
        const ServerFailure(code: FailureCode.conflict).localizedMessage(),
        '数据冲突，请刷新后重试',
      );
      expect(
        const ServerFailure(
          code: FailureCode.serverError,
          statusCode: 500,
        ).localizedMessage(),
        '服务器错误',
      );
      expect(
        const UnknownFailure(code: FailureCode.cancelled).localizedMessage(),
        '请求已取消',
      );
      expect(
        const UnknownFailure(code: FailureCode.unknown).localizedMessage(),
        '未知错误',
      );
    });

    test('requestFailed 把状态码展示出来', () {
      expect(
        const ServerFailure(
          code: FailureCode.requestFailed,
          statusCode: 418,
        ).localizedMessage(),
        '请求失败（418）',
      );
    });

    test('requestFailed 没有状态码时不会崩，也不会显示空格子', () {
      final message = const ServerFailure(code: FailureCode.requestFailed)
          .localizedMessage();

      expect(message, contains('?'));
    });
  });
}
