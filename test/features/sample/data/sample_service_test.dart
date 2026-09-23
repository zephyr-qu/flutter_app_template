import 'package:app_core/base/failure.dart';
import 'package:app_core/data/database/app_database.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:my_app/features/sample/data/models/sample_item.dart';
import 'package:my_app/features/sample/data/sample_api.dart';
import 'package:my_app/features/sample/data/sample_dao.dart';
import 'package:my_app/features/sample/data/sample_service.dart';

class MockSampleApi extends Mock implements SampleApi;

class MockSampleDao extends Mock implements SampleDao;

/// 连不上对端的失败（`runCatching` 会把它翻译成 `NetworkFailure.connection`）。
DioException connectionError() => DioException(
  requestOptions: RequestOptions(path: '/sample-items'),
  type: DioExceptionType.connectionError,
);

void main() {
  const item = SampleItem(id: 1, title: '示例条目一', body: '正文');
  const cachedRow = DbArticle(id: 1, title: '缓存标题', body: '缓存正文');

  late MockSampleApi api;
  late MockSampleDao cache;
  late SampleService service;

  setUpAll(() {
    registerFallbackValue(<DbArticle>[]);
    registerFallbackValue(const DbArticle(id: 0, title: '', body: ''));
  });

  setUp(() {
    api = MockSampleApi();
    cache = MockSampleDao();
    service = SampleService(api, cache);

    when(() => cache.cacheItems(any())).thenAnswer((_) async {});
    when(() => cache.cacheItem(any())).thenAnswer((_) async {});
    when(cache.getCachedItems).thenAnswer((_) async => const <DbArticle>[]);
    when(() => cache.getCachedItem(any())).thenAnswer((_) async => null);
  });

  group('SampleService.getItems', () {
    test('网络成功：写入缓存并返回数据', () async {
      when(api.getItems).thenAnswer((_) async => [item]);

      final result = await service.getItems();

      expect(result.isSuccess, isTrue);
      expect(
        result.when(success: (items) => items.single, failure: (_) => null),
        item,
      );

      final written =
          verify(() => cache.cacheItems(captureAny())).captured.single
              as List<DbArticle>;
      expect(written.single.id, 1);
      expect(written.single.title, '示例条目一');
    });

    test('网络失败但有缓存：回退到缓存（cache-aside）', () async {
      when(api.getItems).thenThrow(connectionError());
      when(cache.getCachedItems).thenAnswer((_) async => const [cachedRow]);

      final result = await service.getItems();

      expect(result.isSuccess, isTrue);
      expect(
        result.when(success: (items) => items.single.title, failure: (_) => ''),
        '缓存标题',
      );
      // 网络失败时不该反过来把缓存清掉
      verifyNever(() => cache.cacheItems(any()));
    });

    test('网络失败且缓存为空：把原始错误原样返回', () async {
      when(api.getItems).thenThrow(connectionError());

      final result = await service.getItems();

      expect(result.isFailure, isTrue);
      expect(
        result.when(success: (_) => '', failure: (failure) => failure.code),
        FailureCode.connection,
      );
    });

    test('读缓存本身抛异常：按未命中处理，仍返回网络错误', () async {
      when(api.getItems).thenThrow(connectionError());
      when(cache.getCachedItems).thenThrow(Exception('db unavailable'));

      final result = await service.getItems();

      expect(result.isFailure, isTrue);
      expect(
        result.when(success: (_) => '', failure: (failure) => failure.code),
        FailureCode.connection,
      );
    });

    test('写缓存失败不影响请求结果', () async {
      when(api.getItems).thenAnswer((_) async => [item]);
      when(() => cache.cacheItems(any()))
          .thenThrow(Exception('db unavailable'));

      final result = await service.getItems();

      expect(result.isSuccess, isTrue);
    });
  });

  group('SampleService.getItem', () {
    test('网络成功：upsert 单条，不动列表缓存', () async {
      when(() => api.getItem(1)).thenAnswer((_) async => item);

      final result = await service.getItem(1);

      expect(result.isSuccess, isTrue);
      verify(() => cache.cacheItem(any())).called(1);
      verifyNever(() => cache.cacheItems(any()));
    });

    test('网络失败但该条有缓存：回退到缓存', () async {
      when(() => api.getItem(1)).thenThrow(connectionError());
      when(() => cache.getCachedItem(1)).thenAnswer((_) async => cachedRow);

      final result = await service.getItem(1);

      expect(result.isSuccess, isTrue);
      expect(
        result.when(success: (value) => value.title, failure: (_) => ''),
        '缓存标题',
      );
    });

    test('网络失败且缓存未命中：返回失败', () async {
      when(() => api.getItem(1)).thenThrow(connectionError());

      final result = await service.getItem(1);

      expect(result.isFailure, isTrue);
      expect(
        result.when(success: (_) => '', failure: (failure) => failure.code),
        FailureCode.connection,
      );
    });

    test('读单条缓存抛异常：按未命中处理', () async {
      when(() => api.getItem(1)).thenThrow(connectionError());
      when(() => cache.getCachedItem(1)).thenThrow(Exception('db unavailable'));

      final result = await service.getItem(1);

      expect(result.isFailure, isTrue);
    });
  });
}
