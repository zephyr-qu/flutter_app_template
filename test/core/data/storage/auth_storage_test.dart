import 'dart:convert';

import 'package:app_core/models/token_set.dart';
import 'package:app_core/models/user.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/data/storage/auth_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late FlutterSecureStorage secure;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    secure = const FlutterSecureStorage();
  });

  /// 新建一个实例，等价于「App 重启后重新构造」
  AuthStorage createStorage() => AuthStorage(prefs, secure);

  group('AuthStorage — 令牌存放在安全存储', () {
    test('saveTokens 后立即可同步读取，且已持久化到安全存储', () async {
      final storage = createStorage();
      await storage.ready;

      await storage.saveTokens(
        const TokenSet(accessToken: 'access-123', refreshToken: 'refresh-123'),
      );

      expect(storage.getAccessToken(), 'access-123');
      expect(storage.getRefreshToken(), 'refresh-123');

      // 新实例（模拟重启）仍能读回 —— 说明确实写进了安全存储
      final restarted = createStorage();
      await restarted.ready;
      expect(restarted.getAccessToken(), 'access-123');
      expect(restarted.getRefreshToken(), 'refresh-123');
    });

    test('令牌整条只占安全存储里的一个键', () async {
      final storage = createStorage();
      await storage.ready;

      await storage.saveTokens(
        const TokenSet(accessToken: 'access-123', refreshToken: 'refresh-123'),
      );

      final persisted = await secure.readAll();
      expect(persisted.keys, ['auth.tokens']);

      // 访问令牌与刷新令牌在同一个 JSON 里，不再各占一个键
      final decoded =
          jsonDecode(persisted['auth.tokens']!) as Map<String, dynamic>;
      expect(decoded['accessToken'], 'access-123');
      expect(decoded['refreshToken'], 'refresh-123');
    });

    test('令牌不会以明文落在 SharedPreferences 里', () async {
      final storage = createStorage();
      await storage.ready;

      await storage.saveTokens(
        const TokenSet(accessToken: 'access-123', refreshToken: 'refresh-123'),
      );

      expect(prefs.getKeys(), isEmpty);
    });

    test('构造时把安全存储里的令牌载入内存', () async {
      FlutterSecureStorage.setMockInitialValues({
        'auth.tokens': jsonEncode({
          'accessToken': 'persisted-access',
          'refreshToken': 'persisted-refresh',
        }),
      });

      final storage = createStorage();
      await storage.ready;

      expect(storage.getAccessToken(), 'persisted-access');
      expect(storage.getRefreshToken(), 'persisted-refresh');
    });

    test('安全存储里的令牌 JSON 损坏时降级为未持有令牌', () async {
      FlutterSecureStorage.setMockInitialValues({'auth.tokens': 'not-json'});

      final storage = createStorage();
      await storage.ready;

      expect(storage.getAccessToken(), isNull);
      expect(storage.getRefreshToken(), isNull);
    });
  });

  group('AuthStorage — 令牌生命周期', () {
    test('refreshToken 为空时保留原刷新令牌（服务端不轮换的情况）', () async {
      final storage = createStorage();
      await storage.ready;
      await storage.saveTokens(
        const TokenSet(accessToken: 'access-1', refreshToken: 'refresh-1'),
      );

      // 刷新接口只返回了新的访问令牌
      await storage.saveTokens(const TokenSet(accessToken: 'access-2'));

      expect(storage.getAccessToken(), 'access-2');
      expect(storage.getRefreshToken(), 'refresh-1');

      // 保留的是落盘后的值，重启依然拿得回来
      final restarted = createStorage();
      await restarted.ready;
      expect(restarted.getRefreshToken(), 'refresh-1');
    });

    test('saveTokens 传入新的 refreshToken 时轮换', () async {
      final storage = createStorage();
      await storage.ready;
      await storage.saveTokens(
        const TokenSet(accessToken: 'access-1', refreshToken: 'refresh-1'),
      );

      await storage.saveTokens(
        const TokenSet(accessToken: 'access-2', refreshToken: 'refresh-2'),
      );

      expect(storage.getRefreshToken(), 'refresh-2');
    });

    test('clearAuth 同时清掉用户与令牌', () async {
      final storage = createStorage();
      await storage.ready;
      await storage.saveTokens(
        TokenSet.withExpiresIn(
          accessToken: 'access-123',
          refreshToken: 'refresh-123',
          expiresIn: 0, // 已过期，用来验证 clearAuth 会把过期时刻一并清掉
        ),
      );
      await storage.saveUser(const User(id: 1, name: '测试用户'));
      expect(storage.isLoggedIn, isTrue);
      expect(storage.isAccessTokenExpiring(), isTrue);

      await storage.clearAuth();

      expect(storage.getAccessToken(), isNull);
      expect(storage.getRefreshToken(), isNull);
      expect(storage.isAccessTokenExpiring(), isFalse);
      expect(storage.currentUser, isNull);
      expect(storage.isLoggedIn, isFalse);
      expect(prefs.getString('auth.user'), isNull);
      expect(await secure.read(key: 'auth.tokens'), isNull);

      final restarted = createStorage();
      await restarted.ready;
      expect(restarted.getAccessToken(), isNull);
      expect(restarted.getRefreshToken(), isNull);
    });
  });

  group('AuthStorage — 访问令牌过期时刻', () {
    test('未提供 expiresIn 时不做主动刷新判断', () async {
      final storage = createStorage();
      await storage.ready;

      await storage.saveTokens(
        const TokenSet(accessToken: 'a', refreshToken: 'r'),
      );

      expect(storage.isAccessTokenExpiring(), isFalse);
    });

    test('expiresIn 还很长时不算即将过期', () async {
      final storage = createStorage();
      await storage.ready;

      await storage.saveTokens(
        TokenSet.withExpiresIn(
          accessToken: 'a',
          refreshToken: 'r',
          expiresIn: 3600,
        ),
      );

      expect(storage.isAccessTokenExpiring(), isFalse);
    });

    test('expiresIn 落在 skew 之内算即将过期', () async {
      final storage = createStorage();
      await storage.ready;

      // 默认 skew 是 30 秒
      await storage.saveTokens(
        TokenSet.withExpiresIn(
          accessToken: 'a',
          refreshToken: 'r',
          expiresIn: 10,
        ),
      );

      expect(storage.isAccessTokenExpiring(), isTrue);
    });

    test('已经过期也算即将过期', () async {
      final storage = createStorage();
      await storage.ready;

      await storage.saveTokens(
        TokenSet.withExpiresIn(
          accessToken: 'a',
          refreshToken: 'r',
          expiresIn: 0,
        ),
      );

      expect(storage.isAccessTokenExpiring(), isTrue);
    });

    test('过期时刻会持久化，重启后仍然生效', () async {
      final storage = createStorage();
      await storage.ready;
      await storage.saveTokens(
        TokenSet.withExpiresIn(
          accessToken: 'a',
          refreshToken: 'r',
          expiresIn: 10,
        ),
      );

      final restarted = createStorage();
      await restarted.ready;

      expect(restarted.isAccessTokenExpiring(), isTrue);
    });
  });

  group('AuthStorage — 用户信息仍走 SharedPreferences', () {
    test('saveUser 写入 prefs 并更新内存真源', () async {
      final storage = createStorage();
      await storage.ready;

      await storage.saveUser(const User(id: 7, name: '张三'));

      expect(storage.currentUser?.name, '张三');
      expect(storage.currentUserId, 7);
      expect(prefs.getString('auth.user'), isNotNull);

      final restarted = createStorage();
      expect(restarted.currentUser?.name, '张三');
    });

    test('本地用户数据损坏时清理，不抛异常', () async {
      SharedPreferences.setMockInitialValues({'auth.user': 'not-json'});

      final storage = createStorage();
      await storage.ready;

      expect(storage.currentUser, isNull);
      expect(prefs.getString('auth.user'), isNull);
    });
  });

  group('AuthStorage — userChanges 流', () {
    test('订阅时立刻收到当前值，之后随登录态推送', () async {
      final storage = createStorage();
      await storage.ready;

      final seen = <User?>[];
      final subscription = storage.userChanges.listen(seen.add);
      addTearDown(subscription.cancel);

      // 对齐 signals 的「读即有值」：消费者不必先读 currentUser 再订阅
      await pumpEventQueue();
      expect(seen, [null]);

      await storage.saveUser(const User(id: 7, name: '张三'));
      await pumpEventQueue();
      expect(seen.last?.name, '张三');
      expect(storage.isLoggedIn, isTrue);

      await storage.clearAuth();
      await pumpEventQueue();
      expect(seen.last, isNull);
      expect(storage.isLoggedIn, isFalse);
    });
  });
}
