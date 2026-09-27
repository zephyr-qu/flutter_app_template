import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:my_app/core/base/failure.dart';
import 'package:my_app/core/base/result.dart';
import 'package:my_app/core/ui/loading_indicator.dart';
import 'package:my_app/features/article/data/article_repository.dart';
import 'package:my_app/features/article/data/models/article.dart';
import 'package:my_app/features/article/logic/article_view_model.dart';
import 'package:my_app/features/article/page/article_detail_page.dart';

import '../../../support/app_test_harness.dart';

class MockArticleRepository extends Mock implements ArticleRepository;

/// 注意：`LoadingIndicator` 内部是会无限循环的 `CircularProgressIndicator`，
/// 所以只要它还在屏幕上就不能用 `pumpAndSettle`（永远 settle 不了）。
/// 这个文件统一用显式 `pump`。
void main() {
  late MockArticleRepository repo;
  late ArticleViewModel viewModel;

  const article = Article(id: 1, title: '第一篇文章', body: '正文');

  setUp(() {
    repo = MockArticleRepository();
    // 直接构造 ViewModel 注入页面：不需要 GetIt，也不需要 setUpTestApp()
    viewModel = ArticleViewModel(repo);
  });

  Future<void> pumpPage(WidgetTester tester) {
    return tester.pumpWidget(
      wrapPage(ArticleDetailPage(articleId: article.id, viewModel: viewModel)),
    );
  }

  group('ArticleDetailPage — 三态', () {
    testWidgets('加载中显示 LoadingIndicator', (tester) async {
      final completer = Completer<Result<Article, Failure>>();
      when(() => repo.getArticle(1)).thenAnswer((_) => completer.future);

      await pumpPage(tester);
      await tester.pump();

      expect(find.byType(LoadingIndicator), findsOneWidget);

      // 收尾，避免留下未完成的 Future
      completer.complete(const Result.success(article));
      await tester.pump();
    });

    testWidgets('有数据时渲染标题与正文', (tester) async {
      when(() => repo.getArticle(1))
          .thenAnswer((_) async => const Result.success(article));

      await pumpPage(tester);
      await tester.pump();
      await tester.pump();

      expect(find.text('第一篇文章'), findsOneWidget);
      expect(find.text('正文'), findsOneWidget);
    });
  });

  group('ArticleDetailPage — selectedArticle 的 nullable 分支', () {
    testWidgets('data(null) 不崩，按 loading 渲染', (tester) async {
      when(() => repo.getArticle(1))
          .thenAnswer((_) async => const Result.success(article));

      await pumpPage(tester);
      await tester.pump();
      await tester.pump();
      expect(find.text('正文'), findsOneWidget);

      // clearSelected() 写的正是 AsyncState.data(null)（真实链路里由卸载触发）。
      // 改前页面这里是 `d!`，会抛 `Null check operator used on a null value`。
      viewModel.clearSelected();
      await tester.pump();

      expect(tester.takeException(), isNull, reason: 'data(null) 不能走空断言');
      expect(find.byType(LoadingIndicator), findsOneWidget);
    });
  });
}
