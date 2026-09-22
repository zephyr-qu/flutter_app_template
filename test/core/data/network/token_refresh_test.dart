import 'dart:async';

import 'package:app_core/data/network/auth_interceptor.dart';
import 'package:app_core/data/network/token_refresher.dart';
import 'package:app_core/models/token_set.dart';
import 'package:app_core/models/user.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/data/storage/auth_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/scripted_http_adapter.dart';

/// 这里用**真实的** AuthStorage + TokenRefresher + AuthInterceptor 跑在真实的
/// Dio 管道里，只有网络层被替换成脚本化适配器。刷新流程的坑几乎都在并发与
/// 递归上，只有把这几层真正拼起来才验得出来。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AuthStorage storage;
  late ScriptedHttpAdapter adapter;
  late Dio dio;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    storage = AuthStorage(prefs, const FlutterSecureStorage());
    await storage.ready;

    adapter = ScriptedHttpAdapter();
    dio = Dio(BaseOptions(baseUrl: 'http://test.local'))
      ..httpClientAdapter = adapter;
    dio.interceptors.add(
      AuthInterceptor(storage, TokenRefresher(storage, dio), dio),
    );
  });

  test('401 后刷新令牌并重放原请求，调用方拿到成功结果', () async {
    await storage.saveTokens(
      const TokenSet(accessToken: 'expired', refreshToken: 'refresh-1'),
    );
    adapter
      ..on('/articles', [
        401,
        {'ok': true},
      ])
      ..on('/refresh', [
        {'accessToken': 'fresh', 'refreshToken': 'refresh-2'},
      ]);

    final response = await dio.get<Map<String, dynamic>>('/articles');

    // 调用方看到的是成功，而不是 401
    expect(response.statusCode, 200);
    expect(response.data, {'ok': true});

    // 刷新请求只发了一次，且不带过期的访问令牌，body 里是刷新令牌
    expect(adapter.requestCount('/refresh'), 1);
    final refreshRequest = adapter.requests.firstWhere(
      (r) => r.path.endsWith('/refresh'),
    );
    expect(refreshRequest.headers.containsKey('Authorization'), isFalse);
    expect(refreshRequest.data, {'refreshToken': 'refresh-1'});

    // 重放用的是新令牌，本地令牌也已更新（含轮换后的刷新令牌）
    expect(adapter.requests.last.headers['Authorization'], 'Bearer fresh');
    expect(storage.getAccessToken(), 'fresh');
    expect(storage.getRefreshToken(), 'refresh-2');
  });

  test('并发 401 只触发一次刷新（single-flight）', () async {
    await storage.saveTokens(
      const TokenSet(accessToken: 'expired', refreshToken: 'refresh-1'),
    );
    // 两次原始请求都拿到 401，之后的重放拿到 200
    adapter
      ..on('/articles', [
        401,
        401,
        {'ok': true},
      ])
      ..on('/refresh', [
        {'accessToken': 'fresh', 'refreshToken': 'refresh-2'},
      ]);

    // 把刷新请求卡住，确保两个 401 都会落在同一次刷新上
    final gate = Completer<void>();
    adapter.beforeRespond = (options) async {
      if (options.path.endsWith('/refresh')) await gate.future;
    };

    final futures = [
      dio.get<dynamic>('/articles'),
      dio.get<dynamic>('/articles'),
    ];
    await Future<void>.delayed(const Duration(milliseconds: 20));
    gate.complete();
    await Future.wait(futures);

    // 若没有 single-flight，这里会是 2 —— 而服务端一旦轮换刷新令牌，
    // 第二次刷新就会用已被换掉的令牌，用户被误登出
    expect(adapter.requestCount('/refresh'), 1);
    expect(adapter.requestCount('/articles'), 4);
  });

  test('刷新接口本身失败时清除凭证，并抛出原始 401', () async {
    await storage.saveTokens(
      const TokenSet(accessToken: 'expired', refreshToken: 'refresh-1'),
    );
    await storage.saveUser(const User(id: 1, name: '测试用户'));
    adapter
      ..on('/articles', [401])
      ..on('/refresh', [401]);

    await expectLater(
      dio.get<dynamic>('/articles'),
      throwsA(
        isA<DioException>().having(
          (e) => e.response?.statusCode,
          'statusCode',
          401,
        ),
      ),
    );

    expect(storage.getAccessToken(), isNull);
    expect(storage.getRefreshToken(), isNull);
    expect(storage.isLoggedIn, isFalse);
    // 刷新失败后不该继续重放
    expect(adapter.requestCount('/articles'), 1);
  });

  test('没有刷新令牌时不调用刷新接口，直接清凭证', () async {
    await storage.saveTokens(const TokenSet(accessToken: 'expired'));
    adapter.on('/articles', [401]);

    await expectLater(
      dio.get<dynamic>('/articles'),
      throwsA(isA<DioException>()),
    );

    expect(adapter.requestCount('/refresh'), 0);
    expect(storage.getAccessToken(), isNull);
  });

  test('重放后仍然 401 不会再刷新（不会无限循环）', () async {
    await storage.saveTokens(
      const TokenSet(accessToken: 'expired', refreshToken: 'refresh-1'),
    );
    adapter
      ..on('/articles', [401])
      ..on('/refresh', [
        {'accessToken': 'still-rejected'},
      ]);

    await expectLater(
      dio.get<dynamic>('/articles'),
      throwsA(isA<DioException>()),
    );

    // 原始请求 + 一次重放
    expect(adapter.requestCount('/articles'), 2);
    expect(adapter.requestCount('/refresh'), 1);
    expect(storage.getAccessToken(), isNull);
  });

  group('主动刷新（expiresIn）', () {
    test('令牌临近过期时先刷新再发请求，不出现 401', () async {
      await storage.saveTokens(
        TokenSet.withExpiresIn(
          accessToken: 'about-to-expire',
          refreshToken: 'refresh-1',
          expiresIn: 10, // 落在默认 30s skew 之内
        ),
      );
      adapter
        ..on('/articles', [
          {'ok': true},
        ])
        ..on('/refresh', [
          {
            'accessToken': 'fresh',
            'refreshToken': 'refresh-2',
            'expiresIn': 3600,
          },
        ]);

      final response = await dio.get<Map<String, dynamic>>('/articles');

      expect(response.statusCode, 200);
      // /articles 只请求了一次 —— 说明是刷新在前，
      // 而不是先带着过期令牌撞一次 401 再重放
      expect(adapter.requestCount('/articles'), 1);
      expect(adapter.requestCount('/refresh'), 1);
      expect(adapter.requests.last.headers['Authorization'], 'Bearer fresh');
      expect(storage.getRefreshToken(), 'refresh-2');
      expect(storage.isAccessTokenExpiring(), isFalse);
    });

    test('令牌仍有效时不主动刷新', () async {
      await storage.saveTokens(
        TokenSet.withExpiresIn(
          accessToken: 'valid',
          refreshToken: 'refresh-1',
          expiresIn: 3600,
        ),
      );
      adapter.on('/articles', [
        {'ok': true},
      ]);

      await dio.get<dynamic>('/articles');

      expect(adapter.requestCount('/refresh'), 0);
      expect(adapter.requests.single.headers['Authorization'], 'Bearer valid');
    });

    test('服务端未提供 expiresIn 时退化为被动刷新', () async {
      await storage.saveTokens(
        const TokenSet(accessToken: 'valid', refreshToken: 'refresh-1'),
      );
      adapter.on('/articles', [
        {'ok': true},
      ]);

      await dio.get<dynamic>('/articles');

      expect(adapter.requestCount('/refresh'), 0);
    });

    test('主动刷新失败不阻塞请求，最终由 401 路径兜底并登出', () async {
      await storage.saveTokens(
        TokenSet.withExpiresIn(
          accessToken: 'about-to-expire',
          refreshToken: 'refresh-1',
          expiresIn: 10,
        ),
      );
      await storage.saveUser(const User(id: 1, name: '测试用户'));
      adapter
        ..on('/refresh', [500]) // 主动刷新失败
        ..on('/articles', [401]); // 过期令牌被拒

      await expectLater(
        dio.get<dynamic>('/articles'),
        throwsA(isA<DioException>()),
      );

      // 主动一次 + 401 之后被动一次，两次都失败 → 登出
      expect(adapter.requestCount('/refresh'), 2);
      expect(adapter.requestCount('/articles'), 1);
      expect(storage.isLoggedIn, isFalse);
    });
  });
}
