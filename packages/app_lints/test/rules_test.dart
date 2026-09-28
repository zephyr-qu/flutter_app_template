import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:app_lints/src/rules.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

/// `app_lints` 七条规则的测试。
///
/// 用官方 `analyzer_testing` 的 `AnalysisRuleTest`：`testFileName` 决定被测文件落在
/// 包内哪个路径（规则的判据依赖路径，如 `lib/core/`），`newFile` 造被引用的文件，
/// `newPackage` 造 `package:flutter/...` 这类外部包的 stub。
///
/// 两条容易踩的约定：
/// - `newFile` 要**绝对路径**，所以拼 `testPackageLibPath`（它已经指向包的 `lib/`）；
/// - 被 import / 被引用的符号必须真的存在，否则会冒 `undefined_identifier` 之类
///   的错误，污染断言。
void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(CoreImportsRuleTest);
    defineReflectiveTests(CrossFeatureImportsRuleTest);
    defineReflectiveTests(ServiceLocatorInLogicRuleTest);
    defineReflectiveTests(ServiceLocatorOutsideLogicRuleTest);
    defineReflectiveTests(PageInjectionPointRuleTest);
    defineReflectiveTests(AvoidAsyncStateMapRuleTest);
    defineReflectiveTests(CommentBlockTooLongRuleTest);
    defineReflectiveTests(LogicImportsMaterialRuleTest);
    defineReflectiveTests(LogicImportsMaterialOutsideLogicTest);
  });
}

/// 一个能编译通过的 service locator 形态，避免用未定义标识符污染断言。
///
/// 两条约束：
/// - 形状照 get_it 的真实形态：`getIt<T>()` 是**顶层函数**、`GetIt.I` 是带成员的
///   对象。刻意不写成「`getIt` 是可调用对象」——那样 `getIt<T>()` 会被解析成隐式的
///   `call` 调用，规则拿到的是**合成**节点，而 `reportAtNode` 对合成节点不产生诊断，
///   断言会假失败。
/// - 桩里**不能**出现真的 locator 取用（如 `GetIt.I.get<T>()`）：桩与用例同在
///   被测文件里，桩自己那一次也会被规则报出来。
const String _locatorStub = '''
class GetIt {
  static GetIt I = GetIt();
  T get<T>() => _zero as T;
  void reset() {}
}

final Object _zero = 0;

T getIt<T>() => _zero as T;
''';

const String _viewModelStub = 'class FooViewModel {}\n';

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

/// 规则 3：`features/*/logic/` 不得用 service locator。
@reflectiveTest
class ServiceLocatorInLogicRuleTest extends AnalysisRuleTest {
  @override
  String get testFileName => 'features/a/logic/probe.dart';

  @override
  void setUp() {
    rule = ServiceLocatorInLogicRule();
    super.setUp();
  }

  Future<void> _flag(String invocation) async {
    final source =
        '$_locatorStub$_viewModelStub'
        'class Zz {\n'
        '  void probe() {\n'
        '    $invocation;\n'
        '  }\n'
        '}\n';
    final offset = source.indexOf(invocation);

    await assertDiagnostics(source, [lint(offset, invocation.length)]);
  }

  Future<void> test_getIt_function() => _flag('getIt<FooViewModel>()');

  Future<void> test_GetIt_dot_I_member_with_type_argument() =>
      _flag('GetIt.I.get<FooViewModel>()');

  Future<void> test_GetIt_dot_I_member_access() => _flag('GetIt.I.reset()');

  void test_constructor_injection_ok() async {
    final source =
        '$_locatorStub$_viewModelStub'
        'class Zz {\n'
        '  Zz(this._dependencies);\n'
        '  final FooViewModel _dependencies;\n'
        '}\n';

    await assertNoDiagnostics(source);
  }
}

/// 规则 3 只管 `features/*/logic/`：同一个调用在别的层不该报。
@reflectiveTest
class ServiceLocatorOutsideLogicRuleTest extends AnalysisRuleTest {
  @override
  String get testFileName => 'features/a/data/probe.dart';

  @override
  void setUp() {
    rule = ServiceLocatorInLogicRule();
    super.setUp();
  }

  void test_getIt_in_data_layer_ok() async {
    final source =
        '$_locatorStub$_viewModelStub'
        'FooViewModel probe() => getIt<FooViewModel>();\n';

    await assertNoDiagnostics(source);
  }
}

/// 规则 4：从容器取 ViewModel 的页面必须给可选注入点。
@reflectiveTest
class PageInjectionPointRuleTest extends AnalysisRuleTest {
  @override
  String get testFileName => 'features/a/page/probe.dart';

  @override
  void setUp() {
    rule = PageInjectionPointRule();
    super.setUp();
  }

  void test_missing_injection_point() async {
    const invocation = 'getIt<FooViewModel>()';
    final source =
        '$_locatorStub$_viewModelStub'
        'FooViewModel probe() => $invocation;\n';
    final offset = source.indexOf(invocation);

    await assertDiagnostics(source, [lint(offset, invocation.length)]);
  }

  void test_partial_injection_point() async {
    // 有字段与构造参数，但缺 `viewModel ?? getIt<...>()` 兜底
    const invocation = 'getIt<FooViewModel>()';
    final source =
        '$_locatorStub$_viewModelStub'
        'class ZzPage {\n'
        '  const ZzPage({this.viewModel});\n'
        '  final FooViewModel? viewModel;\n'
        '  FooViewModel resolve() => $invocation;\n'
        '}\n';
    final offset = source.indexOf(invocation);

    await assertDiagnostics(source, [lint(offset, invocation.length)]);
  }

  void test_complete_injection_point_ok() async {
    final source =
        '$_locatorStub$_viewModelStub'
        'class ZzPage {\n'
        '  const ZzPage({this.viewModel});\n'
        '  final FooViewModel? viewModel;\n'
        '  FooViewModel resolve() => viewModel ?? getIt<FooViewModel>();\n'
        '}\n';

    await assertNoDiagnostics(source);
  }

  void test_non_view_model_lookup_ok() async {
    // 只看 `*ViewModel`：直接取依赖的页面不归本规则管
    final source =
        '$_locatorStub'
        'class AuthStorage {}\n'
        'AuthStorage probe() => getIt<AuthStorage>();\n';

    await assertNoDiagnostics(source);
  }
}

/// 规则 5：禁 `AsyncState.map`。
@reflectiveTest
class AvoidAsyncStateMapRuleTest extends AnalysisRuleTest {
  @override
  String get testFileName => 'core/probe.dart';

  @override
  void setUp() {
    rule = AvoidAsyncStateMapRule();
    super.setUp();
  }

  static const String _stub = '''
class ZzAsyncState {
  int map({int data = 0, int error = 0}) => data + error;
}
''';

  void test_map_with_data_and_error() async {
    const invocation = 'state.map(data: 1, error: 2)';
    final source =
        '$_stub'
        'int probe(ZzAsyncState state) => $invocation;\n';
    final offset = source.indexOf(invocation);

    await assertDiagnostics(source, [lint(offset, invocation.length)]);
  }

  void test_iterable_map_ok() async {
    // 位置参数的 map 不是 AsyncState.map
    await assertNoDiagnostics(
      'List<int> probe() => [1, 2].map((e) => e + 1).toList();\n',
    );
  }

  void test_map_with_only_data_ok() async {
    await assertNoDiagnostics(
      '$_stub'
      'int probe(ZzAsyncState state) => state.map(data: 1);\n',
    );
  }
}

/// 规则 6：连续注释块 ≤10 行。
@reflectiveTest
class CommentBlockTooLongRuleTest extends AnalysisRuleTest {
  @override
  String get testFileName => 'core/probe.dart';

  @override
  void setUp() {
    rule = CommentBlockTooLongRule();
    super.setUp();
  }

  void test_eleven_line_block() async {
    const line = '// 注释行';
    final block = List.filled(11, line).join('\n');
    final source = '$block\nclass Zz {}\n';

    await assertDiagnostics(source, [lint(0, line.length)]);
  }

  void test_ten_line_block_ok() async {
    final block = List.filled(10, '// 注释行').join('\n');

    await assertNoDiagnostics('$block\nclass Zz {}\n');
  }

  void test_comment_markers_in_multiline_string_ok() async {
    // 多行字符串里的 `//` 不是注释
    final body = List.filled(12, '// 不是注释').join('\n');

    await assertNoDiagnostics('const s = """\n$body\n""";\n');
  }
}

/// 规则 7：`features/*/logic/` 不得 import/export UI。
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

  /// 只认 material.dart 的话，改引 widgets.dart 就绕过了 —— 正反例都要钉住。
  Future<void> _flag(String uri, String call) async {
    final source = "import '$uri';\nvoid use() => $call();\n";

    await assertDiagnostics(source, [lint(0, source.indexOf(';') + 1)]);
  }

  Future<void> test_imports_material() =>
      _flag('package:flutter/material.dart', 'm');

  Future<void> test_imports_widgets() =>
      _flag('package:flutter/widgets.dart', 'w');

  void test_exports_material() async {
    final source = "export 'package:flutter/material.dart';\n";

    await assertDiagnostics(source, [lint(0, source.indexOf(';') + 1)]);
  }

  void test_imports_own_page() async {
    newFile('$testPackageLibPath/features/a/page/zz.dart', 'void zz() {}\n');
    final source =
        "import '../page/zz.dart';\n"
        'void use() => zz();\n';

    await assertDiagnostics(source, [lint(0, source.indexOf(';') + 1)]);
  }

  void test_foundation_ok() async {
    final source =
        "import 'package:flutter/foundation.dart';\n"
        'void use() => f();\n';

    await assertNoDiagnostics(source);
  }

  void test_same_feature_logic_ok() async {
    newFile('$testPackageLibPath/features/a/logic/zz.dart', 'void zz() {}\n');
    final source =
        "import '../logic/zz.dart';\n"
        'void use() => zz();\n';

    await assertNoDiagnostics(source);
  }

  void test_other_feature_data_ok() async {
    newFile('$testPackageLibPath/features/b/data/zz.dart', 'void zz() {}\n');
    final source =
        "import '../../b/data/zz.dart';\n"
        'void use() => zz();\n';

    await assertNoDiagnostics(source);
  }
}

/// 规则 7 只管 `features/*/logic/`：页面 import UI 是本分，同一个 import 在页面层不该报。
@reflectiveTest
class LogicImportsMaterialOutsideLogicTest extends AnalysisRuleTest {
  @override
  String get testFileName => 'features/a/page/probe.dart';

  @override
  void setUp() {
    newPackage('flutter')..addFile('lib/material.dart', 'void m() {}\n');
    rule = LogicImportsMaterialRule();
    super.setUp();
  }

  void test_material_in_page_ok() async {
    final source =
        "import 'package:flutter/material.dart';\n"
        'void use() => m();\n';

    await assertNoDiagnostics(source);
  }
}
