import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:my_app/core/base/failure.dart';
import 'package:my_app/core/base/result.dart';
import 'package:my_app/core/ui/loading_indicator.dart';
import 'package:my_app/features/sample/data/models/sample_item.dart';
import 'package:my_app/features/sample/data/sample_providers.dart';
import 'package:my_app/features/sample/data/sample_repository.dart';
import 'package:my_app/features/sample/page/sample_list_page.dart';

import '../../../support/app_test_harness.dart';

class MockSampleRepository extends Mock implements SampleRepository;

/// 这一页是「新增 feature 时照抄」的金标准，所以三态与重试都要有测试兜住。
void main() {
  const item = SampleItem(id: 1, title: '示例条目一', body: '正文');

  late MockSampleRepository repo;
  late ProviderContainer container;

  /// 仓库下一次返回什么由测试改它，而不是重新打桩：`verify` 的计数会被换桩搅乱。
  late Result<List<SampleItem>, Failure> result;

  setUp(() {
    repo = MockSampleRepository();
    result = const Result.success(<SampleItem>[]);
    when(repo.getItems).thenAnswer((_) async => result);

    // 页面的注入点就是 ProviderScope 的 overrides —— 页面本身不需要任何
    // 构造参数（这是 Riverpod 相对 getIt 方案省掉的东西）
    container = ProviderContainer(
      retry: noRetry,
      overrides: [sampleRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
  });

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(
      wrapPage(const SampleListPage(), container: container),
    );
  }

  testWidgets('首次加载显示整屏 loading', (tester) async {
    final pending = Completer<Result<List<SampleItem>, Failure>>();
    when(repo.getItems).thenAnswer((_) => pending.future);

    await pumpPage(tester);
    await tester.pump();

    expect(find.byType(LoadingIndicator), findsOneWidget);

    // 收尾：留着一个未完成的 future 会让后续断言落在 loading 上
    pending.complete(const Result.success(<SampleItem>[]));
    await tester.pumpAndSettle();
  });

  testWidgets('有数据时渲染列表', (tester) async {
    result = const Result.success(<SampleItem>[item]);

    await pumpPage(tester);
    await tester.pumpAndSettle();

    expect(find.text('示例条目一'), findsOneWidget);
    expect(find.text('正文'), findsOneWidget);
    // 空态与列表态都要能下拉刷新
    expect(find.byType(RefreshIndicator), findsOneWidget);
  });

  testWidgets('空列表时渲染空态（同样可下拉刷新）', (tester) async {
    await pumpPage(tester);
    await tester.pumpAndSettle();

    expect(find.text('暂无示例数据'), findsOneWidget);
    expect(find.byType(RefreshIndicator), findsOneWidget);
  });

  testWidgets('失败时显示可翻译的错误文案，点重试会重新拉取', (tester) async {
    result = const Result.failure(NetworkFailure(code: FailureCode.timeout));

    await pumpPage(tester);
    await tester.pumpAndSettle();

    expect(find.text('出错了'), findsOneWidget);
    // 文案由 Failure 的错误码翻译而来，不是「未知错误」
    expect(find.text('请求超时'), findsOneWidget);

    // 换成能成功的实现：重试真的生效的话，列表应该渲染出来
    result = const Result.success(<SampleItem>[item]);

    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();

    expect(find.text('示例条目一'), findsOneWidget);
    // 只 verify 一次：mocktail 的 verify 会把命中的调用消耗掉，
    // 先 called(1) 再 called(2) 只会看到剩下那一次
    verify(() => repo.getItems()).called(2);
  });
}
