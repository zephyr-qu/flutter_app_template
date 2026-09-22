import 'package:app_core/base/failure.dart';
import 'package:app_core/base/result.dart';
import 'package:app_core/logging/logging.dart';
import 'package:dio/dio.dart';

/// 执行可能失败的异步调用，把异常统一转成 [Result]：
/// `DioException` → [handleDioError]，其它异常 → [FailureCode.unknown]。
Future<Result<T, Failure>> runCatching<T>(Future<T> Function() body) async {
  try {
    return Result.success(await body());
  } on DioException catch (e) {
    return Result.failure(handleDioError(e));
  } catch (e, stackTrace) {
    // 原始异常只进日志。它可能带 Dart 堆栈、URL、内部字段名，
    // 展示给用户既没意义也不安全。
    Logging.error('未预期的异常', exception: e, stackTrace: stackTrace);
    return const Result.failure(UnknownFailure(code: FailureCode.unknown));
  }
}
