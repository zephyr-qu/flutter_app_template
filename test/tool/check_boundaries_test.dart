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

  group('ViewModel 里不能用 service locator', () {
    test('logic 里 getIt<...>() 违规', () {
      final messages = check(
        'lib/features/article/logic/article_view_model.dart',
        'final repo = getIt<ArticleRepository>();',
      );

      expect(messages, hasLength(1));
      expect(messages.single, contains('构造器注入'));
    });

    test('logic 里 GetIt.I<...>() 同样违规', () {
      expect(
        check(
          'lib/features/article/logic/article_view_model.dart',
          'final repo = GetIt.I<ArticleRepository>();',
        ),
        hasLength(1),
      );
    });

    test('page/ 里用 getIt 取 ViewModel 不算规则 1 违规', () {
      // 页面从容器取 ViewModel 是有意的（ADR-0001），规则 1 只管 features/*/logic；
      // 页面这边由「可选注入点」那条规则接手，见下一个 group。
      final messages = check(
        'lib/features/article/page/article_list_page.dart',
        'final vm = getIt<ArticleViewModel>();',
      );

      expect(messages, hasLength(1));
      expect(messages.single, isNot(contains('构造器注入')));
      expect(messages.single, contains('可选注入点'));
    });
  });

  group('页面必须提供可选注入点', () {
    // 合规页面 = 字段 + 构造参数 + `??` 兜底（ADR-0001「缓解措施」）
    const injected = '''
class ArticleListPage extends HookWidget {
  final ArticleViewModel? viewModel;

  const ArticleListPage({super.key, this.viewModel});

  Widget build(BuildContext context) {
    final vm = useMemoized(() => viewModel ?? getIt<ArticleViewModel>());
    return const SizedBox.shrink();
  }
}
''';

    test('三件套齐全 —— 放行', () {
      expect(
        check('lib/features/article/page/article_list_page.dart', injected),
        isEmpty,
      );
    });

    test('直接 getIt<VM>()，没有注入点 —— 报违规', () {
      final messages = check(
        'lib/features/article/page/article_list_page.dart',
        '''
class ArticleListPage extends HookWidget {
  const ArticleListPage({super.key});

  Widget build(BuildContext context) {
    final vm = useMemoized(() => getIt<ArticleViewModel>());
    return const SizedBox.shrink();
  }
}
''',
      );

      expect(messages, hasLength(1));
      expect(messages.single, contains('可选注入点'));
      expect(messages.single, contains('ArticleViewModel'));
    });

    test('字段有默认值、构造器没暴露 —— 报违规（这是最隐蔽的写法）', () {
      // `= null` 让它编译得过，路由也不用改，但测试永远传不进来
      final messages = check(
        'lib/features/article/page/article_list_page.dart',
        '''
class ArticleListPage extends HookWidget {
  final ArticleViewModel? viewModel = null;

  const ArticleListPage({super.key});

  Widget build(BuildContext context) {
    final vm = useMemoized(() => viewModel ?? getIt<ArticleViewModel>());
    return const SizedBox.shrink();
  }
}
''',
      );

      expect(messages, hasLength(1));
      expect(messages.single, contains('this.viewModel'));
    });

    test('留了字段却仍直取容器 —— 兜底缺失', () {
      final messages = check(
        'lib/features/article/page/article_list_page.dart',
        '''
class ArticleListPage extends HookWidget {
  final ArticleViewModel? viewModel;

  const ArticleListPage({super.key, this.viewModel});

  Widget build(BuildContext context) {
    final vm = useMemoized(() => getIt<ArticleViewModel>());
    return const SizedBox.shrink();
  }
}
''',
      );

      expect(messages, hasLength(1));
      expect(messages.single, contains('兜底'));
    });

    test('同一类型取两次也只报一次', () {
      final messages = check(
        'lib/features/article/page/article_list_page.dart',
        'final a = getIt<ArticleViewModel>();\n'
            'final b = getIt<ArticleViewModel>();',
      );

      expect(messages, hasLength(1));
    });

    test('取的是依赖而非 ViewModel —— 不在管辖内', () {
      expect(
        check(
          'lib/features/home/page/home_page.dart',
          'final auth = getIt<AuthStorage>();\n'
              'final preferences = getIt<UserPreferences>();',
        ),
        isEmpty,
      );
    });

    test('logic 里的容器取用只报规则 1，不重复报注入点', () {
      final messages = check(
        'lib/features/article/logic/article_view_model.dart',
        'final vm = getIt<ArticleViewModel>();',
      );

      expect(messages, hasLength(1));
      expect(messages.single, contains('构造器注入'));
    });

    test('文件级规则与行级规则同时命中时，按行号输出', () {
      // 规则 4 的结果在行扫描之前就产生了，排序保证输出顺序与翻文件一致
      final violations = findViolations(
        path: 'lib/features/article/logic/article_view_model.dart',
        content:
            "import 'package:my_app/features/auth/page/login_page.dart';\n"
            'final repo = getIt<ArticleRepository>();',
      );

      expect(violations.map((v) => v.line), [1, 2]);
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
