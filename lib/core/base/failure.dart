import 'package:dio/dio.dart';
import 'package:my_app/core/logging/logging.dart';

/// 失败原因码。只描述「是什么错」，文案在展示层翻译；新增 code 后
/// `core/ui/failure_message.dart` 的 switch 会因不穷尽而报错，记得补文案。
enum FailureCode {
  /// 超时（连接 / 发送 / 接收）
  timeout,

  /// 连不上对端
  connection,

  /// TLS 证书校验失败
  badCertificate,

  /// 401
  unauthorized,

  /// 403
  forbidden,

  /// 404
  notFound,

  /// 400
  invalidRequest,

  /// 409
  conflict,

  /// 422
  invalidPayload,

  /// 429
  tooManyRequests,

  /// 5xx，配合 [Failure.statusCode]
  serverError,

  /// 未列举的 4xx，配合 [Failure.statusCode]
  requestFailed,

  /// 请求被主动取消
  cancelled,

  /// Dio 抛出了无法归类的异常（网络层兜底）
  unexpected,

  /// 非 Dio 异常（解析、编程错误等业务层兜底）
  unknown,
}

/// 四类失败：网络（请求没能正常往返）/ 认证（401、403）/ 服务端（其余 4xx、5xx）/ 兜底。
///
/// 「产生 → 分派 → 渲染」的完整流程见 backend/error-handling.md。
sealed class Failure implements Exception {
  const new({required this.code, this.statusCode});

  /// 失败原因；文案在展示层翻译
  final FailureCode code;

  /// HTTP 状态码，仅 [FailureCode.serverError] / [FailureCode.requestFailed] 会带
  final int? statusCode;

  /// 只用于日志与调试，不要展示给用户
  @override
  String toString() =>
      'Failure(${code.name}'
      '${statusCode == null ? '' : ', status: $statusCode'})';
}

class NetworkFailure extends Failure {
  const new({required super.code});
}

class AuthFailure extends Failure {
  const new({required super.code, super.statusCode});
}

class ServerFailure extends Failure {
  const new({required super.code, super.statusCode});
}

class UnknownFailure extends Failure {
  const new({required super.code});
}

/// 将 DioException 转为统一的 Failure；原始异常信息只进日志。
Failure handleDioError(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.transformTimeout:
      return const NetworkFailure(code: FailureCode.timeout);
    case DioExceptionType.connectionError:
      return const NetworkFailure(code: FailureCode.connection);
    case DioExceptionType.badCertificate:
      return const NetworkFailure(code: FailureCode.badCertificate);
    case DioExceptionType.badResponse:
      return _handleBadResponse(e);
    case DioExceptionType.cancel:
      return const UnknownFailure(code: FailureCode.cancelled);
    // 枚举的新增成员会掉到这里：穷尽 switch 保证升级 dio 后这里必须一起改
    case DioExceptionType.unknown:
      Logging.warning('未分类的网络异常(${e.type.name}): ${e.message}');
      return const UnknownFailure(code: FailureCode.unexpected);
  }
}

/// 按状态码映射，覆盖常见的 4xx / 5xx
Failure _handleBadResponse(DioException e) {
  final code = e.response?.statusCode;

  switch (code) {
    case 400:
      return const ServerFailure(code: FailureCode.invalidRequest);
    case 401:
      return const AuthFailure(code: FailureCode.unauthorized);
    case 403:
      return const AuthFailure(code: FailureCode.forbidden);
    case 404:
      return const ServerFailure(code: FailureCode.notFound);
    case 408:
      return const NetworkFailure(code: FailureCode.timeout);
    case 409:
      return const ServerFailure(code: FailureCode.conflict);
    case 422:
      return const ServerFailure(code: FailureCode.invalidPayload);
    case 429:
      return const ServerFailure(code: FailureCode.tooManyRequests);
  }

  if (code == null) {
    // 没有状态码说明不是正经的 HTTP 响应
    Logging.warning('响应缺少状态码: ${e.requestOptions.uri}');
    return const UnknownFailure(code: FailureCode.unexpected);
  }

  if (code >= 500) {
    Logging.warning('服务端错误 $code: ${e.requestOptions.uri}');
    return ServerFailure(code: FailureCode.serverError, statusCode: code);
  }

  // 未逐一列举的 4xx：文案里会带上状态码
  Logging.warning('未映射的响应状态码 $code: ${e.requestOptions.uri}');
  return ServerFailure(code: FailureCode.requestFailed, statusCode: code);
}
