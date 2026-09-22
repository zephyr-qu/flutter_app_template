import 'dart:async';

import 'package:app_core/base/failure.dart';
import 'package:app_core/base/result.dart';
import 'package:app_core/ui/empty_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:my_app/core/ui/error_text.dart';
import 'package:my_app/core/ui/loading_indicator.dart';
import 'package:my_app/features/article/data/article_repository.dart';
import 'package:my_app/features/article/data/models/article.dart';
import 'package:my_app/features/article/logic/article_view_model.dart';
import 'package:my_app/features/article/page/article_list_page.dart';

import '../../../support/app_test_harness.dart';

class MockArticleRepository extends Mock implements ArticleRepository;

/// 注意：`LoadingIndicator` 内部是会无限循环的 `CircularProgressIndicator`，
/// 所以只要它还在屏幕上就不能用 `pumpAndSettle`（永远 settle 不了）。
/// 这个文件统一用显式 `pump`。
void main() {
  late MockArticleRepository repo;
  late ArticleViewModel viewModel;

  setUp(() {
    repo = MockArticleRepository();
    // 直接构造 ViewModel 注入页面：不需要 GetIt，也不需要 setUpTestApp()
    viewModel = ArticleViewModel(repo);
  });

  group('ArticleListPage — 三态', () {
    testWidgets('加载中显示 LoadingIndicator', (tester) async {
      final completer = Completer<Result<List<Article>, Failure>>();
      when(() => repo.getArticles()).thenAnswer((_) => completer.future);

      await tester.pumpWidget(wrapPage(ArticleListPage(viewModel: viewModel)));
      await tester.pump();

      expect(find.byType(LoadingIndicator), findsOneWidget);

      // 收尾，避免留下未完成的 Future
      completer.complete(const Result.success(<Article>[]));
      await tester.pump();
    });

    testWidgets('空列表显示空状态文案', (tester) async {
      when(() => repo.getArticles())
          .thenAnswer((_) async => const Result.success(<Article>[]));

      await tester.pumpWidget(wrapPage(ArticleListPage(viewModel: viewModel)));
      await tester.pump();
      await tester.pump();

      expect(find.byType(EmptyWidget), findsOneWidget);
      expect(find.text('暂无文章'), findsOneWidget);
    });

    testWidgets('有数据时渲染文章卡片', (tester) async {
      when(() => repo.getArticles()).thenAnswer(
        (_) async =>
            const Result.success([Article(id: 1, title: '第一篇文章', body: '正文')]),
      );

      await tester.pumpWidget(wrapPage(ArticleListPage(viewModel: viewModel)));
      await tester.pump();
      await tester.pump();

      expect(find.text('第一篇文章'), findsOneWidget);
      expect(find.text('点击阅读更多...'), findsOneWidget);
      expect(find.text('阅读'), findsOneWidget);
    });
  });

  group('ArticleListPage — 错误状态按当前语言展示', () {
    testWidgets('中文下显示中文错误文案', (tester) async {
      when(() => repo.getArticles()).thenAnswer(
        (_) async =>
            const Result.failure(NetworkFailure(code: FailureCode.connection)),
      );

      await tester.pumpWidget(wrapPage(ArticleListPage(viewModel: viewModel)));
      await tester.pump();
      await tester.pump();

      expect(find.byType(ErrorText), findsOneWidget);
      // Failure 只带 code，这句文案是展示层翻译出来的
      expect(find.text('网络连接失败'), findsOneWidget);
    });

    testWidgets('404 显示「资源不存在」', (tester) async {
      when(() => repo.getArticles()).thenAnswer(
        (_) async =>
            const Result.failure(ServerFailure(code: FailureCode.notFound)),
      );

      await tester.pumpWidget(wrapPage(ArticleListPage(viewModel: viewModel)));
      await tester.pump();
      await tester.pump();

      expect(find.text('资源不存在'), findsOneWidget);
      expect(find.text('重试'), findsOneWidget);
    });

    testWidgets('点击重试会再次请求', (tester) async {
      when(() => repo.getArticles()).thenAnswer(
        (_) async =>
            const Result.failure(NetworkFailure(code: FailureCode.timeout)),
      );

      await tester.pumpWidget(wrapPage(ArticleListPage(viewModel: viewModel)));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('重试'));
      await tester.pump();
      await tester.pump();

      verify(() => repo.getArticles()).called(2);
    });
  });

  group('ArticleListPage — 下拉刷新', () {
    testWidgets('刷新期间保留旧列表，不换成 LoadingIndicator', (tester) async {
      // 要够长才可滚动，否则 RefreshIndicator 不会被触发
      final firstPage = List<Article>.generate(
        20,
        (i) => Article(id: i, title: '第 $i 篇', body: '正文'),
      );
      final refresh = Completer<Result<List<Article>, Failure>>();
      var callCount = 0;
      when(() => repo.getArticles()).thenAnswer((_) {
        callCount++;
        return callCount == 1
            ? Future.value(Result.success(firstPage))
            : refresh.future;
      });

      await tester.pumpWidget(wrapPage(ArticleListPage(viewModel: viewModel)));
      await tester.pump();
      await tester.pump();
      expect(find.text('第 0 篇'), findsOneWidget);

      // 下拉触发刷新，第二次请求被挂住
      await tester.fling(find.text('第 0 篇'), const Offset(0, 300), 1000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(callCount, 2, reason: '下拉确实触发了刷新请求，否则这条断言是空转');
      expect(find.text('第 0 篇'), findsOneWidget, reason: '刷新期间旧列表必须还在屏幕上');
      expect(find.byType(LoadingIndicator), findsNothing);

      refresh.complete(const Result.success(<Article>[]));
      await tester.pump();
      await tester.pump();
    });

    testWidgets('内容不足一屏（仅 1 条）时下拉刷新依然生效', (tester) async {
      final refresh = Completer<Result<List<Article>, Failure>>();
      var callCount = 0;
      when(() => repo.getArticles()).thenAnswer((_) {
        callCount++;
        return callCount == 1
            ? Future.value(
                const Result.success([
                  Article(id: 1, title: '第一篇文章', body: '正文'),
                ]),
              )
            : refresh.future;
      });

      await tester.pumpWidget(wrapPage(ArticleListPage(viewModel: viewModel)));
      await tester.pump();
      await tester.pump();
      expect(find.text('第一篇文章'), findsOneWidget);

      // 默认 physics 下这种「撑不满一屏」的列表不接受下拉，会静默刷不动
      await tester.fling(find.text('第一篇文章'), const Offset(0, 300), 1000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(callCount, 2, reason: '不足一屏也必须能触发刷新');

      refresh.complete(const Result.success(<Article>[]));
      await tester.pump();
      await tester.pump();
    });

    testWidgets('空列表也能下拉刷新（不是死胡同）', (tester) async {
      final refresh = Completer<Result<List<Article>, Failure>>();
      var callCount = 0;
      when(() => repo.getArticles()).thenAnswer((_) {
        callCount++;
        return callCount == 1
            ? Future.value(const Result.success(<Article>[]))
            : refresh.future;
      });

      await tester.pumpWidget(wrapPage(ArticleListPage(viewModel: viewModel)));
      await tester.pump();
      await tester.pump();
      expect(find.byType(EmptyWidget), findsOneWidget);
      // 结构性断言：改动前空状态直接返回 EmptyWidget，树里根本没有
      // RefreshIndicator，下拉刷新不可能被触发
      expect(find.byType(RefreshIndicator), findsOneWidget);

      await tester.fling(find.byType(EmptyWidget), const Offset(0, 300), 1000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(callCount, 2, reason: '空状态也要包在 RefreshIndicator 里且可滚动');

      refresh.complete(
        const Result.success([Article(id: 1, title: '第一篇文章', body: '正文')]),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('第一篇文章'), findsOneWidget, reason: '刷新后应渲染新数据');
    });
  });
}
