import 'package:flutter_test/flutter_test.dart';

import '../../tool/check_doc_links.dart';

/// 链接门禁的核心是一个纯函数（`findDocLinkViolations`），文件系统由
/// `exists` / `readFile` 注入，所以能用普通 `test()` 覆盖：
/// 不必真的去建文件，也不必扫整个仓库。
void main() {
  group('规则 A：markdown 相对链接', () {
    test('目标存在 → 不报', () {
      expect(
        _check(
          '见 [spec](.trellis/spec/index.md)。',
          existing: {'.trellis/spec/index.md', 'DOC.md'},
        ),
        isEmpty,
      );
    });

    test('目标不存在 → 报，且带 `文件:行号`', () {
      final violations = _check(
        '第一行\n\n见 [spec](.trellis/spec/gone.md)。',
        existing: {'DOC.md'},
      );

      expect(violations, hasLength(1));
      expect(violations.single, startsWith('DOC.md:3'));
      expect(violations.single, contains('gone.md'));
    });

    test('指向目录也算存在', () {
      expect(
        _check('[spec](.trellis/spec)', existing: {'DOC.md', '.trellis/spec'}),
        isEmpty,
      );
    });

    test('`./a.md#section` 只比 `a.md`', () {
      expect(
        _check('[x](./a.md#section)', existing: {'DOC.md', 'a.md'}),
        isEmpty,
        reason: '锚点不做校验',
      );
      expect(_check('[x](./a.md#section)', existing: {'DOC.md'}), hasLength(1));
    });

    test('`../../AGENTS.md` 能正确 resolve', () {
      final violations = findDocLinkViolations(
        docs: ['.trellis/spec/index.md'],
        exists: {'.trellis/spec/index.md', 'AGENTS.md'}.contains,
        readFile: (_) => '[契约](../../AGENTS.md)',
      );

      expect(violations, isEmpty);
    });

    test('围栏代码块里的链接不报', () {
      expect(
        _check('```markdown\n[x](gone.md)\n```\n', existing: {'DOC.md'}),
        isEmpty,
      );
      expect(_check('~~~\n[x](gone.md)\n~~~\n', existing: {'DOC.md'}), isEmpty);
    });

    test('行内代码里的链接不报', () {
      expect(
        _check('正则写法 `[x](gone.md)` 不是链接。', existing: {'DOC.md'}),
        isEmpty,
      );
      // 实测误报：`['"]([^'"]+)['"]` 里的 `](...)` 会被当成链接
      expect(
        _check(
          '正则 `^\\s*(import\\|export)\\s+[\'"]([^\'"]+)[\'"]` 只取第一个。',
          existing: {'DOC.md'},
        ),
        isEmpty,
      );
    });

    test('双反引号包单反引号的行内代码也不报', () {
      expect(
        _check(
          '写法 `` `[x](gone.md)` `` 与 ``[y](gone.md)``。',
          existing: {'DOC.md'},
        ),
        isEmpty,
      );
    });

    test('外部 URL / 纯锚点 / 绝对链接不报', () {
      expect(
        _check(
          '[a](https://example.com/x.md)\n'
          '[b](http://example.com)\n'
          '[c](mailto:me@example.com)\n'
          '[d](#anchor)\n'
          '[e](file:///Users/someone/local.md)\n'
          '[f](tel:+8613800000000)\n',
          existing: {'DOC.md'},
        ),
        isEmpty,
      );
    });
  });

  group('规则 B：dart 注释里的 spec 引用', () {
    test('引用存在 → 不报', () {
      expect(
        _check(
          '/// 见 data/error-handling.md「登出语义」。',
          path: 'lib/core/base/x.dart',
          existing: {
            'lib/core/base/x.dart',
            '.trellis/spec/data/error-handling.md',
          },
        ),
        isEmpty,
      );
      expect(
        _check(
          '/// 见 ui/state-management.md。',
          path: 'lib/core/base/x.dart',
          existing: {
            'lib/core/base/x.dart',
            '.trellis/spec/ui/state-management.md',
          },
        ),
        isEmpty,
      );
    });

    test('引用不存在 → 报，且带 `文件:行号`', () {
      final violations = _check(
        '// 说明\n'
        '/// 见 data/no-such.md。\n',
        path: 'lib/core/base/x.dart',
        existing: {'lib/core/base/x.dart'},
      );

      expect(violations, hasLength(1));
      expect(violations.single, startsWith('lib/core/base/x.dart:2'));
      expect(violations.single, contains('.trellis/spec/data/no-such.md'));
    });

    test('裸 `cross-cutting.md` 解析到 spec 根', () {
      expect(
        _check(
          '/// 判据见 cross-cutting.md「架构边界与代码形态」。',
          path: 'lib/core/base/x.dart',
          existing: {'lib/core/base/x.dart', '.trellis/spec/cross-cutting.md'},
        ),
        isEmpty,
      );
    });

    test('字符串里的同名片段不是引用', () {
      expect(
        _check(
          "const fixture = '见 data/no-such.md';\n",
          path: 'test/tool/x_test.dart',
          existing: {'test/tool/x_test.dart'},
        ),
        isEmpty,
        reason: '只看 `//` 注释行，否则测试 fixture 会拦下自己',
      );
    });

    test('带 `.trellis/spec/` 前缀的写法不匹配（宁可少报）', () {
      expect(
        _check(
          '/// 见 .trellis/spec/data/no-such.md。',
          path: 'lib/core/base/x.dart',
          existing: {'lib/core/base/x.dart'},
        ),
        isEmpty,
      );
    });

    test('markdown 文件不跑规则 B', () {
      expect(
        _check('<!-- data/no-such.md -->\n', existing: {'DOC.md'}),
        isEmpty,
      );
    });
  });
}

/// 用注入的假文件系统跑一遍检查。
List<String> _check(
  String content, {
  required Set<String> existing,
  String path = 'DOC.md',
}) {
  return findDocLinkViolations(
    docs: [path],
    exists: {...existing, path}.contains,
    readFile: (_) => content,
  );
}
