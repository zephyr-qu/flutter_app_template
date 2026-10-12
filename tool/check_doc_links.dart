// 文档与代码注释里的「路径引用」一致性检查。
//
// ```bash
// dart run tool/check_doc_links.dart                # 检查下面 targets 覆盖的全部文件
// dart run tool/check_doc_links.dart README.md      # 只检查指定文件
// ```
//
// 为什么要它：目录树门禁（`tool/check_readme_tree.dart`）只管树里的**纯文本路径**。
// markdown 链接与 dart 注释里的 spec 引用不在它视野里，于是目录改名或文件改名
// 会静默留下一堆断链 —— 编辑器不报，Git 不报，测试也不报。
//
// 两条规则：
//   A. markdown 行内链接 `[text](target)` 的相对目标必须存在（文件或目录）
//   B. dart 注释里的 spec 引用（`data/xxx.md`）必须指向真实文件
//
// 扫描面：根 `README.md` / `AGENTS.md`、`docs/**/*.md`、
// `.trellis/spec/**/*.md`、`.cursor/rules/*.mdc`、`lib/**/*.dart`、`test/**/*.dart`。
// 排除项与理由：
//   - `.trellis/tasks/**` —— 任务笔记：活动任务会引用**尚未创建**的目标路径，归档任务是历史
//   - `.pi/skills/**`、`.agents/skills/**` —— vendored 第三方文档，含作者本机的 `file://` 绝对链接
//   - `packages/**` —— 独立包，自带 README 的链接面向 pub 场景
//   - 生成物 —— 复用 `tool/generated_paths.dart`，里面的引用没法手工修
//
// 有意不做：
//   1. 不在本门禁里校验锚点与章节关键词。改章节名是本仓库的常规操作，误报会直接挡住提交；
//      这类引用交给 `tool/check_doc_anchors.dart` —— 只报告、不拦提交，并复用本文件的扫描面。
//   2. 不做自动修复（`--fix`），只报告。
//   3. 规则 B 宁可少报也不误报：只认 `(data|ui|guides)/<名>.md` 与裸
//      `cross-cutting.md`，且只看 `//` 注释行。普通文本与字符串里的同名片段不算引用。

import 'dart:io';

import 'generated_paths.dart' show isGeneratedPath;

/// 要扫描的根，逐个展开（`/**` 表示递归）。
const targets = <String>[
  'README.md',
  'AGENTS.md',
  'docs',
  '.trellis/spec',
  '.cursor/rules',
  'lib',
  'test',
];

/// 递归扫描时不要进入的目录（理由见文件头注释）。
const excludedDirs = <String>['.trellis/tasks', '.pi', '.agents', 'packages'];

/// 规则 B 认的 spec 引用：带层目录的规范文件，或跨层根下的 `cross-cutting.md`。
///
/// 前置边界 `(?<![\w/.-])` 是有意的：`.trellis/spec/data/x.md` 这类**带前缀**的写法
/// 不匹配（`comment-guidelines.md` 本来就禁止写 `.trellis/spec/` 前缀），宁可少报。
final _specRef = RegExp(
  r'(?<![\w/.-])((?:data|ui|guides)/[a-z0-9][a-z0-9._-]*\.md'
  r'|cross-cutting\.md)',
);

/// 围栏代码块的起止（``` 或 ~~~，允许缩进）。
final _fence = RegExp(r'^\s*(?:`{3,}|~{3,})');

/// 行内链接 `[text](target)`（含图片，目标同样必须是真实文件）。
final _inlineLink = RegExp(r'\[[^\[\]]*\]\(([^()\s]*)\)');

/// 带 scheme 的目标（`http:` / `https:` / `mailto:` / `file:` / `tel:`…），一律跳过。
final _hasScheme = RegExp('^[a-zA-Z][a-zA-Z0-9+.-]*:');

/// 规则 A：[docPath] 里的行内链接目标是否都存在。
///
/// 相对链接按 [docPath] 所在目录 resolve；`#锚点` 被剥掉（不校验锚点本身）。
List<String> _checkLinks(
  String docPath,
  String content,
  bool Function(String) exists,
) {
  final violations = <String>[];

  visitProseLines(content, (lineNumber, line) {
    for (final match in _inlineLink.allMatches(line)) {
      final target = match.group(1)!;
      if (target.isEmpty || _hasScheme.hasMatch(target)) continue;

      final path = _stripFragment(target);
      if (path.isEmpty) continue; // 纯锚点 `#section`
      if (path.contains('{') || path.contains('*')) continue; // 模板占位符

      final resolved = resolveFrom(docPath, path);
      if (!exists(resolved)) {
        violations.add(
          '$docPath:$lineNumber  链接目标不存在：`$target`（解析为 `$resolved`）',
        );
      }
    }
  });

  return violations;
}

/// 逐行遍历 [content] 的正文（行号从 1 起），把结果交给 [visit]：
///
/// - 跳过围栏代码块（``` / ~~~）内部的每一行，围栏行本身也不交出
/// - [stripCode] 为 true（默认）时再剜掉行内代码 —— 文档里写正则的例子才不会被当成链接
///
/// 两个门禁共用：`tool/check_doc_links.dart` 与 `tool/check_doc_anchors.dart`。
void visitProseLines(
  String content,
  void Function(int lineNumber, String line) visit, {
  bool stripCode = true,
}) {
  var inFence = false;
  final lines = content.split('\n');

  for (var index = 0; index < lines.length; index++) {
    final raw = lines[index];
    if (_fence.hasMatch(raw)) {
      inFence = !inFence;
      continue;
    }
    if (inFence) continue;
    visit(index + 1, stripCode ? _stripInlineCode(raw) : raw);
  }
}

/// 规则 B：dart 注释里引用的 spec 文件是否都存在。
List<String> _checkSpecRefs(
  String dartPath,
  String content,
  bool Function(String) exists,
) {
  final violations = <String>[];
  final lines = content.split('\n');

  for (var index = 0; index < lines.length; index++) {
    // 只看注释行 —— 字符串里的同名片段不是引用（测试 fixture 里就有）
    if (!lines[index].trimLeft().startsWith('//')) continue;
    for (final match in _specRef.allMatches(lines[index])) {
      final ref = match.group(1)!;
      final resolved = '.trellis/spec/$ref';
      if (!exists(resolved)) {
        violations.add(
          '$dartPath:${index + 1}  spec 引用不存在：`$ref`（解析为 `$resolved`）',
        );
      }
    }
  }

  return violations;
}

/// 剜掉行内代码，再找链接 —— 否则文档里写正则的例子会被当成链接
/// （实测误报：`['\"]([^'\"]+)['\"]` 里的 `](...)`）。
///
/// 先处理**成对的反引号**（CommonMark 的 code span：`N` 个反引号开启、`>= N` 个关闭），
/// 所以 `` `` `[x](y.md)` `` `` 这种双反引号包单反引号的写法也能整段剜掉。
/// 找不到关闭串时按原样保留：宁可少报，也不要把普通文本当代码删掉。
String _stripInlineCode(String line) {
  final buffer = StringBuffer();

  var index = 0;
  while (index < line.length) {
    if (line[index] != '`') {
      buffer.write(line[index++]);
      continue;
    }

    var ticks = 0;
    while (index + ticks < line.length && line[index + ticks] == '`') {
      ticks++;
    }
    final close = _findClosingTicks(line, index + ticks, ticks);
    if (close < 0) {
      buffer.write(line.substring(index, index + ticks));
      index += ticks;
      continue;
    }
    index = close + ticks;
  }

  return buffer.toString();
}

/// 找长度 >= [ticks] 的关闭反引号串，返回其起点；没有则返回 `-1`。
int _findClosingTicks(String line, int from, int ticks) {
  var index = from;
  while (index < line.length) {
    if (line[index] != '`') {
      index++;
      continue;
    }
    var run = 0;
    while (index + run < line.length && line[index + run] == '`') {
      run++;
    }
    if (run >= ticks) return index;
    index += run;
  }
  return -1;
}

/// 剥掉 `#锚点`（锚点本身不做校验，理由见文件头注释）。
String _stripFragment(String target) {
  final hash = target.indexOf('#');
  return (hash >= 0 ? target.substring(0, hash) : target).replaceAll(r'\', '/');
}

/// 把 [target] 按 [docPath] 所在目录 resolve 成仓库相对路径，并消掉 `.` / `..`。
///
/// [docPath] 以 `/` 结尾时就是「相对该目录」；传空串则是「相对仓库根」——
/// `tool/check_doc_anchors.dart` 用它把 spec 根与仓库根一并列进候选。
String resolveFrom(String docPath, String target) {
  final dir = docPath.contains('/')
      ? docPath.substring(0, docPath.lastIndexOf('/'))
      : '';
  final segments = <String>[];

  for (final part in '$dir/$target'.split('/')) {
    if (part.isEmpty || part == '.') continue;
    if (part == '..') {
      if (segments.isNotEmpty) segments.removeLast();
      continue;
    }
    segments.add(part);
  }

  return segments.join('/');
}

/// 逐文件检查，返回违规描述。纯函数：文件系统由 [exists] / [readFile] 注入。
///
/// [docs] 按后缀分派：`.md` / `.mdc` 走规则 A，`.dart` 走规则 B，其余跳过。
List<String> findDocLinkViolations({
  required List<String> docs,
  required bool Function(String) exists,
  required String Function(String) readFile,
}) {
  final violations = <String>[];

  for (final docPath in docs) {
    if (!exists(docPath)) {
      violations.add('$docPath  文件不存在');
      continue;
    }

    final content = readFile(docPath);
    if (docPath.endsWith('.dart')) {
      violations.addAll(_checkSpecRefs(docPath, content, exists));
    } else if (docPath.endsWith('.md') || docPath.endsWith('.mdc')) {
      violations.addAll(_checkLinks(docPath, content, exists));
    }
  }

  return violations;
}

void main(List<String> args) {
  final files = args.isEmpty ? collectFiles() : args;
  final violations = findDocLinkViolations(
    docs: files,
    exists: (path) =>
        FileSystemEntity.typeSync(path) != FileSystemEntityType.notFound,
    readFile: (path) => File(path).readAsStringSync(),
  );

  if (violations.isEmpty) {
    stdout.writeln('✅ 文档链接与 spec 引用均有效（${files.length} 个文件）');
    return;
  }

  stderr.writeln('❌ 发现断链 ${violations.length} 处：');
  for (final violation in violations) {
    stderr.writeln('  • $violation');
  }
  exitCode = 1;
}

/// 展开 [targets]，跳过 [excludedDirs] 与生成物。
///
/// 扫描面只有这一份：`tool/check_doc_anchors.dart` 直接调它，不要各自再枚举一遍。
List<String> collectFiles() {
  final files = <String>[];

  for (final target in targets) {
    final type = FileSystemEntity.typeSync(target);
    if (type == FileSystemEntityType.notFound) {
      stderr.writeln('⚠️  扫描面不存在，已跳过：$target');
      continue;
    }
    if (type == FileSystemEntityType.file) {
      files.add(target);
      continue;
    }

    for (final entity in Directory(target).listSync(recursive: true)) {
      if (entity is! File) continue;
      final path = entity.path.replaceAll(r'\', '/');
      if (excludedDirs.any((dir) => path.startsWith('$dir/'))) continue;
      if (isGeneratedPath(path)) continue;
      if (_isChecked(path)) files.add(path);
    }
  }

  return files..sort();
}

bool _isChecked(String path) =>
    path.endsWith('.md') || path.endsWith('.mdc') || path.endsWith('.dart');
