import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/ui/async_view.dart';
import 'package:signals_flutter/signals_flutter.dart';

void main() {
  /// 每个分支渲染成可断言的纯文本，不依赖主题与 l10n
  Widget wrap(
    AsyncState<String> state, {
    Widget Function()? refreshing,
    Widget Function()? reloading,
  }) {
    return MaterialApp(
      home: AsyncView<String>(
        state: state,
        data: (value) => Text('data:$value'),
        loading: () => const Text('loading'),
        error: (error, stackTrace) => Text('error:$error'),
        refreshing: refreshing,
        reloading: reloading,
      ),
    );
  }

  group('AsyncView — 三个稳定状态', () {
    testWidgets('loading 走 loading 分支', (tester) async {
      await tester.pumpWidget(wrap(AsyncState<String>.loading()));

      expect(find.text('loading'), findsOneWidget);
    });

    testWidgets('data 走 data 分支并带出值', (tester) async {
      await tester.pumpWidget(wrap(AsyncState<String>.data('hello')));

      expect(find.text('data:hello'), findsOneWidget);
    });

    testWidgets('error 走 error 分支，error 与 stackTrace 都传给回调', (tester) async {
      // 这条正是 AsyncState.map 会崩的路径：回调带两个参数。
      // 在 AsyncView 里它是具名的，第二个参数拿到的是 AsyncState 携带的 trace。
      final trace = StackTrace.fromString('boom-trace');
      Object? receivedError;
      StackTrace? receivedTrace;

      await tester.pumpWidget(
        MaterialApp(
          home: AsyncView<String>(
            state: AsyncState<String>.error('boom', trace),
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
    });
  });

  group('AsyncView — 刷新 / 重载', () {
    // 这一组同时是「分支顺序」的回归：`AsyncDataRefreshing` /
    // `AsyncDataReloading` 同时实现了 `AsyncLoading`，若 `switch` 把
    // `AsyncLoading` 放在前面，下面的旧数据会被 loading 吞掉。
    testWidgets('dataRefreshing：缺省继续渲染旧数据，提供 refreshing 则走它', (tester) async {
      await tester.pumpWidget(
        wrap(AsyncState<String>.dataRefreshing('cached')),
      );

      expect(find.text('data:cached'), findsOneWidget);
      expect(find.text('loading'), findsNothing);

      await tester.pumpWidget(
        wrap(
          AsyncState<String>.dataRefreshing('cached'),
          refreshing: () => const Text('refreshing'),
        ),
      );

      expect(find.text('refreshing'), findsOneWidget);
      expect(find.text('data:cached'), findsNothing);
    });

    testWidgets('dataReloading：缺省继续渲染旧数据，提供 reloading 则走它', (tester) async {
      await tester.pumpWidget(wrap(AsyncState<String>.dataReloading('cached')));

      expect(find.text('data:cached'), findsOneWidget);

      await tester.pumpWidget(
        wrap(
          AsyncState<String>.dataReloading('cached'),
          reloading: () => const Text('reloading'),
        ),
      );

      expect(find.text('reloading'), findsOneWidget);
    });

    testWidgets('errorRefreshing：缺省退回 error，提供 refreshing 则走它', (tester) async {
      await tester.pumpWidget(
        wrap(AsyncState<String>.errorRefreshing('offline', StackTrace.empty)),
      );

      expect(find.text('error:offline'), findsOneWidget);

      await tester.pumpWidget(
        wrap(
          AsyncState<String>.errorRefreshing('offline', StackTrace.empty),
          refreshing: () => const Text('refreshing'),
        ),
      );

      expect(find.text('refreshing'), findsOneWidget);
    });

    testWidgets('errorReloading：缺省退回 error，提供 reloading 则走它', (tester) async {
      await tester.pumpWidget(
        wrap(AsyncState<String>.errorReloading('offline', StackTrace.empty)),
      );

      expect(find.text('error:offline'), findsOneWidget);

      await tester.pumpWidget(
        wrap(
          AsyncState<String>.errorReloading('offline', StackTrace.empty),
          reloading: () => const Text('reloading'),
        ),
      );

      expect(find.text('reloading'), findsOneWidget);
    });
  });
}
