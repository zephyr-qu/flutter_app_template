import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import 'paths.dart';

/// 规则 1：`core/` 不得 import/export 上层（`features/` / `app/`）。
///
/// 依赖方向只能是 features → core。底座一旦反向依赖业务，抽象就报废了。
class CoreImportsRule extends _ImportRule {
  static const LintCode code = LintCode(
    'no_upper_import_in_core',
    'core/ 不能 import/export {0} —— 依赖方向只能是 features → core',
    severity: DiagnosticSeverity.WARNING,
  );

  CoreImportsRule()
    : super(
        name: 'no_upper_import_in_core',
        description:
            'Flags core/ files importing or exporting features/ or app/.',
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  List<Object>? check({
    required String fromPath,
    required String? target,
    required String rawUri,
  }) {
    if (target == null) return null;
    if (!fromPath.startsWith('lib/core/')) return null;
    if (!target.startsWith('lib/features/') && !target.startsWith('lib/app/')) {
      return null;
    }
    return [target];
  }
}

/// 规则 2：跨 feature 只共享 `data/` 层。
///
/// `page/` / `logic/` 是 feature 内部实现，其他 feature 不得引用。
class CrossFeatureImportsRule extends _ImportRule {
  static const LintCode code = LintCode(
    'cross_feature_only_data',
    '不能引用 {0} —— 跨 feature 只共享 data 层（page / logic 属于 feature 内部，'
        '改成引 core 的共享能力或对方 data 层）',
    severity: DiagnosticSeverity.WARNING,
  );

  CrossFeatureImportsRule()
    : super(
        name: 'cross_feature_only_data',
        description:
            'Flags cross-feature references to layers other than data/.',
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  List<Object>? check({
    required String fromPath,
    required String? target,
    required String rawUri,
  }) {
    // 组合层（app 层）负责装配，可以 import 任何东西；core 由上一条规则管
    if (fromPath.startsWith('lib/app/')) return null;
    if (fromPath.startsWith('lib/core/')) return null;
    if (target == null) return null;

    final from = featureOf(fromPath);
    final to = featureOf(target);
    if (to == null || to == from) return null;

    // 只有 `data/` 层可跨 feature 共享；层目录缺失（feature 根上的文件）同样
    // 不是 data，按违规处理，否则引对方的聚合 barrel 会静默放行
    final layer = layerOf(target);
    if (layer == 'data') return null;

    return [layer == null ? 'features/$to/' : 'features/$to/$layer/'];
  }
}

/// 规则 3：`features/*/logic/` 不得用 service locator（`getIt` / `GetIt.I`）。
///
/// ViewModel 的依赖必须走构造器注入：service locator 让「这个 ViewModel 需要什么」
/// 从构造函数签名里消失，测试也就只能先装配全局容器（见 docs/adr/ADR-0001.md）。
class ServiceLocatorInLogicRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'no_service_locator_in_logic',
    'features/*/logic 里不得使用 getIt —— 依赖要用构造器注入（见 ADR-0001）',
    severity: DiagnosticSeverity.WARNING,
  );

  ServiceLocatorInLogicRule()
    : super(
        name: 'no_service_locator_in_logic',
        description: 'Flags service locator lookups in features/*/logic/.',
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addMethodInvocation(this, _ServiceLocatorVisitor(this, context));
  }
}

/// 规则 4：从容器取 ViewModel 的页面必须给出「可选注入点」。
///
/// 页面自己走 `getIt<VM>()` 是**有意**的——把它改成必填参数会把路由与 DI 绑死
/// （见 docs/adr/ADR-0001.md）。代价落在页面测试上：必须先装配全局容器。ADR 给的
/// 缓解是页面开一个可选构造参数，容器只做兜底：
///
/// ```dart
/// final ArticleViewModel? viewModel;                        // 只有测试会传
/// const ArticleListPage({super.key, this.viewModel});
/// final vm = useMemoized(() => viewModel ?? getIt<ArticleViewModel>());
/// ```
///
/// 这三处没有任何编译器保护：少写照样能跑，只是测试被悄悄推回 `setUpTestApp()`。
/// 所以做成门禁。`features/*/logic/` 不在这里管：那里的 `getIt` 由规则 3 禁止。
class PageInjectionPointRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'page_must_expose_view_model_injection_point',
    '取 {0} 的页面必须给可选注入点（ADR-0001），缺 {1}',
    severity: DiagnosticSeverity.WARNING,
  );

  PageInjectionPointRule()
    : super(
        name: 'page_must_expose_view_model_injection_point',
        description:
            'Flags pages that fetch a ViewModel from the container without '
            'exposing the optional constructor injection point.',
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addCompilationUnit(
      this,
      _PageInjectionPointVisitor(this, context),
    );
  }
}

/// 规则 5：禁 `AsyncState.map`，改用 `AsyncView`（`core/ui/async_view.dart`）。
///
/// 判据是**具名实参**：`AsyncState.map` 必带 `data` 与 `error`，而 `Iterable.map`
/// / `Stream.map` 只接位置参数。所以这里不会把 `list.map(...)` 判成违规——
/// 也正因为要看实参名，这条规则写不成单行正则。
class AvoidAsyncStateMapRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'avoid_async_state_map',
    '禁用 AsyncState.map（回调签名运行期才校验），改用 AsyncView —— 见 '
        'frontend/state-management.md「渲染状态」',
    severity: DiagnosticSeverity.WARNING,
  );

  AvoidAsyncStateMapRule()
    : super(
        name: 'avoid_async_state_map',
        description: 'Flags AsyncState.map in favour of AsyncView.',
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addMethodInvocation(this, _AsyncStateMapVisitor(this, context));
  }
}

/// 连续注释块的行数上限，超过就该把解释搬进 spec。
const int maxCommentBlockLines = 10;

/// 规则 6：连续注释块不得超过 [maxCommentBlockLines] 行。
///
/// 长的「为什么」属于 spec（见 guides/comment-guidelines.md）：留在代码里会和实现
/// 抢注意力，且改了一处、另一处就成了假信息。超限就把解释搬走，只留一行链接。
class CommentBlockTooLongRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'comment_block_too_long',
    '注释块 {0} 行，超过 {1} 行上限 —— 解释搬到 spec，代码里只留一行链接',
    severity: DiagnosticSeverity.WARNING,
  );

  CommentBlockTooLongRule()
    : super(
        name: 'comment_block_too_long',
        description: 'Flags comment blocks longer than 10 lines.',
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addCompilationUnit(this, _CommentBlockVisitor(this, context));
  }
}

/// 规则 7：`features/*/logic/` 不得 import/export UI。
///
/// 拦三样：`package:flutter/material.dart`、`package:flutter/widgets.dart`
/// （Widget / BuildContext 都在 widgets 里，只挡 material 等于一行 import 就绕过），
/// 以及**本 feature** 的 `page/` 层文件。`foundation` 放行（`ChangeNotifier` /
/// `@visibleForTesting` 在 logic 里正当）；跨 feature 的 `page/` 由规则 2 拦，两边不重复报。
///
/// 与规则 1/2 同类（都是「谁能依赖谁」）：那两条管依赖方向，这条管同一 feature 内的层次。
class LogicImportsMaterialRule extends _ImportRule {
  static const LintCode code = LintCode(
    'no_material_import_in_logic',
    'logic 层不得 import/export {0} —— logic 层是纯 Dart 状态层，'
        'UI（widgets、page 层文件）只能留在页面层',
    severity: DiagnosticSeverity.WARNING,
  );

  LogicImportsMaterialRule()
    : super(
        name: 'no_material_import_in_logic',
        description:
            'Flags UI coupling (material/widgets imports, own-feature page '
            'imports) in features/*/logic/.',
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  List<Object>? check({
    required String fromPath,
    required String? target,
    required String rawUri,
  }) {
    if (!_isFeatureLogic(fromPath)) return null;
    if (rawUri == 'package:flutter/material.dart' ||
        rawUri == 'package:flutter/widgets.dart') {
      return [rawUri];
    }
    if (target == null) return null;

    final from = featureOf(fromPath);
    if (from == null || featureOf(target) != from) return null;
    if (layerOf(target) != 'page') return null;
    return ['features/$from/page/'];
  }
}

abstract class _ImportRule extends AnalysisRule {
  _ImportRule({required super.name, required super.description});

  /// 返回诊断参数（插值进 `LintCode` 的 `{0}`…）；不违规返回 null。
  ///
  /// [target] 是 import 解析出的仓库相对路径，外部包 / `dart:` 为 null；
  /// 需要看原始 URI 的规则用 [rawUri]。
  List<Object>? check({
    required String fromPath,
    required String? target,
    required String rawUri,
  });

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry
      ..addImportDirective(this, _ImportVisitor(this, context))
      ..addExportDirective(this, _ImportVisitor(this, context));
  }
}

class _ImportVisitor extends SimpleAstVisitor<void> {
  _ImportVisitor(this._rule, this._context);

  final _ImportRule _rule;
  final RuleContext _context;

  @override
  void visitImportDirective(ImportDirective node) {
    _check(node);
  }

  @override
  void visitExportDirective(ExportDirective node) {
    _check(node);
  }

  void _check(AstNode node) {
    if (!_context.isInLibDir) return;

    final fromPath = currentPath(_context);
    if (fromPath == null || isGeneratedPath(fromPath)) return;

    final rawUri = switch (node) {
      ImportDirective(:final uri) => uri.stringValue,
      ExportDirective(:final uri) => uri.stringValue,
      _ => null,
    };
    if (rawUri == null) return;

    final arguments = _rule.check(
      fromPath: fromPath,
      target: resolveImport(rawUri, fromPath),
      rawUri: rawUri,
    );
    if (arguments != null) _rule.reportAtNode(node, arguments: arguments);
  }
}

class _ServiceLocatorVisitor extends SimpleAstVisitor<void> {
  _ServiceLocatorVisitor(this._rule, this._context);

  final ServiceLocatorInLogicRule _rule;
  final RuleContext _context;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (!_context.isInLibDir) return;

    final fromPath = currentPath(_context);
    if (fromPath == null || isGeneratedPath(fromPath)) return;
    if (!_isFeatureLogic(fromPath)) return;
    if (!_isServiceLocatorLookup(node)) return;

    _rule.reportAtNode(node);
  }
}

class _PageInjectionPointVisitor extends SimpleAstVisitor<void> {
  _PageInjectionPointVisitor(this._rule, this._context);

  final PageInjectionPointRule _rule;
  final RuleContext _context;

  @override
  void visitCompilationUnit(CompilationUnit node) {
    if (!_context.isInLibDir) return;

    final fromPath = currentPath(_context);
    if (fromPath == null || isGeneratedPath(fromPath)) return;
    // logic 里的 getIt 由规则 3 直接禁止，这里只管页面
    if (_isFeatureLogic(fromPath)) return;

    final content = _context.currentUnit?.content;
    if (content == null) return;

    final collector = _ContainerLookupCollector();
    node.accept(collector);

    for (final entry in collector.firstByType.entries) {
      final type = entry.key;
      final missing = <String>[
        if (!content.contains('final $type? viewModel;'))
          '字段 `final $type? viewModel;`',
        if (!content.contains('this.viewModel')) '构造参数 `this.viewModel`',
        if (!_fallbackPattern(type).hasMatch(content))
          '`viewModel ?? getIt<$type>()` 兜底',
      ];
      if (missing.isEmpty) continue;

      _rule.reportAtNode(entry.value, arguments: [type, missing.join('、')]);
    }
  }
}

/// 收集「从容器取过的 ViewModel 类型」→ 首次出现的那次调用。
class _ContainerLookupCollector extends RecursiveAstVisitor<void> {
  final Map<String, MethodInvocation> firstByType = {};

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final type = _containerViewModelType(node);
    if (type != null) firstByType.putIfAbsent(type, () => node);
    super.visitMethodInvocation(node);
  }
}

class _AsyncStateMapVisitor extends SimpleAstVisitor<void> {
  _AsyncStateMapVisitor(this._rule, this._context);

  final AvoidAsyncStateMapRule _rule;
  final RuleContext _context;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name != 'map') return;
    if (!_context.isInLibDir) return;

    final fromPath = currentPath(_context);
    if (fromPath == null || isGeneratedPath(fromPath)) return;
    if (!_isAsyncStateMap(node.argumentList)) return;

    _rule.reportAtNode(node);
  }
}

class _CommentBlockVisitor extends SimpleAstVisitor<void> {
  _CommentBlockVisitor(this._rule, this._context);

  final CommentBlockTooLongRule _rule;
  final RuleContext _context;

  @override
  void visitCompilationUnit(CompilationUnit node) {
    if (!_context.isInLibDir) return;

    final fromPath = currentPath(_context);
    if (fromPath == null || isGeneratedPath(fromPath)) return;

    final content = _context.currentUnit?.content;
    if (content == null) return;

    final lines = content.split('\n');
    final offsets = <int>[];
    var offset = 0;
    for (final line in lines) {
      offsets.add(offset);
      offset += line.length + 1;
    }

    final strings = _stringRanges(node);
    var start = -1;

    void closeBlock(int end) {
      if (start < 0) return;
      final length = end - start;
      if (length > maxCommentBlockLines) {
        _rule.reportAtOffset(
          offsets[start],
          lines[start].length,
          arguments: [length, maxCommentBlockLines],
        );
      }
      start = -1;
    }

    for (var index = 0; index < lines.length; index++) {
      // 多行字符串里的 `//` 不是注释：靠字符偏移判断，不靠猜引号
      final lineOffset = offsets[index];
      final inString = strings.any(
        (range) => lineOffset >= range.$1 && lineOffset < range.$2,
      );

      if (!inString && lines[index].trimLeft().startsWith('//')) {
        if (start < 0) start = index;
        continue;
      }
      closeBlock(index);
    }
    closeBlock(lines.length);
  }
}

/// 字符串字面量占用的字符区间 `[起始, 结束)`。
///
/// 单行字面量也收进来：它的区间落在自身那一行内部，永远不会盖住行首偏移，
/// 所以不必先判断是否跨行。
List<(int, int)> _stringRanges(CompilationUnit unit) {
  final visitor = _StringRangeVisitor();
  unit.accept(visitor);
  return visitor.ranges;
}

class _StringRangeVisitor extends RecursiveAstVisitor<void> {
  final List<(int, int)> ranges = [];

  @override
  void visitSimpleStringLiteral(SimpleStringLiteral node) {
    ranges.add((node.offset, node.end));
    super.visitSimpleStringLiteral(node);
  }

  @override
  void visitStringInterpolation(StringInterpolation node) {
    ranges.add((node.offset, node.end));
    super.visitStringInterpolation(node);
  }
}

/// 是否是一次 service locator 取用 —— 覆盖 get_it 的两种真实形态：
/// 顶层函数 `getIt<X>()`，以及 `GetIt.I` 上的成员调用 `GetIt.I.get<X>()`。
///
/// 换个写法不该绕过规则，所以判据落在「接收者是 `getIt` 或 `GetIt.I`」上，
/// 而不是某一种调用形态。
///
/// 刻意不支持 `GetIt.I<X>()`（把 `I` 当可调用对象并显式给类型实参）：那种写法
/// 会被解析成隐式的 `call` 调用，节点是**合成**的，而 `reportAtNode` 对合成节点
/// 不产生诊断 —— 想支持得先拿到非合成的锚点，收益不抵复杂度，get_it 的用法里
/// 也不存在。`getIt` 同理：本项目里它是顶层函数，不是可调用对象。
bool _isServiceLocatorLookup(MethodInvocation node) {
  if (node.methodName.name == 'getIt' && node.target == null) return true;
  return _isNamed(node.target, 'getIt') || _isGetItInstance(node.target);
}

/// 从 `getIt<XxxViewModel>()` 里取出 `XxxViewModel`；不是这种形态返回 null。
///
/// 只看显式类型实参、且以 `ViewModel` 结尾的形式（与旧脚本「只看 `*ViewModel`」
/// 的口径一致）：`getIt<AuthStorage>()` 这类直接取依赖的页面不归本规则管。
String? _containerViewModelType(MethodInvocation node) {
  if (!_isServiceLocatorLookup(node)) return null;

  final typeArguments = node.typeArguments;
  if (typeArguments == null || typeArguments.arguments.length != 1) return null;

  final type = typeArguments.arguments.single;
  if (type is! NamedType) return null;

  final name = type.name.lexeme;
  return name.endsWith('ViewModel') ? name : null;
}

/// 可选注入点的兜底写法：`viewModel ?? getIt<XxxViewModel>()`。
RegExp _fallbackPattern(String type) =>
    RegExp('viewModel\\s*\\?\\s*\\?\\s*getIt<\\s*$type\\s*>');

/// 接收者是不是 [expected] 这个名字（`getIt` / `GetIt`）。
bool _isNamed(Expression? expression, String expected) => switch (expression) {
  SimpleIdentifier(:final name) => name == expected,
  PrefixedIdentifier(:final identifier) => identifier.name == expected,
  PropertyAccess(:final propertyName) => propertyName.name == expected,
  _ => false,
};

/// `GetIt.I` —— `GetIt` 是前缀或属性两种形态都算。
bool _isGetItInstance(Expression? expression) => switch (expression) {
  PrefixedIdentifier(:final prefix, :final identifier) =>
    prefix.name == 'GetIt' && identifier.name == 'I',
  PropertyAccess(:final target, :final propertyName) =>
    target is SimpleIdentifier &&
        target.name == 'GetIt' &&
        propertyName.name == 'I',
  _ => false,
};

bool _isFeatureLogic(String path) =>
    RegExp('(?:^|/)features/[^/]+/logic/').hasMatch(path);

/// `AsyncState.map` 必带的具名实参——用于把它和其它 `map` 区分开。
const Set<String> _asyncStateMapArguments = {'data', 'error'};

bool _isAsyncStateMap(ArgumentList arguments) {
  final names = {
    for (final argument in arguments.arguments)
      if (argument is NamedArgument) argument.name.lexeme,
  };
  return names.containsAll(_asyncStateMapArguments);
}
