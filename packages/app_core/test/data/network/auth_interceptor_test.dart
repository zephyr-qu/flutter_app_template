import 'dart:async';

import 'package:app_core/data/network/auth_extra_keys.dart';
import 'package:app_core/data/network/auth_interceptor.dart';
import 'package:app_core/models/token_set.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_token_refresher.dart';
import '../../support/fake_token_store.dart';
import '../../support/scripted_http_adapter.dart';

/// `AuthInterceptor` 的**纯包测试**：不引用 lib 侧任何东西（`AuthStorage` /
/// `SharedPreferences` / signals 都不在场），靠 [FakeTokenStore] 与
/// [FakeTokenRefresher] 驱动。
///
/// 刷新流程「真跑一遍」的那部分（真 `TokenRefresher` + 真 Dio 管道）
/// 在 `token_refresh_test.dart`。
void main() {
  late FakeTokenStore storage;
  late FakeTokenRefresher refresher;

  setUp(() {
    storage = FakeTokenStore();
    refresher = FakeTokenRefresher();
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
      await storage.saveTokens(const TokenSet(accessToken: 'access-123'));
      final adapter = ScriptedHttpAdapter();

      await createDio(adapter).get<dynamic>('/articles');

      expect(
        adapter.requests.single.headers['Authorization'],
        'Bearer access-123',
      );
    });

    test('没有访问令牌时不带 Authorization 头', () async {
      final adapter = ScriptedHttpAdapter();

      await createDio(adapter).get<dynamic>('/articles');

      expect(
        adapter.requests.single.headers.containsKey('Authorization'),
        isFalse,
      );
    });

    test('访问令牌为空字符串时不带 Authorization 头', () async {
      await storage.saveTokens(const TokenSet(accessToken: ''));
      final adapter = ScriptedHttpAdapter();

      await createDio(adapter).get<dynamic>('/articles');

      expect(
        adapter.requests.single.headers.containsKey('Authorization'),
        isFalse,
      );
    });

    test('刷新请求本身不带过期的访问令牌', () async {
      await storage.saveTokens(const TokenSet(accessToken: 'expired-token'));
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

    test('等待令牌从存储载入后才发出请求（冷启动首个请求不漏带）', () async {
      final gate = Completer<void>();
      storage.ready = gate.future;
      await storage.saveTokens(const TokenSet(accessToken: 'loaded'));
      final adapter = ScriptedHttpAdapter();

      final pending = createDio(adapter).get<dynamic>('/articles');
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // 载入还没完成 → 请求还没发出去（发了就会漏带令牌，白撞一次 401）
      expect(adapter.requests, isEmpty);

      gate.complete();
      await pending;

      expect(adapter.requests.single.headers['Authorization'], 'Bearer loaded');
    });

    test('令牌即将过期时先刷新，再用新令牌发请求', () async {
      await storage.saveTokens(
        TokenSet.withExpiresIn(
          accessToken: 'about-to-expire',
          refreshToken: 'refresh-1',
          expiresIn: 10, // 落在默认 30s skew 之内
        ),
      );
      refresher
        ..result = 'fresh'
        ..onRefresh = () =>
            storage.saveTokens(const TokenSet(accessToken: 'fresh'));
      final adapter = ScriptedHttpAdapter();

      await createDio(adapter).get<dynamic>('/articles');

      expect(refresher.refreshCount, 1);
      expect(adapter.requests.single.headers['Authorization'], 'Bearer fresh');
    });

    test('主动刷新失败不阻塞本次请求，带着旧令牌发出去交给 401 兜底', () async {
      await storage.saveTokens(
        TokenSet.withExpiresIn(
          accessToken: 'about-to-expire',
          refreshToken: 'refresh-1',
          expiresIn: 10,
        ),
      );
      refresher.result = null; // 刷新失败
      final adapter = ScriptedHttpAdapter();

      await createDio(adapter).get<dynamic>('/articles');

      expect(refresher.refreshCount, 1);
      expect(
        adapter.requests.single.headers['Authorization'],
        'Bearer about-to-expire',
      );
    });
  });

  group('AuthInterceptor — 何时尝试刷新', () {
    test('非 401 不刷新也不清凭证', () async {
      final adapter = ScriptedHttpAdapter()..on('/articles', [500]);

      await expectLater(
        createDio(adapter).get<dynamic>('/articles'),
        throwsA(isA<DioException>()),
      );

      expect(refresher.refreshCount, 0);
      expect(storage.clearAuthCount, 0);
    });

    test('401 且刷新返回 null 时清除凭证', () async {
      final adapter = ScriptedHttpAdapter()..on('/articles', [401]);
      refresher.result = null;

      await expectLater(
        createDio(adapter).get<dynamic>('/articles'),
        throwsA(isA<DioException>()),
      );

      expect(refresher.refreshCount, 1);
      expect(storage.clearAuthCount, 1);
    });

    // clearAuth 抛异常（安全存储不可用等）时，异常不能外抛到 onError：
    // dio 会把未完成 handler 的异常包成 DioException(type: unknown, response: null)
    // 传给调用方，原始的 401 就被替换成「未知错误」了
    test('clearAuth 抛异常时，调用方仍收到原始 401（不被替换成无关异常）', () async {
      storage = FakeTokenStore(clearAuthError: Exception('安全存储不可用'));
      final adapter = ScriptedHttpAdapter()..on('/articles', [401]);
      refresher.result = null;

      await expectLater(
        createDio(adapter).get<dynamic>('/articles'),
        throwsA(
          isA<DioException>()
              .having((e) => e.type, 'type', DioExceptionType.badResponse)
              .having((e) => e.response?.statusCode, 'statusCode', 401),
        ),
      );

      expect(storage.clearAuthCount, 1);
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

      expect(refresher.refreshCount, 0);
      expect(storage.clearAuthCount, 1);
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

      expect(refresher.refreshCount, 0);
      expect(storage.clearAuthCount, 1);
    });
  });
}
