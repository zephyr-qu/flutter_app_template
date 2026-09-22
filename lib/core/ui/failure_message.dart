import 'package:app_core/base/failure.dart';
import 'package:my_app/l10n/app_localizations.dart';

/// 把 [Failure] 翻译成面向用户的文案。
///
/// 放在展示层而不是 `Failure` 自己身上：翻译是展示职责，领域类型不依赖 l10n。
extension FailureMessage on Failure {
  String localizedMessage(AppLocalizations l10n) {
    return switch (code) {
      FailureCode.timeout => l10n.errorTimeout,
      FailureCode.connection => l10n.errorConnection,
      FailureCode.badCertificate => l10n.errorBadCertificate,
      FailureCode.unauthorized => l10n.errorUnauthorized,
      FailureCode.forbidden => l10n.errorForbidden,
      FailureCode.notFound => l10n.errorNotFound,
      FailureCode.invalidRequest => l10n.errorInvalidRequest,
      FailureCode.conflict => l10n.errorConflict,
      FailureCode.invalidPayload => l10n.errorInvalidPayload,
      FailureCode.tooManyRequests => l10n.errorTooManyRequests,
      FailureCode.serverError => l10n.errorServer,
      // 未逐一列举的 4xx：把状态码一并展示，便于排查
      FailureCode.requestFailed => l10n.errorRequestFailed(
        '${statusCode ?? '?'}',
      ),
      FailureCode.cancelled => l10n.errorCancelled,
      FailureCode.unexpected => l10n.errorUnexpected,
      FailureCode.unknown => l10n.errorUnknown,
    };
  }
}
