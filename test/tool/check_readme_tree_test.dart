import 'package:flutter_test/flutter_test.dart';

import '../../tool/check_readme_tree.dart';

/// 目录树检查的核心是两个纯函数（`parseTree` / `findTreeViolations`），
/// 所以能用普通 `test()` 覆盖，不必真的去读文档或扫 `lib/`。
void main() {
  group('parseTree', () {
    test('按缩进还原完整路径', () {
      const markdown = '''
```
lib/
├── main.dart                  # 程序入口
├── core/
│   ├── base/
│   │   └── result.dart
│   └── theme/
└── di/
```
''';

      expect(parseTree(markdown, 'lib').map((e) => e.label), [
        'main.dart',
        'core/',
        'core/base/',
        'core/base/result.dart',
        'core/theme/',
        'di/',
      ]);
    });

    test('忽略不以根开头的代码块', () {
      const markdown = '''
```dart
final x = 1;
```

```
lib/
└── main.dart
```
''';

      expect(parseTree(markdown, 'lib'), hasLength(1));
    });

    test('跳过空行与只有连接线的行', () {
      const markdown = '''
```
lib/
├── a.dart
│
└── b.dart
```
''';

      expect(parseTree(markdown, 'lib'), hasLength(2));
    });

    test('`#` 之后是注释，不混进路径', () {
      const markdown = '''
```
lib/
└── a.dart    # 说明文字
```
''';

      expect(parseTree(markdown, 'lib').single.path, 'a.dart');
    });
  });

  group('规则 1：树里列了、实际不存在', () {
    test('报出已删除的路径', () {
      const markdown = '''
```
lib/
├── gone.dart
└── ok.dart
```
''';

      final violations = _check(markdown, existing: {'ok.dart'});

      expect(violations, hasLength(1));
      expect(violations.single, contains('gone.dart'));
      expect(violations.single, contains('实际不存在'));
    });

    test('模板占位符不参与存在性检查', () {
      const markdown = '''
```
lib/
└── {feature}/
    └── {name}_page.dart
```
''';

      expect(_check(markdown, existing: const {}), isEmpty);
    });
  });

  group('规则 2：实际有、树里漏了', () {
    test('已展开的目录必须列全', () {
      const markdown = '''
```
lib/
└── core/
    └── base/
        └── result.dart
```
''';

      final violations = _check(
        markdown,
        existing: {'core', 'core/base', 'core/base/result.dart'},
        children: const {
          '': ['core'],
          'core': ['base', 'core_module.dart'],
          'core/base': ['result.dart'],
        },
      );

      expect(violations, hasLength(1));
      expect(violations.single, contains('core_module.dart'));
    });

    test('只写目录名、不展开的，不检查其内容', () {
      const markdown = '''
```
lib/
└── features/
    └── article/
```
''';

      expect(
        _check(
          markdown,
          existing: {'features', 'features/article'},
          children: const {
            '': ['features'],
            'features': ['article'],
            'features/article': ['logic', 'data', 'page'],
          },
        ),
        isEmpty,
      );
    });

    test('用模板占位符展开的目录不检查其内容', () {
      const markdown = '''
```
lib/
└── features/
    └── {feature}/
        └── page/
```
''';

      expect(
        _check(
          markdown,
          existing: {'features'},
          children: const {
            '': ['features'],
            'features': ['auth', 'article'],
          },
        ),
        isEmpty,
      );
    });

    test('生成物不要求在树里列出', () {
      const markdown = '''
```
lib/
└── di/
    └── service_locator.dart
```
''';

      expect(
        _check(
          markdown,
          existing: {'di', 'di/service_locator.dart'},
          children: const {
            '': ['di'],
            'di': ['service_locator.dart', 'service_locator.config.dart'],
          },
        ),
        isEmpty,
      );
    });
  });
}

/// 用注入的假文件系统跑一遍检查。
List<String> _check(
  String markdown, {
  required Set<String> existing,
  Map<String, List<String>> children = const {},
}) {
  return findTreeViolations(
    docPath: 'DOC.md',
    entries: parseTree(markdown, 'lib'),
    exists: existing.contains,
    children: (dir) => children[dir] ?? const [],
  );
}
