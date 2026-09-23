import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/logging/log_redactor.dart';

/// 每个用例都用**新实例**：`LogRedactor` 跨行带状态（长值折行），
/// 复用一个实例会让上一条日志的状态污染下一条。
List<String> _redactAll(List<String> lines) {
  final redactor = LogRedactor();
  return lines.map(redactor.redact).toList();
}

void main() {
  // 形状照抄 PrettyDioLogger 的实际输出（`│` + 缩进 + `"key": value`）——
  // 脱离真实格式写的用例守不住折行那条规则。
  group('单行命中', () {
    test('屏蔽请求体里的密码与响应里的令牌', () {
      final redactor = LogRedactor();

      expect(
        redactor.redact('│ │     "password": "hunter2",'),
        '│ │     "password": ***',
      );
      expect(
        redactor.redact('│ │     "accessToken": "mock-access-token",'),
        '│ │     "accessToken": ***',
      );
      expect(
        redactor.redact('│ │     "refreshToken": "mock-refresh-token",'),
        '│ │     "refreshToken": ***',
      );
    });

    test('字段名大小写不敏感，header 的 `key: value` 形状同样命中', () {
      final redactor = LogRedactor();

      expect(
        redactor.redact('│ │ authorization: Bearer abcdef'),
        '│ │ authorization: ***',
      );
      expect(
        redactor.redact('│ │ Set-Cookie: session=abc'),
        '│ │ Set-Cookie: ***',
      );
      expect(redactor.redact('PASSWORD=secret123'), 'PASSWORD=***');
    });
  });

  group('不误伤', () {
    test('不含敏感字段的行原样返回', () {
      const untouched = [
        '│ │     "title": "Flutter 3.44 新特性解析",',
        '│ │     "expiresIn": 3600',
        '│ │     "user": {id: 1, name: 开发者},',
        '│ ┌─────────────────────────────────',
      ];

      expect(_redactAll(untouched), untouched);
    });

    test('正文里恰好出现 "token" / "password" 这类词不算命字段', () {
      const untouched = [
        '│ │     "message": "wrong password",',
        '│ │     "detail": "token expired",',
      ];

      expect(_redactAll(untouched), untouched);
    });
  });

  group('长值折行（PrettyDioLogger 按 maxWidth 切分）', () {
    test('值的全部分片都被屏蔽，且屏蔽在值结束时收手', () {
      final token = 'eyJhbGciOiJIUzI1NiJ9.${'A' * 200}';
      final lines = [
        '│ │     "refreshToken": "${token.substring(0, 80)}',
        '│ │     ${token.substring(80, 160)}',
        '│ │     ${token.substring(160)}",',
        '│ │     "expiresIn": 3600',
      ];

      final output = _redactAll(lines);

      expect(output.first, '│ │     "refreshToken": ***');
      // 任何分片漏出去都算失败 —— 判据是「分片内容有没有出现」，不是行数
      expect(output.join('\n'), isNot(contains(token.substring(80, 160))));
      expect(output.join('\n'), isNot(contains(token.substring(160, 220))));
      // 收尾引号出现后要收手，不能一路屏蔽到日志末尾
      expect(output.last, '│ │     "expiresIn": 3600');
    });

    test('值在下一行时（key 独占一行）继续屏蔽，遇到分隔线收手', () {
      final redactor = LogRedactor();

      expect(redactor.redact('│ │ authorization: '), '│ │ authorization: ***');
      expect(redactor.redact('│ │ eyJhbGciOiJIUzI1NiJ9'), LogRedactor.masked);
      expect(redactor.redact('│ │ ─────────────────────'), LogRedactor.masked);
      expect(
        redactor.redact('│ │     "expiresIn": 3600'),
        '│ │     "expiresIn": 3600',
      );
    });
  });
}
