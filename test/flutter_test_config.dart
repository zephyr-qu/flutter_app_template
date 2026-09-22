import 'dart:async';

import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';

/// 为所有 widget 测试启用 leak tracking（检测未 dispose 的对象）。
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  LeakTesting.enable();
  LeakTesting.settings = LeakTesting.settings
      // Ignore objects created by test helpers (e.g., pumpWidget).
      .withIgnored(createdByTestHelpers: true);

  await testMain();
}
