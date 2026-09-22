import 'package:flutter_test/flutter_test.dart';

import '../../tool/prune.dart';

// ──────────────────────────────────────────────
// 为什么这些断言里可以放心写 `l10n.x` 字面量
// ──────────────────────────────────────────────
// `tool/prune.dart` 的通用改写会扫 lib/ 与 test/ 下所有含 `l10n.` 的文件，
// 但它显式跳过了 `test/tool/**`（见 `_localizationAwareFiles`）——那批文件
// 是本脚本自己的 fixture，喂进去的 `l10n.` / `package:.../l10n/...` 都是测试
// 数据而不是真实调用点。所以这份测试可以正常写字面量，不会在裁剪时被改掉。

void main() {
  group('parseArb', () {
    test('取出 key → 文案，跳过 @@locale / @key 元数据与非字符串值', () {
      const content =
          '{\n'
          '  "@@locale": "zh",\n'
          '  "title": "标题",\n'
          '  "@title": {"description": "标题的元数据"},\n'
          '  "count": 3\n'
          '}\n';

      expect(parseArb(content), <String, String>{'title': '标题'});
    });
  });

  group('rewriteLocalizations', () {
    test('裸 l10n 调用换成中文字面量', () {
      final failures = <String>[];

      expect(
        rewriteLocalizations(
          'Text(l10n.title)',
          <String, String>{'title': '标题'},
          failures,
          'x.dart',
        ),
        "Text('标题')",
      );
      expect(failures, isEmpty);
    });

    test('AppLocalizations.of(context).x 也换掉', () {
      final failures = <String>[];

      expect(
        rewriteLocalizations(
          'Text(AppLocalizations.of(context).title)',
          <String, String>{'title': '标题'},
          failures,
          'x.dart',
        ),
        "Text('标题')",
      );
      expect(failures, isEmpty);
    });

    test('占位符实参的尾逗号不会被带进插值（否则是语法错误）', () {
      final failures = <String>[];

      final out = rewriteLocalizations(
        r"l10n.requestFailed('${code}',)",
        <String, String>{'requestFailed': '失败（{code}）'},
        failures,
        'x.dart',
      );

      expect(out, r"'失败（${'${code}'}）'");
      expect(failures, isEmpty);
    });

    test('占位符实参里嵌套的 l10n 调用会被递归改写', () {
      final failures = <String>[];

      final out = rewriteLocalizations(
        'l10n.greeting(user ?? l10n.fallback)',
        <String, String>{'greeting': '你好, {name}', 'fallback': '访客'},
        failures,
        'x.dart',
      );

      expect(out, r"'你好, ${user ?? '访客'}'");
      expect(failures, isEmpty);
    });

    test('localizedMessage 去掉遗留的 l10n 实参', () {
      final failures = <String>[];

      expect(
        rewriteLocalizations(
          'error.localizedMessage(l10n)',
          const <String, String>{},
          failures,
          'x.dart',
        ),
        'error.localizedMessage()',
      );
    });

    test('移除 l10n 声明与 l10n import', () {
      final failures = <String>[];
      const content =
          "import 'package:my_app/l10n/app_localizations.dart';\n"
          '\n'
          'void f() {\n'
          '  final l10n = AppLocalizations.of(context);\n'
          '  return l10n.title;\n'
          '}\n';

      final out = rewriteLocalizations(
        content,
        <String, String>{'title': '标题'},
        failures,
        'x.dart',
      );

      expect(out, contains("return '标题';"));
      expect(out, isNot(contains('app_localizations')));
      expect(out, isNot(contains('AppLocalizations.of')));
      expect(out, isNot(contains('final l10n')));
      expect(failures, isEmpty);
    });

    test('摘掉 MaterialApp 的 l10n 三件套（delegates / locales / locale）', () {
      final failures = <String>[];
      const content =
          'MaterialApp(\n'
          '  theme: t,\n'
          '  localizationsDelegates: AppLocalizations.localizationsDelegates,\n'
          '  supportedLocales: AppLocalizations.supportedLocales,\n'
          "  locale: const Locale('zh'),\n"
          '  home: h,\n'
          ')\n';

      expect(
        rewriteLocalizations(
          content,
          const <String, String>{},
          failures,
          'x.dart',
        ),
        'MaterialApp(\n  theme: t,\n  home: h,\n)\n',
      );
      expect(failures, isEmpty);
    });

    test('去掉 wrapPage 的 locale 实参，并保留外层调用的右括号', () {
      final failures = <String>[];

      expect(
        rewriteLocalizations(
          "wrapPage(Home(), locale: const Locale('en'))",
          const <String, String>{},
          failures,
          'x.dart',
        ),
        'wrapPage(Home())',
      );
      expect(
        rewriteLocalizations(
          'wrapPage(Other(), locale: locale)',
          const <String, String>{},
          failures,
          'x.dart',
        ),
        'wrapPage(Other())',
      );
      expect(failures, isEmpty);
    });

    test('ARB 里没有的 key 记进 failures，且不动调用点', () {
      final failures = <String>[];

      expect(
        rewriteLocalizations(
          'l10n.nope',
          const <String, String>{},
          failures,
          'x.dart',
        ),
        'l10n.nope',
      );
      expect(failures, hasLength(1));
    });

    test('不含 l10n 的代码原样返回', () {
      final failures = <String>[];

      expect(
        rewriteLocalizations(
          'void f() {}',
          const <String, String>{},
          failures,
          'x.dart',
        ),
        'void f() {}',
      );
      expect(failures, isEmpty);
    });
  });

  group('参数轴与常量', () {
    test('l10n 轴支持 multi / single，默认 multi', () {
      expect(supportedAxes['l10n'], containsAll(<String>['multi', 'single']));
      expect(defaultAxes['l10n'], 'multi');
    });

    test('ARB 路径与 l10n 自有的删除清单', () {
      expect(arbPath, 'lib/l10n/app_zh.arb');
      expect(l10nOwnedPaths, isNotEmpty);
    });
  });
}
