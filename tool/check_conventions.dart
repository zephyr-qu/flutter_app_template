// 代码形态约定（依赖方向在 tool/check_boundaries.dart，不在这里），扫 lib/：
//   avoid_async_state_map   —— 禁 AsyncState.map，改用 AsyncView
//   comment_block_too_long  —— 注释块 ≤10 行，长解释搬进 spec
//
// ```bash
// dart run tool/check_conventions.dart [root]
// ```
//
// 用 package:analyzer 的 parseString 做语法级判断：`map` 要看具名实参才分得清
// AsyncState.map 与 list.map。规则见 .trellis/spec/cross-cutting.md「代码形态约定」。

import 'dart:io';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import 'check_boundaries.dart' show BoundaryViolation, dartFiles, normalizePath;

/// 连续注释块的行数上限，超过就该把解释搬进 spec。
const int maxCommentBlockLines = 10;

/// `AsyncState.map` 必带的具名实参——用于把它和其它 `map` 区分开。
const Set<String> _asyncStateMapArguments = {'data', 'error'};

/// 规则 1 的提示语。第一段留了尾随空格：中文换行处本来不加空格，而
/// missing_whitespace_between_adjacent_strings 是按英文长句设计的。
const String _mapMessage =
    '禁用 AsyncState.map（回调签名运行期才校验），改用 AsyncView —— 见 '
    'frontend/state-management.md「渲染状态」';

/// 规则 2 的提示语尾部。
const String _commentBlockTail = '解释搬到 spec，代码里只留一行链接';

void main(List<String> args) {
  final roots = args.where((arg) => !arg.startsWith('-')).toList();
  final targets = roots.isEmpty ? const ['lib'] : roots;
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
    return;
  }

  stderr.writeln('❌ 形态约定违规 ${violations.length} 处：');
  for (final violation in violations) {
    stderr.writeln('  • $violation');
  }
  exitCode = 1;
}

/// 检查单个文件，返回全部约定违规（按行号排序）。
///
/// 只解析一次：两条规则都要 AST（`map` 的具名实参、字符串字面量的范围）。
List<BoundaryViolation> findViolations({
  required String path,
  required String content,
}) {
  final parsed = parseString(content: content, throwIfDiagnostics: false);
  final violations = <BoundaryViolation>[
    ...findAsyncStateMap(path: path, parsed: parsed),
    ...findLongCommentBlocks(path: path, parsed: parsed),
  ]..sort((a, b) => a.line.compareTo(b.line));

  return violations;
}

/// 规则 1：禁 `AsyncState.map`，用 `AsyncView`（core/ui/async_view.dart）。
///
/// 判据是**具名实参**：`AsyncState.map` 必带 `data` 与 `error`，而 `Iterable.map`
/// / `Stream.map` 只接位置参数。所以这里不会把 `list.map(...)` 判成违规——
/// 也正因为要看实参名，这条规则写不成单行正则。
List<BoundaryViolation> findAsyncStateMap({
  required String path,
  required ParseStringResult parsed,
}) {
  // 绝大多数字符串里没有 `.map(`，先便宜地跳过再解析
  if (!parsed.content.contains('.map(')) return const <BoundaryViolation>[];

  final visitor = _AsyncStateMapVisitor(
    (offset) => parsed.lineInfo.getLocation(offset).lineNumber,
  );
  parsed.unit.accept(visitor);

  return [
    for (final line in visitor.lines)
      BoundaryViolation(file: path, line: line, message: _mapMessage),
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

class _AsyncStateMapVisitor extends RecursiveAstVisitor<void> {
  new(this.lineOf);

  /// 偏移量 → 行号，由调用方绑定 [ParseStringResult.lineInfo]。
  final int Function(int offset) lineOf;

  final List<int> lines = [];

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'map' && _isAsyncStateMap(node.argumentList)) {
      lines.add(lineOf(node.offset));
    }
    super.visitMethodInvocation(node);
  }
}

bool _isAsyncStateMap(ArgumentList arguments) {
  final names = {
    for (final argument in arguments.arguments)
      if (argument is NamedArgument) argument.name.lexeme,
  };
  return names.containsAll(_asyncStateMapArguments);
}
