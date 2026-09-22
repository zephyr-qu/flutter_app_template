import 'package:flutter_test/flutter_test.dart';
import 'package:signals_flutter/signals_flutter.dart';

/// 信号基础行为冒烟测试。
///
/// 这里验证的是 signals 包本身的用法约定（ViewModel 直接公开 signal），
/// 项目并没有 BaseViewModel 基类 —— 共享逻辑在 `lib/core/base/run_async.dart`。
final class SignalHolder {
  final FlutterSignal<int> counter = signal(0);

  Future<void> delayedOp() async {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    counter.value++;
  }
}

void main() {
  group('signals basics', () {
    test('signal keeps its initial value', () {
      final holder = SignalHolder();
      expect(holder.counter.value, equals(0));
    });

    test('signal updates correctly', () {
      final holder = SignalHolder();
      holder.counter.value = 42;
      expect(holder.counter.value, equals(42));
    });
  });
}
