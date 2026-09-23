import 'package:app_core/base/failure.dart';
import 'package:app_core/base/result.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:my_app/features/sample/data/models/sample_item.dart';
import 'package:my_app/features/sample/data/sample_providers.dart';
import 'package:my_app/features/sample/data/sample_repository.dart';
import 'package:my_app/features/sample/logic/sample_list_notifier.dart';

import '../../../support/app_test_harness.dart' show noRetry;

class MockSampleRepository extends Mock implements SampleRepository;

/// `SampleListNotifier` 只做一件事：把仓库的 `Result` 翻译成 `AsyncValue`。
/// 「上一次胜出」「刷新保留旧值」都已经是框架行为，不该在这里另测一遍。
void main() {
  const item = SampleItem(id: 1, title: '示例条目一', body: '正文');

  late MockSampleRepository repo;
  late ProviderContainer container;

  setUp(() {
    repo = MockSampleRepository();
    container = ProviderContainer(
      retry: noRetry,
      overrides: [sampleRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
  });

  /// 建订阅以保住 autoDispose 的 provider（不订阅的话两次 read 之间会被释放）。
  ///
  /// 必须在打桩**之后**调用：`listen` 会立刻跑一次 `build()`，提前调用等于拿一个
  /// 还没打桩的 mock 去调仓库 —— mocktail 返回 null，`build` 里当场类型错。
  void warmUp() {
    container.listen(sampleListProvider, (_, _) {});
  }

  test('成功时把 Result 展平成数据', () async {
    when(repo.getItems)
        .thenAnswer((_) async => const Result.success(<SampleItem>[item]));
    warmUp();

    expect(await container.read(sampleListProvider.future), [item]);
  });

  test('失败时抛出 Failure 本身（不是另造的包装异常）', () async {
    when(repo.getItems).thenAnswer(
      (_) async =>
          const Result.failure(NetworkFailure(code: FailureCode.timeout)),
    );
    warmUp();

    await expectLater(
      container.read(sampleListProvider.future),
      throwsA(isA<NetworkFailure>()),
    );

    // ErrorText 要靠这个对象翻译错误码；包一层就只剩「未知错误」
    expect(container.read(sampleListProvider).error, isA<NetworkFailure>());
  });

  test('刷新时保留旧数据（isRefreshing，而不是回落 loading）', () async {
    when(repo.getItems)
        .thenAnswer((_) async => const Result.success(<SampleItem>[item]));
    warmUp();
    await container.read(sampleListProvider.future);

    final refreshing = container.refresh(sampleListProvider);

    expect(refreshing.isRefreshing, isTrue);
    expect(refreshing.value, [item]);
  });
}
