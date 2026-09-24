// 代码形态约定（依赖方向在 tool/check_boundaries.dart，不在这里），扫 lib/：
//   avoid_ref_read_in_build —— build 里不得用 ref.read 取 provider 值
//   comment_block_too_long  —— 注释块 ≤10 行，长解释搬进 spec
//
// ```bash
// dart run tool/check_conventions.dart [root]
// ```
//
// 用 package:analyzer 的 parseString 做语法级判断：两条规则都要 AST ——
// 「调用点在不在 build 方法体里」「实参是不是 .notifier」都不是正则能可靠判断的
// 形态，而误报会挡住提交。规则见 .trellis/spec/cross-cutting.md「代码形态约定」。

import 'dart:io';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import 'check_boundaries.dart'
    show BoundaryViolation, dartFiles, defaultRoots, normalizePath;

/// 连续注释块的行数上限，超过就该把解释搬进 spec。
const int maxCommentBlockLines = 10;

/// 规则 1 的提示语。
const String _refReadMessage =
    // 中文句子在换行处本来就不加空格，这条规则的前提是英文长句
    // ignore: missing_whitespace_between_adjacent_strings
    'build 里不要用 ref.read 取 provider 值 —— 它不建立订阅，provider 变化不会重建；'
    '读值用 ref.watch（ref.read(xxx.notifier) 取 notifier 调方法不在此列）';

/// 规则 2 的提示语尾部。
const String _commentBlockTail = '解释搬到 spec，代码里只留一行链接';

void main(List<String> args) => exitCode = run(args);

/// 跑一遍检查，返回退出码（0 = 通过）。
///
/// 拆出来是为了让 `tool/verify.dart` 能在**同一个进程**里依次调四道脚本门禁。
int run(List<String> args) {
  final roots = args.where((arg) => !arg.startsWith('-')).toList();
  final targets = roots.isEmpty ? defaultRoots : roots;
  final violations = <BoundaryViolation>[];

  for (final root in targets) {
    for (final file in dartFiles(root)) {
      violations.addAll(
        findViolations(
          path: normalizePath(file.path),
          content: file.readAsStringSync(),
        ),
      );
    }
  }

  if (violations.isEmpty) {
    stdout.writeln('✅ 形态约定检查通过（${targets.join(' ')}）');
    return 0;
  }

  stderr.writeln('❌ 形态约定违规 ${violations.length} 处：');
  for (final violation in violations) {
    stderr.writeln('  • $violation');
  }
  return 1;
}

/// 检查单个文件，返回全部约定违规（按行号排序）。
///
/// 只解析一次：两条规则都要 AST（调用的位置与实参形态、字符串字面量的范围）。
List<BoundaryViolation> findViolations({
  required String path,
  required String content,
}) {
  final parsed = parseString(content: content, throwIfDiagnostics: false);
  final violations = <BoundaryViolation>[
    ...findRefReadInBuild(path: path, parsed: parsed),
    ...findLongCommentBlocks(path: path, parsed: parsed),
  ]..sort((a, b) => a.line.compareTo(b.line));

  return violations;
}

/// 规则 1：`build` 里不得用 `ref.read` 读 provider 的**值**。
///
/// `ref.read` 不建立订阅：provider 变化后不会重建，界面停在旧值上。唯一的例外是
/// `ref.read(xxx.notifier)`——取的是 notifier 实例本身（身份稳定、不参与订阅），
/// 页面把它当方法接收者用（`onChanged: notifier.updateEmail`）是正当写法。
///
/// 判据落在 AST 上：「调用点在不在名为 `build` 的方法体内」（方法体里的闭包也算）
/// 与「实参是不是 `.notifier`」，正则都分不清。
List<BoundaryViolation> findRefReadInBuild({
  required String path,
  required ParseStringResult parsed,
}) {
  final visitor = _RefReadInBuildVisitor(
    (offset) => parsed.lineInfo.getLocation(offset).lineNumber,
  );
  parsed.unit.accept(visitor);

  return [
    for (final line in visitor.lines)
      BoundaryViolation(file: path, line: line, message: _refReadMessage),
  ];
}

/// 规则 2：连续注释块不得超过 [maxCommentBlockLines] 行。
///
/// 长的「为什么」属于 spec（guides/comment-guidelines.md）：留在代码里会和实现
/// 抢注意力，且改了一处、另一处就成了假信息。超限就把解释搬走，只留一行链接。
List<BoundaryViolation> findLongCommentBlocks({
  required String path,
  required ParseStringResult parsed,
  int maxLines = maxCommentBlockLines,
}) {
  final lines = parsed.content.split('\n');
  final strings = _stringRanges(parsed.unit);
  final violations = <BoundaryViolation>[];
  var start = -1;

  void closeBlock(int end) {
    if (start < 0) return;
    final length = end - start;
    if (length > maxLines) {
      violations.add(
        BoundaryViolation(
          file: path,
          line: start + 1,
          message: '注释块 $length 行，超过 $maxLines 行上限 —— $_commentBlockTail',
        ),
      );
    }
    start = -1;
  }

  for (var index = 0; index < lines.length; index++) {
    // 多行字符串里的 `//` 不是注释：靠字符偏移判断，不靠猜引号
    final offset = parsed.lineInfo.getOffsetOfLine(index);
    final inString = strings.any(
      (range) => offset >= range.$1 && offset < range.$2,
    );

    if (!inString && lines[index].trimLeft().startsWith('//')) {
      if (start < 0) start = index;
      continue;
    }
    closeBlock(index);
  }
  closeBlock(lines.length);

  return violations;
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

class _RefReadInBuildVisitor extends RecursiveAstVisitor<void> {
  new(this.lineOf);

  /// 偏移量 → 行号，由调用方绑定 [ParseStringResult.lineInfo]。
  final int Function(int offset) lineOf;

  final List<int> lines = [];

  /// 当前是否在 `build` 方法体内（>0 即在内，方法体里的闭包也算）。
  int _buildDepth = 0;

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    final isBuild = node.name.lexeme == 'build';
    if (isBuild) _buildDepth++;
    super.visitMethodDeclaration(node);
    if (isBuild) _buildDepth--;
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (_buildDepth > 0 && _isRefReadOfValue(node)) {
      lines.add(lineOf(node.offset));
    }
    super.visitMethodInvocation(node);
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
