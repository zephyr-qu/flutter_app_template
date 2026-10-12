// 章节关键词引用（`路径.md「关键词」`）的报告工具 —— **只报告，不拦提交**。
//
// ```bash
// dart run tool/check_doc_anchors.dart             # 只报告，退出码恒为 0
// dart run tool/check_doc_anchors.dart --strict      # 有关键词对不上时退出码 1
// dart run tool/check_doc_anchors.dart README.md     # 只检查指定文件
// ```
//
// 为什么要它：`tool/check_doc_links.dart` 只做**文件级**校验（路径存不存在），看不到
// 「章节关键词」。而 `guides/comment-guidelines.md` 要求引用写标题关键词，改标题在本仓库
// 又是常规操作（一轮收敛能改上百个标题）—— 关键词断了没人报：编辑器不报、Git 不报、
// 测试也不报。
//
// 为什么不进 `just verify`：改标题是常态，拦提交会误伤；它的价值在「改完标题顺手看一眼」。
// 所以默认退出码 0，`--strict` 才返回 1。扫描面直接调 `tool/check_doc_links.dart` 的
// `collectFiles()` —— 两份扫描面必然漂，不抄第二份。
//
// 判据：目标文件里**任一标题包含**该关键词即通过（引用写的是关键词，不是完整标题），
// 标题取 `#` 到 `######`，围栏代码块里的 `#` 是代码注释、不算标题。
// 无 `「」` 的引用整条跳过 —— 文件级校验已由 `check_doc_links.dart` 负责。
//
// 已知容差（宁可少报，也不误报）：
//   - `路径.md` 与 `「关键词」` 之间隔着字（如 `x.md 的「yy」`）的写法认不出
//   - 引用的是正文短语而非标题时会被报出 —— 这是报告不是门禁，人工判断即可

import 'dart:io';

import 'check_doc_links.dart' show collectFiles, resolveFrom, visitProseLines;

/// 引用形态：`路径.md「关键词」`。
///
/// 路径与 `「」` 之间允许一个收尾符 —— markdown 链接的 `)` 或 code span 的 `` ` ``，
/// 因为 `[x.md](x.md)「关键词」` 与 `` `x.md`「关键词」 `` 是同一件事的写法。
/// 前置边界 `(?<![\w/\-])` 保证不会从半截路径开始匹配；`\.?` 放行 `.trellis/...` 这类
/// 以点开头的目录，`(?:\.{1,2}/)*` 放行 `./` 与 `../`。
final _anchorRef = RegExp(
  r'(?<![\w/\-])((?:\.{1,2}/)*\.?'
  r'[A-Za-z0-9_][A-Za-z0-9_.\-/]*\.md[cx]?)'
  r'`?\)?「([^「」]+)」',
);

/// 标题行：`#` 到 `######`（允许前导缩进），标题文本去掉行尾的 `#`。
final _heading = RegExp(r'^\s{0,3}#{1,6}\s+(.+?)\s*#*\s*$');

/// 一份文档里的全部章节引用。
///
/// dart 只看 `//` 注释行（字符串里的同名片段不是引用，测试 fixture 里就有）；
/// markdown 走 [visitProseLines] 跳过围栏与行内代码。
List<({int line, String path, String keyword})> refsIn(
  String docPath,
  String content,
) {
  final refs = <({int line, String path, String keyword})>[];

  void collect(int lineNumber, String text) {
    for (final match in _anchorRef.allMatches(text)) {
      refs.add((
        line: lineNumber,
        path: match.group(1)!,
        keyword: match.group(2)!.trim(),
      ));
    }
  }

  if (docPath.endsWith('.dart')) {
    final lines = content.split('\n');
    for (var index = 0; index < lines.length; index++) {
      if (!lines[index].trimLeft().startsWith('//')) continue;
      collect(index + 1, lines[index]);
    }
  } else {
    visitProseLines(content, collect, stripCode: false);
  }

  return refs;
}

/// [content] 的全部标题文本（围栏代码块里的 `#` 是代码注释，不算标题）。
List<String> headingsOf(String content) {
  final headings = <String>[];
  visitProseLines(content, (_, line) {
    final match = _heading.firstMatch(line);
    if (match != null) headings.add(match.group(1)!);
  }, stripCode: false);
  return headings;
}

/// [ref] 的候选仓库相对路径，按「引用所在目录 / spec 根 / 仓库根」依次尝试。
///
/// 三种写法都真实存在：markdown 链接的相对路径、dart 注释的 spec 相对路径
/// （`data/x.md`）、md 里的仓库相对路径（`.trellis/spec/x.md`）。
List<String> _candidatesOf(String docPath, String ref) => <String>{
  resolveFrom(docPath, ref),
  resolveFrom('.trellis/spec/', ref),
  resolveFrom('', ref),
}.toList();

/// 逐文档检查，返回可疑引用。纯函数：文件系统由 [exists] / [readFile] 注入。
List<String> findDocAnchorViolations({
  required List<String> docs,
  required bool Function(String) exists,
  required String Function(String) readFile,
}) {
  final violations = <String>[];
  final headings = <String, List<String>>{};

  for (final docPath in docs) {
    if (!exists(docPath)) {
      violations.add('$docPath  文件不存在');
      continue;
    }

    for (final ref in refsIn(docPath, readFile(docPath))) {
      final target = _existingTarget(docPath, ref.path, exists);
      if (target == null) {
        violations.add(
          '$docPath:${ref.line}  引用 `${ref.path}「${ref.keyword}」`，但目标文件不存在',
        );
        continue;
      }

      final titles = headings.putIfAbsent(
        target,
        () => headingsOf(readFile(target)),
      );
      if (titles.any((title) => title.contains(ref.keyword))) continue;

      violations.add(
        '$docPath:${ref.line}  引用「${ref.keyword}」，但 $target 里没有标题包含它',
      );
    }
  }

  return violations;
}

/// 候选里第一个存在的路径；都不存在时返回 `null`。
String? _existingTarget(
  String docPath,
  String ref,
  bool Function(String) exists,
) {
  for (final candidate in _candidatesOf(docPath, ref)) {
    if (exists(candidate)) return candidate;
  }
  return null;
}

/// 退出码策略：默认 0（只报告），[strict] 且有发现时才 1 —— 不进 `just verify` 的依据。
int anchorExitCode(List<String> findings, {required bool strict}) =>
    strict && findings.isNotEmpty ? 1 : 0;

void main(List<String> args) {
  final strict = args.contains('--strict');
  final files = args.where((arg) => !arg.startsWith('--')).toList();
  final docs = files.isEmpty ? collectFiles() : files;

  final findings = findDocAnchorViolations(
    docs: docs,
    exists: (path) =>
        FileSystemEntity.typeSync(path) != FileSystemEntityType.notFound,
    readFile: (path) => File(path).readAsStringSync(),
  );

  if (findings.isEmpty) {
    stdout.writeln('✅ 章节关键词引用均能对上（${docs.length} 个文件）');
  } else {
    stdout.writeln('⚠️  发现 ${findings.length} 处可疑引用（只报告，不拦提交）：');
    for (final finding in findings) {
      stdout.writeln('  • $finding');
    }
  }

  exitCode = anchorExitCode(findings, strict: strict);
}
