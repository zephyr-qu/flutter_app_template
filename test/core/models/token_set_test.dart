import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/models/token_set.dart';

void main() {
  group('TokenSet.fromApi', () {
    test('expiresIn（秒）当场换算成绝对过期时刻', () {
      final before = DateTime.now();
      final tokens = TokenSet.fromApi({
        'accessToken': 'access-1',
        'refreshToken': 'refresh-1',
        'expiresIn': 3600,
      });

      expect(tokens.accessToken, 'access-1');
      expect(tokens.refreshToken, 'refresh-1');
      expect(tokens.expiresAt, isNotNull);
      // 允许几毫秒的钟表抖动
      expect(tokens.expiresAt!.difference(before).inSeconds, closeTo(3600, 5));
    });

    test('服务端未给 expiresIn 时 expiresAt 为 null（只能等 401 兜底）', () {
      final tokens = TokenSet.fromApi({'accessToken': 'access-1'});

      expect(tokens.expiresAt, isNull);
    });

    test('刷新令牌可以是 null（服务端只在轮换时返回）', () {
      final tokens = TokenSet.fromApi({
        'accessToken': 'access-1',
        'expiresIn': 10,
      });

      expect(tokens.refreshToken, isNull);
    });
  });

  group('toJson / fromJson（落盘形状）', () {
    test('JSON 里放的是绝对毫秒时刻，不是 expiresIn', () {
      final expiresAt = DateTime.fromMillisecondsSinceEpoch(1_700_000_000_000);
      final tokens = TokenSet(
        accessToken: 'access-1',
        refreshToken: 'refresh-1',
        expiresAt: expiresAt,
      );

      expect(tokens.toJson(), {
        'accessToken': 'access-1',
        'refreshToken': 'refresh-1',
        'expiresAt': 1_700_000_000_000,
      });
    });

    test('null 字段不进 JSON（不是写成 null 值）', () {
      const tokens = TokenSet(accessToken: 'access-1');

      expect(tokens.toJson(), {'accessToken': 'access-1'});
    });

    test('往返后字段不变，过期时刻精确到毫秒（落盘精度）', () {
      final original = TokenSet.withExpiresIn(
        accessToken: 'access-1',
        refreshToken: 'refresh-1',
        expiresIn: 3600,
      );

      final restored = TokenSet.fromJson(original.toJson());

      expect(restored.accessToken, original.accessToken);
      expect(restored.refreshToken, original.refreshToken);
      // 落盘存的是毫秒时间戳，微秒部分会被截断——比较到毫秒即可
      expect(
        restored.expiresAt!.millisecondsSinceEpoch,
        original.expiresAt!.millisecondsSinceEpoch,
      );
    });

    test('缺失 / 类型不对的 expiresAt 一律按「无过期时刻」处理', () {
      expect(TokenSet.fromJson({'accessToken': 'a'}).expiresAt, isNull);
      expect(
        TokenSet.fromJson({'accessToken': 'a', 'expiresAt': 'oops'}).expiresAt,
        isNull,
      );
    });
  });

  group('withExpiresIn', () {
    test('expiresIn 为 0 时过期时刻就是现在（已过期）', () {
      final tokens = TokenSet.withExpiresIn(accessToken: 'a', expiresIn: 0);

      expect(
        tokens.expiresAt!.isBefore(
          DateTime.now().add(const Duration(seconds: 1)),
        ),
        isTrue,
      );
    });

    test('expiresIn 为 null 时不设过期时刻', () {
      expect(TokenSet.withExpiresIn(accessToken: 'a').expiresAt, isNull);
    });
  });
}
