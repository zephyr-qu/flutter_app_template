import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/base/failure.dart';
import 'package:my_app/core/base/result.dart';
import 'package:my_app/core/base/run_async.dart';
import 'package:signals_flutter/signals_flutter.dart';

void main() {
  group('runAsync', () {
    test('成功后信号设为 data', () async {
      final signal = asyncSignal<String>(AsyncState.data(''));
      final result = await runAsync(
        signal,
        () async => const Result.success('hello'),
      );

      expect(result.isSuccess, isTrue);
      expect(signal.value.value, 'hello');
      expect(signal.value.isLoading, isFalse);
      expect(signal.value.hasError, isFalse);
    });

    test('失败后信号设为 error，载荷是 Failure 对象（供展示层翻译）', () async {
      final signal = asyncSignal<String>(AsyncState.data(''));
      Future<Result<String, Failure>> task() async =>
          const Result.failure(NetworkFailure(code: FailureCode.connection));
      final result = await runAsync(signal, task);

      expect(result.isFailure, isTrue);
      expect(signal.value.hasError, isTrue);
      expect(
        signal.value.error,
        isA<NetworkFailure>().having(
          (f) => f.code,
          'code',
          FailureCode.connection,
        ),
      );
      expect(signal.value.isLoading, isFalse);
    });

    test('执行中状态为 loading', () async {
      final signal = asyncSignal<String>(AsyncState.data(''));

      final future = runAsync(signal, () async {
        await Future<void>.delayed(const Duration(seconds: 1));
        return const Result.success('done');
      });

      expect(signal.value.isLoading, isTrue);
      await future;
    });

    test('异常时信号设为 error 并返回 Failure，原始异常不外泄', () async {
      final signal = asyncSignal<int>(AsyncState.data(0));
      final result = await runAsync(
        signal,
        () async => throw Exception('内部细节 accessToken=secret'),
      );

      expect(result.isFailure, isTrue);
      expect(signal.value.hasError, isTrue);
      expect(signal.value.isLoading, isFalse);
      // error 载荷是 Failure，异常文本只进日志
      expect(
        signal.value.error,
        isA<UnknownFailure>().having(
          (f) => f.code,
          'code',
          FailureCode.unknown,
        ),
      );
      expect('${signal.value.error}', isNot(contains('secret')));
    });

    test('loading 状态在成功前设置', () async {
      final signal = asyncSignal<int>(AsyncState.data(0));

      // 在 runAsync 执行前先检查 loading
      late Future<Result<void, Failure>> future;
      future = runAsync(signal, () async {
        expect(signal.value.isLoading, isTrue);
        return const Result.success(42);
      });

      await future;
      expect(signal.value.value, 42);
    });
  });

  group('runAsync 并发：最后一次胜出', () {
    test('后发起的调用先完成时，先发起的旧响应不覆盖新状态', () async {
      final signal = asyncSignal<String>(AsyncState.data(''));
      final oldTask = Completer<Result<String, Failure>>();
      final newTask = Completer<Result<String, Failure>>();

      // 首屏加载（旧，慢）；紧接着下拉刷新（新，快）
      final oldCall = runAsync(signal, () => oldTask.future);
      final newCall = runAsync(signal, () => newTask.future);

      newTask.complete(const Result.success('新的'));
      await newCall;
      expect(signal.value.value, '新的');

      // 旧响应后到：不得覆盖
      oldTask.complete(const Result.success('旧的'));
      final oldResult = await oldCall;

      expect(signal.value.value, '新的');
      expect(signal.value.isLoading, isFalse);
      expect(oldResult.isSuccess, isTrue, reason: '被取代的调用仍如实返回自己 task 的结果');
    });

    test('被取代的调用失败时，不把 error 写进信号', () async {
      final signal = asyncSignal<String>(AsyncState.data(''));
      final oldTask = Completer<Result<String, Failure>>();
      final newTask = Completer<Result<String, Failure>>();

      final oldCall = runAsync(signal, () => oldTask.future);
      final newCall = runAsync(signal, () => newTask.future);

      newTask.complete(const Result.success('新的'));
      await newCall;

      oldTask.complete(
        const Result.failure(NetworkFailure(code: FailureCode.connection)),
      );
      final oldResult = await oldCall;

      expect(signal.value.hasError, isFalse, reason: '旧调用的失败不得污染新状态');
      expect(signal.value.value, '新的');
      expect(oldResult.isFailure, isTrue, reason: '旧调用仍如实返回自己的失败');
    });

    test('被取代的调用迟到的异常，不把新数据打成 error', () async {
      final signal = asyncSignal<String>(AsyncState.data(''));
      final newTask = Completer<Result<String, Failure>>();
      final oldTask = Completer<void>();

      // 旧调用先挂起，晚于新调用才抛
      final oldCall = runAsync<String>(signal, () async {
        await oldTask.future;
        throw StateError('boom');
      });
      final newCall = runAsync(signal, () => newTask.future);

      newTask.complete(const Result.success('新的'));
      await newCall;

      oldTask.complete();
      final oldResult = await oldCall;

      expect(signal.value.value, '新的');
      expect(signal.value.hasError, isFalse, reason: '迟到的异常不得污染新状态');
      expect(oldResult.isFailure, isTrue, reason: '异常转成 Failure 返回，不外泄');
    });

    test('最新一次的失败照常写入 error（不是一律不写）', () async {
      final signal = asyncSignal<String>(AsyncState.data(''));

      await runAsync(
        signal,
        () async => const Result<String, Failure>.failure(
          NetworkFailure(code: FailureCode.timeout),
        ),
      );

      expect(signal.value.hasError, isTrue);
      expect(
        signal.value.error,
        isA<NetworkFailure>().having(
          (f) => f.code,
          'code',
          FailureCode.timeout,
        ),
      );
    });

    test('序号按 signal 隔离：不同 signal 的并发互不影响', () async {
      final listSignal = asyncSignal<String>(AsyncState.data(''));
      final detailSignal = asyncSignal<String>(AsyncState.data(''));
      final slowTask = Completer<Result<String, Failure>>();

      final slowCall = runAsync(listSignal, () => slowTask.future);
      await runAsync(detailSignal, () async => const Result.success('详情'));

      slowTask.complete(const Result.success('列表'));
      await slowCall;

      expect(listSignal.value.value, '列表', reason: '没有更新的调用取代它，应当正常写入');
      expect(detailSignal.value.value, '详情');
    });

    test('顺序调用（非并发）不受影响', () async {
      final signal = asyncSignal<int>(AsyncState.data(0));

      await runAsync(signal, () async => const Result.success(1));
      expect(signal.value.value, 1);

      await runAsync(signal, () async => const Result.success(2));
      expect(signal.value.value, 2);
    });
  });

  group('runAsync 刷新：保留旧数据', () {
    /// 与页面里 `AsyncState.map` 的用法一致，用来断言「界面上会走哪个分支」
    String render(Signal<AsyncState<String>> signal) => signal.value.map(
      loading: () => 'loading',
      error: (Object? error) => 'error',
      data: (value) => 'data:$value',
    );

    test('首次加载（无旧数据）是纯 loading，界面走 loading 分支', () async {
      final signal = asyncSignal<String>(AsyncState.loading());
      final task = Completer<Result<String, Failure>>();

      final future = runAsync(signal, () => task.future);

      expect(signal.value.isLoading, isTrue);
      expect(signal.value.hasValue, isFalse);
      expect(signal.value.isRefreshing, isFalse);
      expect(render(signal), 'loading');

      task.complete(const Result.success('新的'));
      await future;
    });

    test('已有数据时进入 refreshing，界面继续走 data 分支', () async {
      final signal = asyncSignal<String>(AsyncState.data('旧的'));
      final task = Completer<Result<String, Failure>>();

      final future = runAsync(signal, () => task.future);

      expect(signal.value.isRefreshing, isTrue);
      expect(signal.value.hasValue, isTrue, reason: '旧数据必须还在');
      expect(render(signal), 'data:旧的', reason: '刷新期间界面渲染旧数据，不闪成 loading');

      task.complete(const Result.success('新的'));
      await future;

      expect(render(signal), 'data:新的');
      expect(signal.value.isRefreshing, isFalse);
    });

    test('刷新失败时不再保留旧数据，进入 error', () async {
      final signal = asyncSignal<String>(AsyncState.data('旧的'));

      await runAsync(
        signal,
        () async => const Result<String, Failure>.failure(
          NetworkFailure(code: FailureCode.connection),
        ),
      );

      expect(signal.value.hasError, isTrue);
      expect(render(signal), 'error');
    });

    test('data(null) 视同没有数据：仍回到 loading', () async {
      // selectedArticle 这类 nullable 信号，clearSelected() 后就是 data(null)
      final signal = asyncSignal<String?>(AsyncState.data(null));
      final task = Completer<Result<String?, Failure>>();

      final future = runAsync(signal, () => task.future);

      expect(signal.value.isRefreshing, isFalse);
      expect(signal.value.hasValue, isFalse);

      task.complete(const Result.success('来了'));
      await future;
    });
  });

  group('runAsyncVoid：任务只报成败', () {
    test('成功时把信号置为 onSuccess，T 不需要手写', () async {
      // T = String?：若走 runAsync，void 会把 T 塌成 void 并在这里抛类型错
      final signal = asyncSignal<String?>(AsyncState.data('旧值'));

      final result = await runAsyncVoid(
        signal,
        () async => const Result<void, Failure>.success(null),
        onSuccess: null,
      );

      expect(result.isSuccess, isTrue);
      expect(signal.value.value, isNull);
      expect(signal.value.isLoading, isFalse);
      expect(signal.value.hasError, isFalse);
    });

    test('失败时 error 写进信号，Failure 原样返回', () async {
      final signal = asyncSignal<String?>(AsyncState.data('旧值'));

      final result = await runAsyncVoid(
        signal,
        () async => const Result<void, Failure>.failure(
          ServerFailure(code: FailureCode.conflict),
        ),
        onSuccess: null,
      );

      expect(result.isFailure, isTrue);
      expect(
        signal.value.error,
        isA<ServerFailure>().having(
          (f) => f.code,
          'code',
          FailureCode.conflict,
        ),
      );
      expect(signal.value.isLoading, isFalse);
    });

    test('共享同一套骨架：无旧数据时先 loading', () async {
      final signal = asyncSignal<String?>(AsyncState.data(null));
      final task = Completer<Result<void, Failure>>();

      final future = runAsyncVoid(signal, () => task.future, onSuccess: '新');

      expect(signal.value.isLoading, isTrue);
      expect(signal.value.hasValue, isFalse);

      task.complete(const Result.success(null));
      await future;

      expect(signal.value.value, '新');
    });

    test('对照：把 void 任务交给 runAsync 会塌成 T=void 并抛错', () async {
      // 这条是「为什么需要 runAsyncVoid」的现场证据。若哪天 Dart 的推断不再这样解，
      // 它会失败——那时该做的是删掉 runAsyncVoid，而不是以为代码坏了。
      final signal = asyncSignal<String?>(AsyncState.data(null));

      await expectLater(
        runAsync(signal, () async => const Result<void, Failure>.success(null)),
        throwsA(isA<TypeError>()),
      );
    });
  });
}
