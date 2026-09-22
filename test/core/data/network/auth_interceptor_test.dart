import 'package:app_core/data/network/auth_extra_keys.dart';
import 'package:app_core/data/network/auth_interceptor.dart';
import 'package:app_core/data/network/token_refresher.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:my_app/core/data/storage/auth_storage.dart';

import '../../../support/scripted_http_adapter.dart';

class MockAuthStorage extends Mock implements AuthStorage;

class MockTokenRefresher extends Mock implements TokenRefresher;

void main() {
  late MockAuthStorage storage;
  late MockTokenRefresher refresher;

  setUp(() {
    storage = MockAuthStorage();
    refresher = MockTokenRefresher();
    when(() => storage.ready).thenAnswer((_) async {});
    // 默认「不过期」：主动刷新那条分支由下面的专门用例覆盖
    when(() => storage.isAccessTokenExpiring()).thenReturn(false);
  });

  /// 构造一个带拦截器、并把网络层换成假适配器的 Dio
  Dio createDio(ScriptedHttpAdapter adapter) {
    final dio = Dio(BaseOptions(baseUrl: 'http://test.local'))
      ..httpClientAdapter = adapter;
    dio.interceptors.add(AuthInterceptor(storage, refresher, dio));
    return dio;
  }

  group('AuthInterceptor — 附加访问令牌', () {
    test('持有访问令牌时带上 Authorization: Bearer', () async {
      when(() => storage.getAccessToken()).thenReturn('access-123');
      final adapter = ScriptedHttpAdapter();

      await createDio(adapter).get<dynamic>('/articles');

      expect(
        adapter.requests.single.headers['Authorization'],
        'Bearer access-123',
      );
    });

    test('没有访问令牌时不带 Authorization 头', () async {
      when(() => storage.getAccessToken()).thenReturn(null);
      final adapter = ScriptedHttpAdapter();

      await createDio(adapter).get<dynamic>('/articles');

      expect(
        adapter.requests.single.headers.containsKey('Authorization'),
        isFalse,
      );
    });

    test('访问令牌为空字符串时不带 Authorization 头', () async {
      when(() => storage.getAccessToken()).thenReturn('');
      final adapter = ScriptedHttpAdapter();

      await createDio(adapter).get<dynamic>('/articles');

      expect(
        adapter.requests.single.headers.containsKey('Authorization'),
        isFalse,
      );
    });

    test('刷新请求本身不带过期的访问令牌', () async {
      when(() => storage.getAccessToken()).thenReturn('expired-token');
      final adapter = ScriptedHttpAdapter();

      await createDio(adapter).post<dynamic>(
        '/refresh',
        options: Options(extra: const {kSkipAuthRefresh: true}),
      );

      expect(
        adapter.requests.single.headers.containsKey('Authorization'),
        isFalse,
      );
    });

    test('令牌即将过期时先刷新，再用新令牌发请求', () async {
      var token = 'about-to-expire';
      when(() => storage.isAccessTokenExpiring()).thenReturn(true);
      when(() => storage.getAccessToken()).thenAnswer((_) => token);
      when(() => refresher.refresh()).thenAnswer((_) async {
        token = 'fresh';
        return 'fresh';
      });
      final adapter = ScriptedHttpAdapter();

      await createDio(adapter).get<dynamic>('/articles');

      verify(() => refresher.refresh()).called(1);
      expect(adapter.requests.single.headers['Authorization'], 'Bearer fresh');
    });
  });

  group('AuthInterceptor — 何时尝试刷新', () {
    test('非 401 不刷新也不清凭证', () async {
      final adapter = ScriptedHttpAdapter()..on('/articles', [500]);

      await expectLater(
        createDio(adapter).get<dynamic>('/articles'),
        throwsA(isA<DioException>()),
      );

      verifyNever(() => refresher.refresh());
      verifyNever(() => storage.clearAuth());
    });

    test('401 且刷新返回 null 时清除凭证', () async {
      final adapter = ScriptedHttpAdapter()..on('/articles', [401]);
      when(() => refresher.refresh()).thenAnswer((_) async => null);

      await expectLater(
        createDio(adapter).get<dynamic>('/articles'),
        throwsA(isA<DioException>()),
      );

      verify(() => refresher.refresh()).called(1);
      verify(() => storage.clearAuth()).called(1);
    });

    // clearAuth 抛异常（安全存储不可用等）时，异常不能外抛到 onError：
    // dio 会把未完成 handler 的异常包成 DioException(type: unknown, response: null)
    // 传给调用方，原始的 401 就被替换成「未知错误」了
    test('clearAuth 抛异常时，调用方仍收到原始 401（不被替换成无关异常）', () async {
      final adapter = ScriptedHttpAdapter()..on('/articles', [401]);
      when(() => refresher.refresh()).thenAnswer((_) async => null);
      when(() => storage.clearAuth()).thenThrow(StateError('安全存储不可用'));

      await expectLater(
        createDio(adapter).get<dynamic>('/articles'),
        throwsA(
          isA<DioException>()
              .having((e) => e.type, 'type', DioExceptionType.badResponse)
              .having((e) => e.response?.statusCode, 'statusCode', 401),
        ),
      );

      verify(() => storage.clearAuth()).called(1);
    });

    test('已重放过的请求（kAuthRetried）不再刷新，直接清凭证', () async {
      final adapter = ScriptedHttpAdapter()..on('/articles', [401]);

      await expectLater(
        createDio(adapter).get<dynamic>(
          '/articles',
          options: Options(extra: const {kAuthRetried: true}),
        ),
        throwsA(isA<DioException>()),
      );

      verifyNever(() => refresher.refresh());
      verify(() => storage.clearAuth()).called(1);
    });

    test('刷新请求自身 401（kSkipAuthRefresh）不再刷新，直接清凭证', () async {
      final adapter = ScriptedHttpAdapter()..on('/refresh', [401]);

      await expectLater(
        createDio(adapter).post<dynamic>(
          '/refresh',
          options: Options(extra: const {kSkipAuthRefresh: true}),
        ),
        throwsA(isA<DioException>()),
      );

      verifyNever(() => refresher.refresh());
      verify(() => storage.clearAuth()).called(1);
    });
  });
}
