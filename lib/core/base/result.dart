/// 统一结果类型：所有可能失败的操作都返回它，而不是裸抛异常。
///
/// 用法见 backend/error-handling.md。
sealed class Result<T, E> {
  const new();

  const factory success(T data) = Ok<T, E>;

  const factory failure(E error) = Err<T, E>;

  R when<R>({
    required R Function(T data) success,
    required R Function(E error) failure,
  });

  bool get isSuccess => this is Ok<T, E>;

  bool get isFailure => this is Err<T, E>;

  /// 取成功值；在 [Err] 上会抛 [StateError]，只用于测试
  T get getOrThrow => switch (this) {
    Ok<T, E>(:final data) => data,
    Err<T, E>(:final error) => throw StateError(
      'Called getOrThrow on Err: $error',
    ),
  };

  Result<R, E> map<R>(R Function(T data) transform) {
    return switch (this) {
      Ok<T, E>(:final data) => Result.success(transform(data)),
      Err<T, E>(:final error) => Result.failure(error),
    };
  }

  Result<T, F> mapError<F>(F Function(E error) transform) {
    return switch (this) {
      Ok<T, E>(:final data) => Result.success(data),
      Err<T, E>(:final error) => Result.failure(transform(error)),
    };
  }

  Result<R, E> flatMap<R>(Result<R, E> Function(T data) transform) {
    return switch (this) {
      Ok<T, E>(:final data) => transform(data),
      Err<T, E>(:final error) => Result.failure(error),
    };
  }
}

/// 成功结果
class Ok<T, E> extends Result<T, E> {
  const new(this.data);
  final T data;

  @override
  R when<R>({
    required R Function(T data) success,
    required R Function(E error) failure,
  }) => success(data);

  @override
  String toString() => 'Ok($data)';
}

/// 失败结果
class Err<T, E> extends Result<T, E> {
  const new(this.error);
  final E error;

  @override
  R when<R>({
    required R Function(T data) success,
    required R Function(E error) failure,
  }) => failure(error);

  @override
  String toString() => 'Err($error)';
}
