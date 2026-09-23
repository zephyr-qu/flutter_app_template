import 'package:flutter_test/flutter_test.dart';

import '../../tool/check_boundaries.dart' show dartFiles, normalizePath;
import '../../tool/check_conventions.dart';

/// 约定门禁是脚本 + 纯函数，规则逻辑可以用普通 `test()` 覆盖；
/// 末尾的「真实仓库」用例再拿 `lib/` 本身回归一次。
void main() {
  List<String> messages(String content) => findViolations(
    path: 'lib/features/sample/page/sample_list_page.dart',
    content: content,
  ).map((v) => v.message).toList();

  group('build 里不得 ref.read', () {
    /// 一个最小的 `build` 方法外壳；`body` 是方法体。
    String widgetBuild(String body) =>
        'class A extends ConsumerWidget {\n'
        '  Widget build(BuildContext context, WidgetRef ref) {\n'
        '$body\n'
        '  }\n'
        '}';

    test('build 里 ref.read(provider) 违规', () {
      final found = messages(
        widgetBuild('final name = ref.read(userProvider);'),
      );

      expect(found, hasLength(1));
      expect(found.single, contains('ref.watch'));
    });

    test('build 里 ref.read(xxx.notifier) 放行', () {
      // 取的是 notifier 实例本身（身份稳定、不参与订阅），当方法接收者用是正当写法
      expect(
        messages(
          widgetBuild('final notifier = ref.read(loginProvider.notifier);'),
        ),
        isEmpty,
      );
    });

    test('dart format 折行后的 ref 换行 .read(...) 也认得出', () {
      final found = messages(
        widgetBuild('final name = ref\n        .read(userProvider);'),
      );

      expect(found, hasLength(1));
    });

    test('build 里的闭包里 ref.read 一样违规', () {
      final found = messages(
        widgetBuild('return Builder(builder: (context) => Text(ref.read(x)));'),
      );

      expect(found, hasLength(1));
    });

    test('Notifier 的 build 里 read 也违规（同样漏订阅）', () {
      final found = messages(
        'class N extends Notifier<int> {\n'
        '  int build() => ref.read(baseProvider);\n'
        '}',
      );

      expect(found, hasLength(1));
    });

    test('build 之外 ref.read 放行 —— 回调里取值本来就该用 read', () {
      expect(
        messages(
          'class A extends ConsumerWidget {\n'
          '  Widget build(BuildContext context, WidgetRef ref) {\n'
          '    return TextButton(onPressed: () => _go(ref), child: label);\n'
          '  }\n'
          '}\n'
          'Future<void> _go(WidgetRef ref) => ref.read(repoProvider).logout();',
        ),
        isEmpty,
      );
    });

    test('ref.watch 不受影响', () {
      expect(
        messages(widgetBuild('final name = ref.watch(userProvider);')),
        isEmpty,
      );
    });

    test('报出调用所在行', () {
      final violations = findViolations(
        path: 'lib/features/sample/page/sample_list_page.dart',
        content:
            'class A extends ConsumerWidget {\n'
            '  Widget build(BuildContext context, WidgetRef ref) {\n'
            '    final name = ref.read(userProvider);\n'
            '    return Text(name);\n'
            '  }\n'
            '}',
      );

      expect(violations.single.line, 3);
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
