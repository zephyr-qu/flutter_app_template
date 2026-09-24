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

    final layer = layerOf(target);
    if (layer == null || layer == 'data') return null;

    return ['features/$to/$layer/'];
  }
}

/// 规则 3：`features/*/logic/` 不得 import/export `package:flutter/material.dart`。
///
/// logic 层是纯 Dart 状态层；出现 material 通常意味着把 Widget / BuildContext
/// 塞了进去。只认这一个 URI（`foundation` / `widgets` 不管）。
class LogicImportsMaterialRule extends _ImportRule {
  static const LintCode code = LintCode(
    'no_material_import_in_logic',
    'logic 层不得 import/export package:flutter/material.dart —— logic 层是纯 Dart，'
        '出现 material 通常意味着把 Widget / BuildContext 塞进了状态层',
    severity: DiagnosticSeverity.WARNING,
  );

  LogicImportsMaterialRule()
    : super(
        name: 'no_material_import_in_logic',
        description:
            'Flags material.dart imports or exports in features/*/logic/.',
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
    if (rawUri != 'package:flutter/material.dart') return null;
    return const [];
  }
}

/// 规则 4：`build` 方法体里不得用 `ref.read` 读 provider 的**值**。
///
/// `ref.read` 不建立订阅：provider 变化后不会重建，界面停在旧值上。例外是
/// `ref.read(xxx.notifier)`——取的是 notifier 实例本身（身份稳定），页面把它当
/// 方法接收者用是正当写法。
class RefReadInBuildRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'avoid_ref_read_in_build',
    'build 里不要用 ref.read 取 provider 值 —— 它不建立订阅，provider 变化不会重建；'
        '读值用 ref.watch（ref.read(xxx.notifier) 取 notifier 调方法不在此列）',
    severity: DiagnosticSeverity.WARNING,
  );

  RefReadInBuildRule()
    : super(
        name: 'avoid_ref_read_in_build',
        description: 'Flags ref.read of a provider value inside build.',
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addMethodInvocation(this, _RefReadVisitor(this, context));
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

class _RefReadVisitor extends SimpleAstVisitor<void> {
  _RefReadVisitor(this._rule, this._context);

  final RefReadInBuildRule _rule;
  final RuleContext _context;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (!_context.isInLibDir) return;

    final fromPath = currentPath(_context);
    if (fromPath == null || isGeneratedPath(fromPath)) return;

    if (!_isRefReadOfValue(node)) return;

    // 最近的 `build` 方法祖先（方法体里的闭包也算）
    final enclosing = node.thisOrAncestorMatching(
      (n) => n is MethodDeclaration,
    );
    if (enclosing is! MethodDeclaration || enclosing.name.lexeme != 'build') {
      return;
    }

    _rule.reportAtNode(node);
  }
}

/// 是不是「取 provider 值」的 `ref.read`；`ref.read(xxx.notifier)` 放行。
bool _isRefReadOfValue(MethodInvocation node) {
  final target = node.target;
  if (target is! SimpleIdentifier || target.name != 'ref') return false;
  if (node.methodName.name != 'read') return false;

  final arguments = node.argumentList.arguments;
  if (arguments.length != 1) return false;

  // 具名实参不是 `ref.read` 的正当写法，按取值的 read 处理
  final argument = arguments.single;
  if (argument is! Expression) return true;

  return !_isNotifierAccess(argument);
}

/// `xxx.notifier`——读到的是 notifier 实例本身，不是 provider 的值。
bool _isNotifierAccess(Expression expression) => switch (expression) {
  PrefixedIdentifier(:final identifier) => identifier.name == 'notifier',
  PropertyAccess(:final propertyName) => propertyName.name == 'notifier',
  _ => false,
};

bool _isFeatureLogic(String path) =>
    RegExp('(?:^|/)features/[^/]+/logic/').hasMatch(path);
