import 'package:my_app/core/base/failure.dart';

/// 把 [Failure] 翻译成面向用户的文案。
///
/// 放在展示层而不是 `Failure` 自己身上：翻译是展示职责，领域类型不依赖 l10n。
extension FailureMessage on Failure {
  String localizedMessage() {
    return switch (code) {
      FailureCode.timeout => '请求超时',
      FailureCode.connection => '网络连接失败',
      FailureCode.badCertificate => '安全连接校验失败',
      FailureCode.unauthorized => '未授权，请登录',
      FailureCode.forbidden => '禁止访问',
      FailureCode.notFound => '资源不存在',
      FailureCode.invalidRequest => '请求参数有误',
      FailureCode.conflict => '数据冲突，请刷新后重试',
      FailureCode.invalidPayload => '提交的内容不合法',
      FailureCode.tooManyRequests => '请求过于频繁，请稍后重试',
      FailureCode.serverError => '服务器错误',
      // 未逐一列举的 4xx：把状态码一并展示，便于排查
      FailureCode.requestFailed => '请求失败（${'${statusCode ?? '?'}'}）',
      FailureCode.cancelled => '请求已取消',
      FailureCode.unexpected => '网络异常，请稍后重试',
      FailureCode.unknown => '未知错误',
    };
  }
}
