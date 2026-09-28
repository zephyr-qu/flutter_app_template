import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:app_lints/src/rules.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

/// `app_lints` 四条规则的测试。
///
/// 用官方 `analyzer_testing` 的 `AnalysisRuleTest`：`testFileName` 决定被测文件落在
/// 包内哪个路径（规则的判据依赖路径，如 `lib/core/`），`newFile` 造被引用的文件，
/// `newPackage` 造 `package:flutter/...` 这类外部包的 stub。
///
/// 两条容易踩的约定：
/// - `newFile` 要**绝对路径**，所以拼 `testPackageLibPath`（它已经指向包的 `lib/`）；
/// - 被 import 的符号必须真的被用到，否则会冒 `unused_import` 错误，污染断言。
void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(CoreImportsRuleTest);
    defineReflectiveTests(CrossFeatureImportsRuleTest);
    defineReflectiveTests(LogicImportsMaterialRuleTest);
    defineReflectiveTests(RefReadInBuildRuleTest);
  });
}

/// 规则 1：`core/` 不得 import 上层。
@reflectiveTest
class CoreImportsRuleTest extends AnalysisRuleTest {
  @override
  String get testFileName => 'core/probe.dart';

  @override
  void setUp() {
    rule = CoreImportsRule();
    super.setUp();
  }

  void test_core_imports_feature() async {
    newFile('$testPackageLibPath/features/b/logic/zz.dart', 'void zz() {}\n');
    final source =
        "import '../features/b/logic/zz.dart';\n"
        'void use() => zz();\n';

    await assertDiagnostics(source, [lint(0, source.indexOf(';') + 1)]);
  }

  void test_core_exports_feature() async {
    newFile('$testPackageLibPath/features/b/data/zz.dart', 'void zz() {}\n');
    final source = "export '../features/b/data/zz.dart';\n";

    await assertDiagnostics(source, [lint(0, source.indexOf(';') + 1)]);
  }

  void test_core_imports_app() async {
    newFile('$testPackageLibPath/app/router.dart', 'void r() {}\n');
    final source =
        "import '../app/router.dart';\n"
        'void use() => r();\n';

    await assertDiagnostics(source, [lint(0, source.indexOf(';') + 1)]);
  }

  void test_core_imports_core_ok() async {
    newFile('$testPackageLibPath/core/x.dart', 'void x() {}\n');

    await assertNoDiagnostics(
      "import 'x.dart';\n"
      'void use() => x();\n',
    );
  }

  void test_feature_imports_core_ok() async {
    newFile('$testPackageLibPath/core/x.dart', 'void x() {}\n');

    await assertNoDiagnostics(
      "import '../core/x.dart';\n"
      'void use() => x();\n',
    );
  }
}

/// 规则 2：跨 feature 只共享 `data/`。
@reflectiveTest
class CrossFeatureImportsRuleTest extends AnalysisRuleTest {
  @override
  String get testFileName => 'features/a/page/probe.dart';

  @override
  void setUp() {
    rule = CrossFeatureImportsRule();
    super.setUp();
  }

  void test_other_feature_logic() async {
    newFile('$testPackageLibPath/features/b/logic/zz.dart', 'void zz() {}\n');
    final source =
        "import '../../b/logic/zz.dart';\n"
        'void use() => zz();\n';

    await assertDiagnostics(source, [lint(0, source.indexOf(';') + 1)]);
  }

  void test_other_feature_exports_logic() async {
    newFile('$testPackageLibPath/features/b/logic/zz.dart', 'void zz() {}\n');
    final source = "export '../../b/logic/zz.dart';\n";

    await assertDiagnostics(source, [lint(0, source.indexOf(';') + 1)]);
  }

  void test_other_feature_page() async {
    newFile('$testPackageLibPath/features/b/page/zz.dart', 'void zz() {}\n');
    final source =
        "import '../../b/page/zz.dart';\n"
        'void use() => zz();\n';

    await assertDiagnostics(source, [lint(0, source.indexOf(';') + 1)]);
  }

  void test_other_feature_data_ok() async {
    newFile('$testPackageLibPath/features/b/data/zz.dart', 'void zz() {}\n');

    await assertNoDiagnostics(
      "import '../../b/data/zz.dart';\n"
      'void use() => zz();\n',
    );
  }

  void test_same_feature_logic_ok() async {
    newFile('$testPackageLibPath/features/a/logic/zz.dart', 'void zz() {}\n');

    await assertNoDiagnostics(
      "import '../logic/zz.dart';\n"
      'void use() => zz();\n',
    );
  }

  void test_other_feature_root_file() async {
    newFile('$testPackageLibPath/features/b/b.dart', 'void zz() {}\n');
    final source =
        "import '../../b/b.dart';\n"
        'void use() => zz();\n';

    await assertDiagnostics(source, [lint(0, source.indexOf(';') + 1)]);
  }
}

/// 规则 3：`features/*/logic/` 不得 import material。
@reflectiveTest
class LogicImportsMaterialRuleTest extends AnalysisRuleTest {
  @override
  String get testFileName => 'features/a/logic/probe.dart';

  @override
  void setUp() {
    newPackage('flutter')
      ..addFile('lib/material.dart', 'void m() {}\n')
      ..addFile('lib/widgets.dart', 'void w() {}\n')
      ..addFile('lib/foundation.dart', 'void f() {}\n');
    rule = LogicImportsMaterialRule();
    super.setUp();
  }

  void test_logic_imports_material() async {
    final source =
        "import 'package:flutter/material.dart';\n"
        'void use() => m();\n';

    await assertDiagnostics(source, [lint(0, source.indexOf(';') + 1)]);
  }

  void test_logic_imports_widgets() async {
    final source =
        "import 'package:flutter/widgets.dart';\n"
        'void use() => w();\n';

    await assertDiagnostics(source, [lint(0, source.indexOf(';') + 1)]);
  }

  void test_logic_imports_own_page() async {
    newFile('$testPackageLibPath/features/a/page/zz.dart', 'void zz() {}\n');
    final source =
        "import '../page/zz.dart';\n"
        'void use() => zz();\n';

    await assertDiagnostics(source, [lint(0, source.indexOf(';') + 1)]);
  }

  void test_logic_imports_other_feature_data_ok() async {
    newFile('$testPackageLibPath/features/b/data/zz.dart', 'void zz() {}\n');
    final source =
        "import '../../b/data/zz.dart';\n"
        'void use() => zz();\n';

    await assertNoDiagnostics(source);
  }

  void test_logic_exports_material() async {
    final source = "export 'package:flutter/material.dart';\n";

    await assertDiagnostics(source, [lint(0, source.indexOf(';') + 1)]);
  }

  void test_logic_imports_foundation_ok() async {
    await assertNoDiagnostics(
      "import 'package:flutter/foundation.dart';\n"
      'void use() => f();\n',
    );
  }
}

/// 规则 4：`build` 里不得用 `ref.read` 取值。
@reflectiveTest
class RefReadInBuildRuleTest extends AnalysisRuleTest {
  @override
  String get testFileName => 'features/a/logic/probe.dart';

  @override
  void setUp() {
    rule = RefReadInBuildRule();
    super.setUp();
  }

  /// 一个能编译通过的 `ref` 形态，避免用未定义标识符污染断言。
  static const _refStub = '''
class ZzRef {
  T read<T>(T provider) => provider;
  T watch<T>(T provider) => provider;
}

class ZzNotifier {
  void update() {}
}

class ZzProvider {
  ZzNotifier notifier = ZzNotifier();
}
''';

  void test_ref_read_of_value_in_build() async {
    final invocation = 'ref.read(42)';
    final source =
        '''
$_refStub
class ZzWidget {
  int build() {
    final ref = ZzRef();
    return $invocation;
  }
}
''';

    final offset = source.indexOf(invocation);
    await assertDiagnostics(source, [lint(offset, invocation.length)]);
  }

  void test_this_ref_read_of_value_in_build() async {
    final invocation = 'this.ref.read(42)';
    final source =
        '''
$_refStub
class ZzWidget {
  final ZzRef ref = ZzRef();
  int build() {
    return $invocation;
  }
}
''';

    final offset = source.indexOf(invocation);
    await assertDiagnostics(source, [lint(offset, invocation.length)]);
  }

  void test_ref_read_notifier_in_build_ok() async {
    final source =
        '''
$_refStub
class ZzWidget {
  int build() {
    final ref = ZzRef();
    final p = ZzProvider();
    ref.read(p.notifier).update();
    return 0;
  }
}
''';

    await assertNoDiagnostics(source);
  }

  void test_ref_read_outside_build_ok() async {
    final source =
        '''
$_refStub
class ZzWidget {
  int helper() {
    final ref = ZzRef();
    return ref.read(42);
  }
}
''';

    await assertNoDiagnostics(source);
  }

  void test_ref_watch_in_build_ok() async {
    final source =
        '''
$_refStub
class ZzWidget {
  int build() {
    final ref = ZzRef();
    return ref.watch(42);
  }
}
''';

    await assertNoDiagnostics(source);
  }
}
