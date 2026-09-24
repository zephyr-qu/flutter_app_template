import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/ui/async_view.dart';

import '../../support/app_test_harness.dart' show noRetry;

/// 每次 build 排一个新的 Completer：只有能精确控制「哪一次调用还没回来」，
/// 才构造得出 refreshing / reloading 这两种中间态。
///
/// 不手搓 `AsyncValue` 是**有意**的：`isRefreshing` / `isReloading` 怎么置、
/// 刷新时旧值保不保留都是框架行为，`copyWithPrevious` 又是 `@internal`，
/// 用真 provider 走一遍反而更接近线上。
///
/// ⚠️ 全程用 `tester.pump()` 驱动，**不要** `await provider.future`：
/// widget 测试的时钟是假的，riverpod 的调度任务不 pump 就不会跑，
/// 那个 await 会一直卡到测试超时（10 分钟）。
final _answers = <Completer<String>>[];

Completer<String> _nextAnswer() => _answers.removeAt(0);

final _answerProvider = FutureProvider<String>((ref) {
  final answer = Completer<String>();
  _answers.add(answer);
  return answer.future;
});

final _nullableAnswers = <Completer<String?>>[];

Completer<String?> _nextNullableAnswer() => _nullableAnswers.removeAt(0);

final _nullableProvider = FutureProvider<String?>((ref) {
  final answer = Completer<String?>();
  _nullableAnswers.add(answer);
  return answer.future;
});

void main() {
  late ProviderContainer container;

  setUp(() {
    _answers.clear();
    _nullableAnswers.clear();
    container = ProviderContainer(retry: noRetry);
    addTearDown(container.dispose);
  });

  /// 每个分支渲染成可断言的纯文本，不依赖主题与 l10n
  Widget wrap(
    AsyncValue<String> state, {
    Widget Function()? refreshing,
    Widget Function()? reloading,
  }) => MaterialApp(
    home: AsyncView<String>(
      state: state,
      data: (value) => Text('data:$value'),
      loading: () => const Text('loading'),
      error: (error, stackTrace) => Text('error:$error'),
      refreshing: refreshing,
      reloading: reloading,
    ),
  );

  Widget wrapNullable(
    AsyncValue<String?> state, {
    Widget Function()? refreshing,
  }) => MaterialApp(
    home: AsyncView<String?>(
      state: state,
      data: (value) => Text('data:$value'),
      loading: () => const Text('loading'),
      error: (error, stackTrace) => Text('error:$error'),
      refreshing: refreshing,
    ),
  );

  /// 把自己渲染成首帧（loading），并订阅 provider
  ///
  /// 必须 `listen`：provider 是 autoDispose，没订阅的话它在两次 read 之间会被
  /// 释放，重新 read 会造出一个**新**的 Completer，队列就对不上了。
  Future<void> pumpFirstFrame(WidgetTester tester) async {
    container.listen(_answerProvider, (_, _) {});
    await tester.pumpWidget(wrap(container.read(_answerProvider)));
  }

  /// 排空 riverpod 调度器留下的定时器：测试结束时还有 pending timer，
  /// binding 会直接判失败（`A Timer is still pending...`）。
  Future<void> drainScheduler(WidgetTester tester) =>
      tester.pump(const Duration(seconds: 1));

  group('AsyncView — 三个稳定状态', () {
    testWidgets('loading 走 loading 分支', (tester) async {
      await pumpFirstFrame(tester);

      expect(container.read(_answerProvider).isLoading, isTrue);
      expect(find.text('loading'), findsOneWidget);
    });

    testWidgets('data 走 data 分支并带出值', (tester) async {
      await pumpFirstFrame(tester);

      _nextAnswer().complete('hello');
      await tester.pump();
      await tester.pumpWidget(wrap(container.read(_answerProvider)));

      expect(find.text('data:hello'), findsOneWidget);

      await drainScheduler(tester);
    });

    testWidgets('error 走 error 分支，error 与 stackTrace 都传给回调', (tester) async {
      await pumpFirstFrame(tester);

      final trace = StackTrace.fromString('boom-trace');
      _nextAnswer().completeError('boom', trace);
      await tester.pump();

      Object? receivedError;
      StackTrace? receivedTrace;

      await tester.pumpWidget(
        MaterialApp(
          home: AsyncView<String>(
            state: container.read(_answerProvider),
            data: (value) => Text('data:$value'),
            loading: () => const Text('loading'),
            error: (error, stackTrace) {
              receivedError = error;
              receivedTrace = stackTrace;
              return const Text('error');
            },
          ),
        ),
      );

      expect(find.text('error'), findsOneWidget);
      expect(receivedError, 'boom');
      expect(receivedTrace, same(trace));

      await drainScheduler(tester);
    });
  });

  group('AsyncView — 刷新 / 重载', () {
    // 这一组同时是「分支顺序」的回归：刷新 / 重载期间 hasValue 或 hasError 仍为
    // 真，若把 hasValue 放在前面，旧数据（或错误）会把中间态吞掉。
    testWidgets('dataRefreshing：缺省继续渲染旧数据，提供 refreshing 则走它', (tester) async {
      await pumpFirstFrame(tester);
      _nextAnswer().complete('cached');
      await tester.pump();

      // 模拟下拉刷新：新一轮 loading 开始，但旧值仍在
      container.refresh(_answerProvider);
      await tester.pump();
      final refreshing = container.read(_answerProvider);
      expect(refreshing.isRefreshing, isTrue);
      expect(refreshing.value, 'cached');

      await tester.pumpWidget(wrap(refreshing));
      expect(find.text('data:cached'), findsOneWidget);
      expect(find.text('loading'), findsNothing);

      await tester.pumpWidget(
        wrap(refreshing, refreshing: () => const Text('refreshing')),
      );
      expect(find.text('refreshing'), findsOneWidget);
      expect(find.text('data:cached'), findsNothing);

      await drainScheduler(tester);
    });

    testWidgets('dataReloading：缺省继续渲染旧数据，提供 reloading 则走它', (tester) async {
      await pumpFirstFrame(tester);
      _nextAnswer().complete('cached');
      await tester.pump();

      // `asReload: true` 对应「依赖变化导致的重建」，与 refresh 区分开
      container.invalidate(_answerProvider, asReload: true);
      await tester.pump();
      final reloading = container.read(_answerProvider);
      expect(reloading.isReloading, isTrue);
      expect(reloading.value, 'cached');

      await tester.pumpWidget(wrap(reloading));
      expect(find.text('data:cached'), findsOneWidget);
      expect(find.text('loading'), findsNothing);

      await tester.pumpWidget(
        wrap(reloading, reloading: () => const Text('reloading')),
      );
      expect(find.text('reloading'), findsOneWidget);
      expect(find.text('data:cached'), findsNothing);

      await drainScheduler(tester);
    });

    testWidgets('errorRefreshing：缺省退回 error，提供 refreshing 则走它', (tester) async {
      await pumpFirstFrame(tester);
      _nextAnswer().completeError('offline', StackTrace.empty);
      await tester.pump();

      // 出错之后再来一轮刷新：旧状态是 error，新一轮还在飞
      container.refresh(_answerProvider);
      await tester.pump();
      final refreshing = container.read(_answerProvider);
      expect(refreshing.isRefreshing, isTrue);
      expect(refreshing.hasError, isTrue);

      await tester.pumpWidget(wrap(refreshing));
      expect(find.text('error:offline'), findsOneWidget);

      await tester.pumpWidget(
        wrap(refreshing, refreshing: () => const Text('refreshing')),
      );
      expect(find.text('refreshing'), findsOneWidget);
      expect(find.text('error:offline'), findsNothing);

      await drainScheduler(tester);
    });

    testWidgets('errorReloading：缺省退回 error，提供 reloading 则走它', (tester) async {
      await pumpFirstFrame(tester);
      _nextAnswer().completeError('offline', StackTrace.empty);
      await tester.pump();

      container.invalidate(_answerProvider, asReload: true);
      await tester.pump();
      final reloading = container.read(_answerProvider);
      expect(reloading.isReloading, isTrue);
      expect(reloading.hasError, isTrue);

      await tester.pumpWidget(wrap(reloading));
      expect(find.text('error:offline'), findsOneWidget);

      await tester.pumpWidget(
        wrap(reloading, reloading: () => const Text('reloading')),
      );
      expect(find.text('reloading'), findsOneWidget);
      expect(find.text('error:offline'), findsNothing);

      await drainScheduler(tester);
    });
  });

  group('AsyncView — 旧值为 null 视同没有数据', () {
    // 「旧值为 null 视同没有数据」：刷新时旧内容为 null 不当作有内容可展示，
    // 必须先过判空。语义见 frontend/state-management.md「渲染状态」。
    testWidgets('稳定态下 data(null) 照常走 data 分支', (tester) async {
      container.listen(_nullableProvider, (_, _) {});
      await tester.pumpWidget(wrapNullable(container.read(_nullableProvider)));
      expect(find.text('loading'), findsOneWidget);

      _nextNullableAnswer().complete(null);
      await tester.pump();
      await tester.pumpWidget(wrapNullable(container.read(_nullableProvider)));

      expect(find.text('data:null'), findsOneWidget);
      expect(find.text('loading'), findsNothing);

      await drainScheduler(tester);
    });

    testWidgets('刷新中旧值为 null 时走 loading，而不是 data(null)', (tester) async {
      container.listen(_nullableProvider, (_, _) {});
      await tester.pumpWidget(wrapNullable(container.read(_nullableProvider)));
      _nextNullableAnswer().complete(null);
      await tester.pump();

      container.refresh(_nullableProvider);
      await tester.pump();
      final refreshing = container.read(_nullableProvider);
      expect(refreshing.isRefreshing, isTrue);

      await tester.pumpWidget(wrapNullable(refreshing));

      expect(find.text('loading'), findsOneWidget);
      expect(find.text('data:null'), findsNothing);

      await drainScheduler(tester);
    });
  });
}
