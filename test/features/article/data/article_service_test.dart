import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:my_app/core/base/failure.dart';
import 'package:my_app/core/data/database/app_database.dart';
import 'package:my_app/features/article/data/article_api.dart';
import 'package:my_app/features/article/data/article_dao.dart';
import 'package:my_app/features/article/data/article_service.dart';
import 'package:my_app/features/article/data/models/article.dart';

class MockArticleApi extends Mock implements ArticleApi;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockArticleApi api;
  late AppDatabase db;
  late ArticleDao cache;
  late ArticleService service;

  const article = Article(id: 1, title: '标题', body: '内容');

  setUp(() async {
    // 用真实的内存数据库：缓存旁路与「行对象 ↔ 业务模型」的映射
    // 只有真跑一遍才验得到（字段写反这类问题编译期看不出来）
    db = AppDatabase.connect(NativeDatabase.memory());
    addTearDown(db.close);
    // 等待表创建完成
    await db.customSelect('SELECT 1').get();
    cache = ArticleDao(db);

    api = MockArticleApi();
    service = ArticleService(api, cache);
  });

  DioException dioError(int statusCode) {
    final requestOptions = RequestOptions(path: '/articles');
    return DioException(
      requestOptions: requestOptions,
      type: DioExceptionType.badResponse,
      response: Response<void>(
        requestOptions: requestOptions,
        statusCode: statusCode,
      ),
    );
  }

  DioException offline() => DioException(
    requestOptions: RequestOptions(path: '/articles'),
    type: DioExceptionType.connectionError,
  );

  group('ArticleService.getArticles — 网络', () {
    test('成功后返回列表', () async {
      when(() => api.getArticles()).thenAnswer((_) async => [article]);

      final result = await service.getArticles();

      expect(result.isSuccess, isTrue);
      expect(
        result.when(success: (list) => list.single.title, failure: (_) => null),
        '标题',
      );
    });

    test('404 映射为 notFound', () async {
      when(() => api.getArticles()).thenThrow(dioError(404));

      final result = await service.getArticles();

      expect(result.isFailure, isTrue);
      expect(
        result.when(success: (_) => null, failure: (f) => f.code),
        FailureCode.notFound,
      );
    });

    test('401 映射为认证失败', () async {
      when(() => api.getArticles()).thenThrow(dioError(401));

      final result = await service.getArticles();

      expect(
        result.when(success: (_) => null, failure: (f) => f),
        isA<AuthFailure>(),
      );
    });

    test('超时映射为网络失败', () async {
      when(() => api.getArticles()).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/articles'),
          type: DioExceptionType.receiveTimeout,
        ),
      );

      final result = await service.getArticles();

      expect(
        result.when(success: (_) => null, failure: (f) => f),
        isA<NetworkFailure>(),
      );
    });

    test('非 Dio 异常转为 unknown，不携带异常文本', () async {
      when(() => api.getArticles())
          .thenThrow(StateError('内部字段 accessToken=secret'));

      final result = await service.getArticles();

      expect(
        result.when(success: (_) => null, failure: (f) => f.code),
        FailureCode.unknown,
      );
    });
  });

  group('ArticleService.getArticles — 缓存旁路', () {
    test('网络成功时顺手写入缓存', () async {
      when(() => api.getArticles()).thenAnswer((_) async => [article]);

      await service.getArticles();

      final cached = await cache.getCachedArticles();
      expect(cached, hasLength(1));
      expect(cached.single.id, 1);
      expect(cached.single.title, '标题');
      expect(cached.single.body, '内容');
    });

    test('网络失败但有缓存时，返回缓存内容而不是失败', () async {
      when(() => api.getArticles()).thenAnswer((_) async => [article]);
      await service.getArticles(); // 先填充缓存

      when(() => api.getArticles()).thenThrow(offline());
      final result = await service.getArticles();

      expect(result.isSuccess, isTrue);
      expect(
        result.when(success: (list) => list.single.title, failure: (_) => null),
        '标题',
      );
    });

    test('网络失败且无缓存时，返回原始 Failure（保留错误码）', () async {
      when(() => api.getArticles()).thenThrow(offline());

      final result = await service.getArticles();

      expect(result.isFailure, isTrue);
      expect(
        result.when(success: (_) => null, failure: (f) => f.code),
        FailureCode.connection,
      );
    });
  });

  group('ArticleService.getArticle', () {
    test('成功后返回单篇文章', () async {
      when(() => api.getArticle(any())).thenAnswer((_) async => article);

      final result = await service.getArticle(1);

      expect(result.isSuccess, isTrue);
      verify(() => api.getArticle(1)).called(1);
    });

    test('把 id 原样透传给 API', () async {
      when(() => api.getArticle(any())).thenAnswer((_) async => article);

      await service.getArticle(42);

      verify(() => api.getArticle(42)).called(1);
    });

    test('404 映射为 notFound', () async {
      when(() => api.getArticle(any())).thenThrow(dioError(404));

      final result = await service.getArticle(999);

      expect(
        result.when(success: (_) => null, failure: (f) => f.code),
        FailureCode.notFound,
      );
    });

    test('网络失败但有该篇缓存时，返回缓存内容', () async {
      when(() => api.getArticle(any())).thenAnswer((_) async => article);
      await service.getArticle(1); // 填充缓存

      when(() => api.getArticle(any())).thenThrow(offline());
      final result = await service.getArticle(1);

      expect(result.isSuccess, isTrue);
      expect(result.when(success: (a) => a.body, failure: (_) => null), '内容');
    });

    test('网络失败且缓存里没有这一篇时，返回失败', () async {
      when(() => api.getArticle(any())).thenThrow(offline());

      final result = await service.getArticle(7);

      expect(result.isFailure, isTrue);
      expect(
        result.when(success: (_) => null, failure: (f) => f.code),
        FailureCode.connection,
      );
    });

    test('写单篇不会清掉列表缓存', () async {
      when(() => api.getArticles()).thenAnswer(
        (_) async => [
          const Article(id: 1, title: '一', body: 'a'),
          const Article(id: 2, title: '二', body: 'b'),
        ],
      );
      await service.getArticles();

      when(() => api.getArticle(any()))
          .thenAnswer((_) async => const Article(id: 3, title: '三', body: 'c'));
      await service.getArticle(3);

      final cached = await cache.getCachedArticles();
      expect(cached.map((a) => a.id), containsAll(<int>[1, 2, 3]));
    });
  });
}
