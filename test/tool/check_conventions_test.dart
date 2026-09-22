import 'package:flutter_test/flutter_test.dart';

import '../../tool/check_boundaries.dart' show dartFiles, normalizePath;
import '../../tool/check_conventions.dart';

/// 约定门禁是脚本 + 纯函数，规则逻辑可以用普通 `test()` 覆盖；
/// 末尾的「真实仓库」用例再拿 `lib/` 本身回归一次。
void main() {
  List<String> messages(String content) => findViolations(
    path: 'lib/features/article/page/article_list_page.dart',
    content: content,
  ).map((v) => v.message).toList();

  group('禁 AsyncState.map', () {
    test('带 data / error 两个具名实参的 map 违规', () {
      final found = messages(
        'final widget = async.map(\n'
        "  data: (v) => Text('\$v'),\n"
        '  loading: () => const SizedBox(),\n'
        '  error: (e, st) => ErrorText(error: e),\n'
        ');',
      );

      expect(found, hasLength(1));
      expect(found.single, contains('AsyncView'));
    });

    test('实参顺序无关：error 在前也照样命中', () {
      const content =
          'final x = async.map(error: (e, st) => e, '
          'loading: () => 0, data: (v) => v);';

      expect(messages(content), hasLength(1));
    });

    test('Iterable.map 不违规（只有位置参数）', () {
      expect(
        messages('final names = list.map((a) => a.title).toList();'),
        isEmpty,
      );
    });

    test('只给 data 的 map 不违规 —— 判据是 data + error 同时出现', () {
      expect(messages('final x = holder.map(data: (v) => v);'), isEmpty);
    });

    test('报出调用所在行', () {
      final violations = findViolations(
        path: 'lib/features/article/page/article_list_page.dart',
        content:
            'void build() {\n'
            '  final w = async.map(\n'
            '    data: (v) => Text(v),\n'
            '    error: (e, st) => ErrorText(error: e),\n'
            '  );\n'
            '}',
      );

      expect(violations.single.line, 2);
    });
  });

  group('注释块上限', () {
    String block(int lines) =>
        List.generate(lines, (i) => '// 第 $i 行').join('\n');

    test('正好 10 行不违规', () {
      expect(messages('${block(10)}\nclass A {}'), isEmpty);
    });

    test('11 行违规，报在块的第一行', () {
      final violations = findViolations(
        path: 'lib/core/util.dart',
        content: 'class A {}\n\n${block(11)}\nclass B {}',
      );

      expect(violations, hasLength(1));
      expect(violations.single.line, 3);
      expect(violations.single.message, contains('11 行'));
    });

    test('空行把两块切开，各自计数', () {
      expect(messages('${block(7)}\n\n${block(7)}\nclass A {}'), isEmpty);
    });

    test('多行字符串里的 // 不算注释', () {
      final content = [
        'final sql = ',
        "  '''",
        '// 这一行在字符串里',
        '// 这一行也在字符串里',
        "''';",
        'class A {}',
      ].join('\n');

      expect(messages(content), isEmpty);
    });

    test('字符串之后的真注释照样算', () {
      final content = [
        'final sql = ',
        "  '''",
        "// 在字符串里''';",
        block(11),
        'class A {}',
      ].join('\n');

      expect(messages(content), hasLength(1));
    });

    test('/// 文档注释与 // 同等计数', () {
      final docComment = List.generate(12, (i) => '/// 第 $i 行').join('\n');
      expect(messages('$docComment\nclass A {}'), hasLength(1));
    });
  });

  group('真实仓库', () {
    test('lib/ 下没有约定违规（回归护栏）', () {
      final violations = <String>[];

      for (final file in dartFiles('lib')) {
        violations.addAll(
          findViolations(
            path: normalizePath(file.path),
            content: file.readAsStringSync(),
          ).map((v) => v.toString()),
        );
      }

      expect(violations, isEmpty, reason: '发现约定违规：\n${violations.join('\n')}');
    });
  });
}
