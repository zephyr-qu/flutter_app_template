import 'package:my_app/core/base/failure.dart';
import 'package:my_app/core/base/result.dart';
import 'package:my_app/core/logging/logging.dart';
import 'package:signals_flutter/signals_flutter.dart';

/// 按 signal 记录最近一次调用的序号（用 [Expando]，不阻止 signal 被 GC）。
final Expando<int> _latestCallId = Expando<int>('runAsync.latestCallId');

/// 把一个异步任务跑成三态：先 loading，成功 data、失败 error；返回原始 `Result`。
///
/// 三条已定行为——并发「最后一次胜出」、已有数据时保留旧数据（`dataRefreshing`）、
/// error 里放 [Failure] 对象而非文案——见 frontend/state-management.md。
///
/// 任务的 `Result` 就是信号的值。任务只表达成败（`Result<void, _>`）时改用
/// [runAsyncVoid]——把 `void` 传进来会让 `T` 塌成 `void`，运行时报类型错。
Future<Result<void, Failure>> runAsync<T>(
  Signal<AsyncState<T>> signal,
  Future<Result<T, Failure>> Function() task,
) => _drive<T>(signal, task);

/// 任务只表达成败（`Result<void, _>`），成功时把信号置为 `data(onSuccess)`。
///
/// **为什么不能直接复用 [runAsync]**：`T` 同时被「信号」和「任务结果」约束，而 `void`
/// 是所有类型的父类型——任务返回 `Result<void, _>` 时约束解是 `LUB(T信号, void) = void`，
/// 于是 `AsyncState<void>` 在运行时等于 `AsyncState<dynamic>`，写进
/// `Signal<AsyncState<User?>>` 会当场抛类型错。把「成功时该是什么值」显式写出来
/// （[onSuccess]），`T` 就只由信号与非 `void` 的值决定。
Future<Result<void, Failure>> runAsyncVoid<T>(
  Signal<AsyncState<T>> signal,
  Future<Result<void, Failure>> Function() task, {
  required T onSuccess,
}) => _drive<T>(signal, () async => (await task()).map((_) => onSuccess));

/// 两个公开函数的共同骨架：三态迁移 + 兜异常 + 竞态保护。
///
/// **这里没有 `disposed` 守卫，这是有意的**：加它就必须同时允许 ViewModel 自己
/// `dispose()`，否则页面在请求飞行中被 pop 后再写 signal 会抛
/// `SignalsWriteAfterDisposeError`。两者要么都不做（现状），要么一起做。
/// 理由见 frontend/state-management.md「什么时候才需要 dispose」。
Future<Result<void, Failure>> _drive<T>(
  Signal<AsyncState<T>> signal,
  Future<Result<T, Failure>> Function() task,
) async {
  final callId = (_latestCallId[signal] ?? 0) + 1;
  _latestCallId[signal] = callId;

  // 有旧数据就保留（刷新中），没有才清成 loading；data(null) 视同没有数据。
  // 用 peek() 读旧值：命令式读取不该建立订阅（理由见 frontend/state-management.md）。
  final previous = signal.peek().value;
  signal.value = previous == null
      ? AsyncState<T>.loading()
      : AsyncState<T>.dataRefreshing(previous);

  Result<T, Failure> result;
  try {
    result = await task();
  } catch (e, stackTrace) {
    // 原始异常只进日志，用户侧给一个可翻译的通用 code
    Logging.error('runAsync 未捕获异常', exception: e, stackTrace: stackTrace);
    result = const Result.failure(UnknownFailure(code: FailureCode.unknown));
  }

  // 已被更新的调用取代：不回写 signal，避免旧响应覆盖新状态
  final superseded = _latestCallId[signal] != callId;

  return result.when<Result<void, Failure>>(
    success: (data) {
      if (!superseded) signal.value = AsyncState.data(data);
      return const Result.success(null);
    },
    failure: (failure) {
      if (!superseded) signal.value = AsyncState.error(failure);
      return Result.failure(failure);
    },
  );
}
