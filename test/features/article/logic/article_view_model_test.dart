import 'dart:async';

import 'package:app_core/base/failure.dart';
import 'package:app_core/base/result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:my_app/features/article/data/article_repository.dart';
import 'package:my_app/features/article/data/models/article.dart';
import 'package:my_app/features/article/logic/article_view_model.dart';

class MockArticleRepository extends Mock implements ArticleRepository;

void main() {
  late MockArticleRepository mockRepo;
  late ArticleViewModel vm;

  setUp(() {
    mockRepo = MockArticleRepository();
    vm = ArticleViewModel(mockRepo);
  });

  group('ArticleViewModel', () {
    test('初始状态为 loading', () {
      expect(vm.articles.value.isLoading, isTrue);
      expect(vm.articles.value.hasError, isFalse);
      expect(vm.articles.value.value, isNull);
    });

    group('loadArticles()', () {
      test('成功后更新列表', () async {
        final articles = [
          const Article(id: 1, title: 'a', body: 'body a'),
          const Article(id: 2, title: 'b', body: 'body b'),
        ];
        when(() => mockRepo.getArticles())
            .thenAnswer((_) async => Result.success(articles));

        await vm.loadArticles();

        expect(vm.articles.value.value, hasLength(2));
        expect(vm.articles.value.value![0].title, 'a');
        expect(vm.articles.value.isLoading, isFalse);
        expect(vm.articles.value.hasError, isFalse);
      });

      test('失败后设置 error 状态', () async {
        when(() => mockRepo.getArticles()).thenAnswer(
          (_) async => const Result.failure(
            NetworkFailure(code: FailureCode.connection),
          ),
        );

        await vm.loadArticles();

        expect(vm.articles.value.hasError, isTrue);
        // error 载荷是 Failure 对象，文案留给展示层翻译
        expect(
          vm.articles.value.error,
          isA<NetworkFailure>().having(
            (f) => f.code,
            'code',
            FailureCode.connection,
          ),
        );
        expect(vm.articles.value.value, isNull);
        expect(vm.articles.value.isLoading, isFalse);
      });

      test('加载中时 isLoading 为 true', () {
        when(() => mockRepo.getArticles()).thenAnswer((_) async {
          await Future<void>.delayed(const Duration(seconds: 1));
          return const Result.success(<Article>[]);
        });

        final future = vm.loadArticles();

        expect(vm.articles.value.isLoading, isTrue);
        expect(future, completes);
      });

      test('首屏加载与下拉刷新并发时，先发出的旧响应不覆盖新数据', () async {
        // 第一次调用（useEffect 首屏）慢，第二次调用（下拉刷新）快
        final firstLoad = Completer<Result<List<Article>, Failure>>();
        final refresh = Completer<Result<List<Article>, Failure>>();
        var callCount = 0;
        when(() => mockRepo.getArticles()).thenAnswer((_) {
          callCount++;
          return callCount == 1 ? firstLoad.future : refresh.future;
        });

        final firstLoadFuture = vm.loadArticles();
        final refreshFuture = vm.loadArticles();

        refresh.complete(
          const Result.success([Article(id: 2, title: '新的', body: 'b')]),
        );
        await refreshFuture;

        // 旧响应后到：不得把列表打回旧数据
        firstLoad.complete(
          const Result.success([Article(id: 1, title: '旧的', body: 'a')]),
        );
        await firstLoadFuture;

        expect(vm.articles.value.value, hasLength(1));
        expect(vm.articles.value.value![0].title, '新的');
        expect(vm.articles.value.hasError, isFalse);
      });

      test('刷新时进入 refreshing 并保留旧列表，不闪成 loading', () async {
        final refresh = Completer<Result<List<Article>, Failure>>();
        var callCount = 0;
        when(() => mockRepo.getArticles()).thenAnswer((_) {
          callCount++;
          return callCount == 1
              ? Future.value(
                  const Result.success([
                    Article(id: 1, title: '旧的', body: 'a'),
                  ]),
                )
              : refresh.future;
        });

        await vm.loadArticles();
        expect(vm.articles.value.value, hasLength(1));

        // 下拉刷新：请求挂住
        final refreshFuture = vm.loadArticles();

        expect(vm.articles.value.isRefreshing, isTrue);
        expect(
          vm.articles.value.value?.first.title,
          '旧的',
          reason: '刷新期间旧列表必须还在（页面才不会整块换成 loading）',
        );

        refresh.complete(
          const Result.success([Article(id: 2, title: '新的', body: 'b')]),
        );
        await refreshFuture;

        expect(vm.articles.value.value?.first.title, '新的');
        expect(vm.articles.value.isRefreshing, isFalse);
      });
    });

    group('loadDetail()', () {
      test('成功后更新 selectedArticle', () async {
        const article = Article(id: 1, title: 't', body: 'b');
        when(() => mockRepo.getArticle(1))
            .thenAnswer((_) async => const Result.success(article));

        final result = await vm.loadDetail(1);

        expect(result.isSuccess, isTrue);
        expect(vm.selectedArticle.value.value?.title, 't');
        expect(vm.selectedArticle.value.isLoading, isFalse);
      });

      test('失败后返回 Failure', () async {
        when(() => mockRepo.getArticle(1)).thenAnswer(
          (_) async => const Result.failure(
            ServerFailure(code: FailureCode.serverError),
          ),
        );

        final result = await vm.loadDetail(1);

        expect(result.isFailure, isTrue);
        expect(vm.selectedArticle.value.hasError, isTrue);
        expect(vm.selectedArticle.value.value, isNull);
      });
    });

    group('clearSelected()', () {
      test('清除选中文章', () async {
        when(() => mockRepo.getArticle(1)).thenAnswer(
          (_) async =>
              const Result.success(Article(id: 1, title: 't', body: 'b')),
        );

        await vm.loadDetail(1);
        expect(vm.selectedArticle.value.value, isNotNull);

        vm.clearSelected();
        expect(vm.selectedArticle.value.value, isNull);
        expect(vm.selectedArticle.value.isLoading, isFalse);
      });
    });
  });
}
