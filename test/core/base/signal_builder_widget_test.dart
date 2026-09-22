import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signals_flutter/signals_flutter.dart';

/// 覆盖 `SignalBuilder` + `asyncSignal` 渲染 loading / data / error 三态。
///
/// 注意：**生产页面走的不是这条路**——页面统一是 `HookWidget` +
/// `useSignalValue` + `AsyncView`（见 frontend/state-management.md）。
/// 这里验证的是可选的 SignalBuilder 路线：需要把重建范围收缩到某棵子树时才用它。
void main() {
  group('asyncSignal + SignalBuilder three-state rendering', () {
    /// Helper widget that renders the three states of an asyncSignal.
    Widget buildTestApp(AsyncState<String> Function() readSignal) {
      return MaterialApp(
        home: Scaffold(
          body: SignalBuilder(
            builder: (context) {
              final async = readSignal();
              if (async.isLoading) {
                return const CircularProgressIndicator();
              }
              if (async.hasError) {
                return Text('Error: ${async.error}');
              }
              final data = async.value;
              if (data == null || data.isEmpty) {
                return const Text('Empty state');
              }
              return Text('Data: $data');
            },
          ),
        ),
      );
    }

    testWidgets('renders loading to data transition', (tester) async {
      final signal = asyncSignal<String>(AsyncState.data(''));

      await tester.pumpWidget(buildTestApp(() => signal.value));

      // Initial: empty data state
      expect(find.text('Empty state'), findsOneWidget);

      // Transition to loading
      signal.value = AsyncState<String>.loading();
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Transition to data
      signal.value = AsyncState.data('hello world');
      await tester.pump();
      expect(find.text('Data: hello world'), findsOneWidget);
    });

    testWidgets('renders loading to error transition', (tester) async {
      final signal = asyncSignal<String>(AsyncState.data(''));

      await tester.pumpWidget(buildTestApp(() => signal.value));

      // Initial: empty
      expect(find.text('Empty state'), findsOneWidget);

      // Loading
      signal.value = AsyncState<String>.loading();
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Error
      signal.value = AsyncState<String>.error('连接失败');
      await tester.pump();
      expect(find.text('Error: 连接失败'), findsOneWidget);
    });

    testWidgets('renders loading to data (list) to error transition', (
      tester,
    ) async {
      // Use a list signal to match the common pattern (e.g., ArticleViewModel)
      final signal = asyncSignal<List<String>>(AsyncState.data([]));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SignalBuilder(
              builder: (context) {
                final async = signal.value;
                if (async.isLoading) {
                  return const CircularProgressIndicator();
                }
                if (async.hasError) {
                  return Text('Error: ${async.error}');
                }
                final data = async.value;
                if (data == null || data.isEmpty) {
                  return const Text('No items');
                }
                return Text('${data.length} items');
              },
            ),
          ),
        ),
      );

      // Initial empty
      expect(find.text('No items'), findsOneWidget);

      // Loading
      signal.value = AsyncState<List<String>>.loading();
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Data
      signal.value = AsyncState.data(['a', 'b', 'c']);
      await tester.pump();
      expect(find.text('3 items'), findsOneWidget);

      // Error
      signal.value = AsyncState<List<String>>.error('服务器错误');
      await tester.pump();
      expect(find.text('Error: 服务器错误'), findsOneWidget);
    });

    testWidgets('SignalBuilder rebuilds on signal change', (tester) async {
      final signal = asyncSignal<String>(AsyncState.data('initial'));
      var rebuildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: SignalBuilder(
            builder: (context) {
              rebuildCount++;
              return Text(signal.value.value ?? '');
            },
          ),
        ),
      );

      // Initial build
      expect(rebuildCount, 1);
      expect(find.text('initial'), findsOneWidget);

      // Update signal — triggers rebuild
      signal.value = AsyncState.data('updated');
      await tester.pump();
      expect(find.text('updated'), findsOneWidget);
      // Should be 1 initial + 1 update = 2
      expect(rebuildCount, 2);
    });
  });
}
