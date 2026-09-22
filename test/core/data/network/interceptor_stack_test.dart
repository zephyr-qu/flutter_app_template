import 'package:app_core/config/network_config.dart';
import 'package:app_core/models/token_set.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/config/user_preferences.dart';
import 'package:my_app/core/data/network/dio_client.dart';
import 'package:my_app/core/data/storage/auth_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/scripted_http_adapter.dart';

/// 复刻生产的拦截器装配，好在测试里拿到**与线上完全一致**的栈（Auth + 解码 + Retry）。
///
/// 与 `token_refresh_test.dart` 的分工见 backend/network-guidelines.md「拦截器顺序」。
class _TestNetworkModule extends NetworkModule;

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

    // 关掉调试日志，否则 PrettyDioLogger 会把每个响应打到测试输出里
    final preferences = UserPreferences(prefs)..setDebugLogging(enabled: false);

    dio = _TestNetworkModule().dio(
      preferences,
      storage,
      const NetworkConfig(baseUrl: 'http://test.local'),
    );
    adapter = ScriptedHttpAdapter();
    dio.httpClientAdapter = adapter;
  });

  test('重试拦截器不会吞掉 401：仍然刷新令牌并重放', () async {
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

    expect(response.statusCode, 200);
    expect(response.data, {'ok': true});

    // 原始一次 + 重放一次。若 RetryInterceptor 把 401 也拿去重试，
    // 第二次就会直接消费脚本里的 200，refresh 次数会变成 0 —— 这条断言
    // 正是在守住「401 只归 AuthInterceptor 管」。
    expect(adapter.requestCount('/articles'), 2);
    expect(adapter.requestCount('/refresh'), 1);
    expect(storage.getAccessToken(), 'fresh');
  });

  test('5xx 交给重试拦截器，且不触碰刷新流程', () async {
    await storage.saveTokens(
      const TokenSet(accessToken: 'valid', refreshToken: 'refresh-1'),
    );
    adapter.on('/articles', [
      503,
      {'ok': true},
    ]);

    final response = await dio.get<Map<String, dynamic>>('/articles');

    expect(response.statusCode, 200);
    // 第一次 503、重试后 200
    expect(adapter.requestCount('/articles'), 2);
    expect(adapter.requestCount('/refresh'), 0);
    expect(storage.getAccessToken(), 'valid');
  });
}
