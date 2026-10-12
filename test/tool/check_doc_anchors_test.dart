import 'package:flutter_test/flutter_test.dart';

import '../../tool/check_doc_anchors.dart';

/// 判据是一个纯函数（`findDocAnchorViolations`），文件系统由 `exists` / `readFile`
/// 注入，所以能用普通 `test()` 覆盖：不必真的建文件，也不必扫整个仓库。
void main() {
  group('章节关键词引用', () {
    test('关键词被某个标题包含 → 不报', () {
      expect(
        _check(
          '见 data/database-guidelines.md「分工」。',
          files: {
            '.trellis/spec/data/database-guidelines.md':
                '# 数据库规范\n\n### 分工：schema 在 core，查询在 feature\n',
          },
        ),
        isEmpty,
        reason: '引用写的是关键词，不是完整标题 —— 包含即通过',
      );
    });

    test('markdown 链接形式的引用也能对上', () {
      expect(
        _check(
          '见 [data/database-guidelines.md](./data/database-guidelines.md)「分工」。',
          files: {
            '.trellis/spec/data/database-guidelines.md':
                '# 数据库规范\n\n### 分工：schema 在 core，查询在 feature\n',
          },
        ),
        isEmpty,
        reason: '`[x.md](x.md)「关键词」` 与 `x.md「关键词」` 是同一件事',
      );
    });

    test('没有任何标题包含关键词 → 报，且带 `文件:行号`', () {
      final violations = _check(
        '第一行\n\n见 data/x.md「不存在的章节」。',
        files: {'.trellis/spec/data/x.md': '# 数据库规范\n\n## 概览\n'},
      );

      expect(violations, hasLength(1));
      expect(violations.single, startsWith('DOC.md:3'));
      expect(violations.single, contains('没有标题包含它'));
      expect(violations.single, contains('data/x.md'));
    });

    test('描述性关键词（正文短语）→ 报出来，属已知容差', () {
      final violations = _check(
        '见 data/x.md「读要软，写要硬」。',
        files: {'.trellis/spec/data/x.md': '# 数据库规范\n\n正文里才写「读要软，写要硬」这句。\n'},
      );

      expect(violations, hasLength(1));
      expect(violations.single, contains('没有标题包含它'));
    });

    test('描述性说法恰好是标题的一部分 → 通过', () {
      expect(
        _check(
          '见 data/x.md「读要软，写要硬」。',
          files: {
            '.trellis/spec/data/x.md':
                '# 数据库规范\n\n### AuthStorage 的失败策略：读要软，写要硬\n',
          },
        ),
        isEmpty,
      );
    });

    test('无 `「」` 的引用跳过（文件级由 check_doc_links.dart 负责）', () {
      expect(
        _check('见 data/x.md 这一节。'),
        isEmpty,
        reason: '没有「」，也可能只是路径引用；文件存不存在不归本工具管',
      );
    });

    test('围栏代码块里的引用跳过', () {
      expect(_check('```markdown\n见 data/x.md「不存在的章节」。\n```\n'), isEmpty);
    });

    test('行内代码里的模板占位符跳过，真实路径的 code span 仍会被检查', () {
      expect(_check('指路写成 `<层>/<文件>.md「<章节>」`：'), isEmpty, reason: '占位符不是真实路径');
      expect(
        _check(
          '见 `data/x.md`「不存在的章节」。',
          files: {'.trellis/spec/data/x.md': '# 数据库规范\n'},
        ),
        hasLength(1),
      );
    });

    test('dart 只认 `//` 注释行 —— 字符串里的同名片段不是引用', () {
      expect(
        _check(
          "const fixture = '见 data/x.md「不存在的章节」。';\n",
          path: 'lib/core/base/x.dart',
        ),
        isEmpty,
      );
      expect(
        _check(
          '// 见 data/x.md「不存在的章节」。\n',
          path: 'lib/core/base/x.dart',
          files: {'.trellis/spec/data/x.md': '# 数据库规范\n'},
        ),
        hasLength(1),
      );
    });

    test('目标文件不存在 → 报', () {
      final violations = _check('见 data/no-such.md「分工」。');

      expect(violations, hasLength(1));
      expect(violations.single, contains('目标文件不存在'));
    });

    test('`../x.md` 按引用所在目录 resolve', () {
      expect(
        _check(
          '见 [../data/error-handling.md](../data/error-handling.md)「登出语义」。',
          path: '.trellis/spec/ui/routing.md',
          files: {
            '.trellis/spec/data/error-handling.md': '# 错误处理\n\n### 登出语义\n',
          },
        ),
        isEmpty,
      );
    });

    test('`.trellis/spec/x.md` 这类仓库相对路径与 `.mdc` 目标都能对上', () {
      expect(
        _check(
          '见 [`.cursor/rules/project-conventions.mdc`](.cursor/rules/project-conventions.mdc)「不存在的东西」。',
          path: 'README.md',
          files: {
            '.cursor/rules/project-conventions.mdc':
                '# 项目硬约束\n\n## 不存在的东西（不要「补回来」）\n',
          },
        ),
        isEmpty,
      );
    });
  });

  group('退出码策略（不进 just verify 的依据）', () {
    test('默认恒为 0；--strict 且有发现才 1', () {
      expect(anchorExitCode(const [], strict: false), 0);
      expect(anchorExitCode(const ['x'], strict: false), 0);
      expect(anchorExitCode(const [], strict: true), 0);
      expect(anchorExitCode(const ['x'], strict: true), 1);
    });
  });
}

/// 用注入的假文件系统跑一遍检查：`files` 是 `路径 → 内容`，被检文档由 [content] 提供。
List<String> _check(
  String content, {
  Map<String, String> files = const {},
  String path = 'DOC.md',
}) {
  return findDocAnchorViolations(
    docs: [path],
    exists: (probe) => probe == path || files.containsKey(probe),
    readFile: (probe) => probe == path ? content : files[probe]!,
  );
}
