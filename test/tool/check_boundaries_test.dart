import 'package:flutter_test/flutter_test.dart';

import '../../tool/check_boundaries.dart';

/// 边界检查是脚本 + 纯函数，所以可以用普通 `test()` 覆盖，
/// 不像 analyzer 插件那样只能靠 IDE 手动验证。
void main() {
  List<String> check(String path, String content) => findViolations(
    path: path,
    content: content,
  ).map((v) => v.message).toList();

  group('core 不能依赖上层', () {
    test('core import features 违规', () {
      final messages = check(
        'lib/core/config/app_config.dart',
        "import 'package:my_app/features/auth/data/auth_repository.dart';",
      );

      expect(messages, hasLength(1));
      expect(messages.single, contains('core/ 不能 import'));
    });

    test('core import routing 违规', () {
      final messages = check(
        'lib/core/ui/error_text.dart',
        "import 'package:my_app/app/routing/router.dart';",
      );

      expect(messages, hasLength(1));
      expect(messages.single, contains('core/ 不能 import'));
    });

    test('core 引用 core 没问题', () {
      expect(
        check(
          'lib/core/config/app_config.dart',
          "import 'package:my_app/core/data/storage/auth_storage.dart';",
        ),
        isEmpty,
      );
    });
  });

  group('跨 feature 只共享 data 层', () {
    test('引用另一个 feature 的 logic 违规', () {
      final messages = check(
        'lib/features/profile/page/profile_page.dart',
        "import 'package:my_app/features/auth/logic/auth_view_model.dart';",
      );

      expect(messages, hasLength(1));
      expect(messages.single, contains('features/auth/logic/'));
    });

    test('引用另一个 feature 的 page 违规', () {
      final messages = check(
        'lib/features/home/page/home_page.dart',
        "import 'package:my_app/features/article/page/article_list_page.dart';",
      );

      expect(messages, hasLength(1));
      expect(messages.single, contains('features/article/page/'));
    });

    test('引用另一个 feature 的 data 允许', () {
      expect(
        check(
          'lib/features/profile/page/profile_page.dart',
          "import 'package:my_app/features/auth/data/auth_repository.dart';",
        ),
        isEmpty,
      );
    });

    test('引用自己所在 feature 的 page/logic 允许', () {
      expect(
        check(
          'lib/features/auth/page/login_page.dart',
          "import 'package:my_app/features/auth/logic/auth_view_model.dart';",
        ),
        isEmpty,
      );
    });

    test('相对路径同样能解析出来', () {
      // lib/features/home/page/home_page.dart → ../../article/page/...
      final messages = check(
        'lib/features/home/page/home_page.dart',
        "import '../../article/page/article_list_page.dart';",
      );

      expect(messages, hasLength(1));
      expect(messages.single, contains('features/article/page/'));
    });

    test('外部包与 dart: 忽略', () {
      expect(
        check(
          'lib/features/home/page/home_page.dart',
          "import 'dart:async';\nimport 'package:flutter/material.dart';",
        ),
        isEmpty,
      );
    });

    test('组合层（app/routing）可以引用各 feature 的 page', () {
      expect(
        check(
          'lib/app/routing/router.dart',
          "import 'package:my_app/features/auth/page/login_page.dart';",
        ),
        isEmpty,
      );
    });

    test('app.dart 作为组合根也可以引用 feature', () {
      expect(
        check(
          'lib/app/app.dart',
          "import 'package:my_app/features/home/page/main_page.dart';",
        ),
        isEmpty,
      );
    });

    test('报出行号', () {
      final violations = findViolations(
        path: 'lib/features/home/page/home_page.dart',
        content:
            "import 'package:flutter/material.dart';\n"
            "import 'package:my_app/features/article/page/article_list_page.dart';",
      );

      expect(violations.single.line, 2);
    });
  });

  group('logic 里不得手动建容器', () {
    test('ProviderContainer(...) 违规', () {
      final messages = check(
        'lib/features/sample/logic/sample_list_notifier.dart',
        'final container = ProviderContainer();',
      );

      expect(messages, hasLength(1));
      expect(messages.single, contains('ProviderContainer'));
    });

    test('ProviderContainer.test(...) 同样违规', () {
      expect(
        check(
          'lib/features/sample/logic/sample_list_notifier.dart',
          'final container = ProviderContainer.test();',
        ),
        hasLength(1),
      );
    });

    test('只是提到 ProviderContainer 类型声明，不算建容器', () {
      // 判据是「建容器」（`ProviderContainer(` / `.`），不是出现这个词
      expect(
        check(
          'lib/features/sample/logic/sample_list_notifier.dart',
          '// 容器只在测试里出现，页面与 logic 只吃 ref',
        ),
        isEmpty,
      );
    });

    test('logic 层之外不受这条规则管', () {
      // 规则 3 只管 features/*/logic：页面与装配层不是它的管辖范围
      expect(
        check(
          'lib/features/sample/page/sample_list_page.dart',
          'final container = ProviderContainer();',
        ),
        isEmpty,
      );
      expect(
        check(
          'lib/core/providers.dart',
          'final container = ProviderContainer();',
        ),
        isEmpty,
      );
    });
  });

  group('logic 不得依赖 Flutter UI', () {
    test('logic 里 import material 违规', () {
      final messages = check(
        'lib/features/sample/logic/sample_list_notifier.dart',
        "import 'package:flutter/material.dart';",
      );

      expect(messages, hasLength(1));
      expect(messages.single, contains('material'));
    });

    test('page/ 里 import material 是正常的', () {
      expect(
        check(
          'lib/features/sample/page/sample_list_page.dart',
          "import 'package:flutter/material.dart';",
        ),
        isEmpty,
      );
    });

    test('core/ 里 import material 是正常的（ThemeMode 就在 material 里）', () {
      expect(
        check(
          'lib/core/config/app_settings.dart',
          "import 'package:flutter/material.dart';",
        ),
        isEmpty,
      );
    });

    test('foundation / widgets 不在管辖内', () {
      expect(
        check(
          'lib/features/auth/logic/login_notifier.dart',
          "import 'package:flutter/foundation.dart';\n"
              "import 'package:flutter/widgets.dart';",
        ),
        isEmpty,
      );
    });

    test('报出行号', () {
      final violations = findViolations(
        path: 'lib/features/sample/logic/sample_list_notifier.dart',
        content:
            "import 'package:my_app/core/base/result.dart';\n"
            "import 'package:flutter/material.dart';",
      );

      expect(violations.single.line, 2);
    });
  });

  group('疑似漏检的 warning', () {
    List<BoundaryViolation> warnings(String path, String content) =>
        findViolations(
          path: path,
          content: content,
        ).where((v) => v.isWarning).toList();

    // 第二个 URI 指向别的 feature 的 logic：真去解析就是违规，
    // 现在只会打 warning —— 漏检从「静默」变成「可见」，但仍是漏检。
    const conditionalImport =
        "import './x.dart' if (dart.library.io) '../../auth/logic/v.dart';";

    test('条件导入的 if 分支拿不到 URI —— 打 warning', () {
      final found = warnings(
        'lib/features/home/page/home_page.dart',
        conditionalImport,
      );

      expect(found, hasLength(1));
      expect(found.single.message, contains('条件导入'));
    });

    test('dart format 折行后的指令 —— 打 warning', () {
      // 生成代码里真实长这样：包名一长，format 就把 `as x` 折到下一行
      final found = warnings(
        'lib/core/utils/text.dart',
        "import './x.dart'\n    as y;",
      );

      expect(found, hasLength(1));
      expect(found.single.message, contains('续行'));
    });

    test('指令跨行（URI 在下一行）—— 打 warning', () {
      final found = warnings(
        'lib/core/utils/text.dart',
        "import\n    './x.dart';",
      );

      expect(found, hasLength(1));
      expect(found.single.message, contains('没解析出 URI'));
    });

    test('warning 只提示、不算违规：不拦提交', () {
      final violations = findViolations(
        path: 'lib/features/home/page/home_page.dart',
        content: conditionalImport,
      );

      // 脚本的退出码只看 error，warning 单独打印（见 main()）
      expect(violations.where((v) => !v.isWarning), isEmpty);
    });

    test('完整解析的 import/export 不打 warning', () {
      expect(
        warnings(
          'lib/core/utils/text.dart',
          "import './a.dart' as x;\n"
              "export './a.dart' show A;\n"
              "import './b.dart'; // 行尾注释不影响判定",
        ),
        isEmpty,
      );
    });
  });

  group('真实仓库', () {
    test('lib/ 下没有边界违规，也没有漏检提示（回归护栏）', () {
      final violations = <BoundaryViolation>[];

      for (final file in dartFiles('lib')) {
        violations.addAll(
          findViolations(
            path: normalizePath(file.path),
            content: file.readAsStringSync(),
          ),
        );
      }

      final errors = violations.where((v) => !v.isWarning).toList();
      expect(errors, isEmpty, reason: '发现边界违规：\n${errors.join('\n')}');

      // warning 命中 = 正则级检查已经漏掉 import 了（条件导入 / 跨行指令），
      // 正是 docs/architecture-review.md P4 里「迁到 analyzer AST」的触发条件。
      final missed = violations.where((v) => v.isWarning).toList();
      expect(missed, isEmpty, reason: '检查能力已被撑破：\n${missed.join('\n')}');
    });

    test('生成文件不参与检查', () {
      final paths = dartFiles('lib')
          .map((file) => normalizePath(file.path))
          .toList();

      expect(paths, isNotEmpty);
      expect(paths.where((p) => p.endsWith('.g.dart')), isEmpty);
      expect(paths.where((p) => p.endsWith('.freezed.dart')), isEmpty);
      expect(paths.where((p) => p.endsWith('.gr.dart')), isEmpty);
      expect(paths.where((p) => p.endsWith('.config.dart')), isEmpty);
      expect(paths.where((p) => p.contains('/gen/')), isEmpty);
      expect(paths.where((p) => p.contains('app_localizations')), isEmpty);
    });

    test('手写的组合根仍在检查范围内（只是被放行）', () {
      final paths = dartFiles('lib')
          .map((file) => normalizePath(file.path))
          .toList();

      expect(paths, contains('lib/app/routing/router.dart'));
      expect(paths, contains('lib/app/app.dart'));
    });
  });
}
