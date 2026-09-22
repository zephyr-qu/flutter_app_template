import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/base/failure.dart';
import 'package:my_app/core/ui/failure_message.dart';
import 'package:my_app/l10n/app_localizations.dart';
import 'package:my_app/l10n/app_localizations_en.dart';
import 'package:my_app/l10n/app_localizations_zh.dart';

/// Failure 只带 code，文案在这里翻译 —— 所以「切英文后错误提示是英文」
/// 这件事就落在这一层，值得直接测。
void main() {
  final zh = AppLocalizationsZh();
  final en = AppLocalizationsEn();

  group('FailureMessage — 中文', () {
    test('每种 code 都有中文文案', () {
      expect(
        const NetworkFailure(code: FailureCode.timeout).localizedMessage(zh),
        '请求超时',
      );
      expect(
        const NetworkFailure(code: FailureCode.connection).localizedMessage(zh),
        '网络连接失败',
      );
      expect(
        const AuthFailure(code: FailureCode.unauthorized).localizedMessage(zh),
        '未授权，请登录',
      );
      expect(
        const AuthFailure(code: FailureCode.forbidden).localizedMessage(zh),
        '禁止访问',
      );
      expect(
        const ServerFailure(code: FailureCode.notFound).localizedMessage(zh),
        '资源不存在',
      );
      expect(
        const ServerFailure(code: FailureCode.conflict).localizedMessage(zh),
        '数据冲突，请刷新后重试',
      );
      expect(
        const ServerFailure(
          code: FailureCode.serverError,
          statusCode: 500,
        ).localizedMessage(zh),
        '服务器错误',
      );
      expect(
        const UnknownFailure(code: FailureCode.cancelled).localizedMessage(zh),
        '请求已取消',
      );
      expect(
        const UnknownFailure(code: FailureCode.unknown).localizedMessage(zh),
        '未知错误',
      );
    });

    test('requestFailed 把状态码展示出来', () {
      expect(
        const ServerFailure(
          code: FailureCode.requestFailed,
          statusCode: 418,
        ).localizedMessage(zh),
        '请求失败（418）',
      );
    });

    test('requestFailed 没有状态码时不会崩，也不会显示空格子', () {
      final message = const ServerFailure(code: FailureCode.requestFailed)
          .localizedMessage(zh);

      expect(message, contains('?'));
    });
  });

  group('FailureMessage — 英文', () {
    test('同一个 Failure 翻译成英文', () {
      expect(
        const NetworkFailure(code: FailureCode.timeout).localizedMessage(en),
        'Request timed out',
      );
      expect(
        const AuthFailure(code: FailureCode.unauthorized).localizedMessage(en),
        'Not authorized, please sign in',
      );
      expect(
        const ServerFailure(
          code: FailureCode.requestFailed,
          statusCode: 418,
        ).localizedMessage(en),
        'Request failed (418)',
      );
    });

    test('中英文案确实不同', () {
      for (final failure in <Failure>[
        const NetworkFailure(code: FailureCode.timeout),
        const AuthFailure(code: FailureCode.unauthorized),
        const ServerFailure(code: FailureCode.notFound),
        const UnknownFailure(code: FailureCode.unknown),
      ]) {
        expect(
          failure.localizedMessage(zh),
          isNot(failure.localizedMessage(en)),
          reason: '${failure.code} 的中英文案相同，可能漏了英文翻译',
        );
      }
    });

    test('每一种 code 都有非空文案（两种语言）', () {
      for (final localizations in <AppLocalizations>[zh, en]) {
        for (final code in FailureCode.values) {
          final failure = ServerFailure(code: code, statusCode: 500);
          expect(
            failure.localizedMessage(localizations),
            isNotEmpty,
            reason: '$code 缺少文案',
          );
        }
      }
    });
  });
}
