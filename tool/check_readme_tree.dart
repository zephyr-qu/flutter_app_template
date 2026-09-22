// 文档里的目录树 vs 实际 `lib/` 的一致性检查。
//
// ```bash
// dart run tool/check_readme_tree.dart                # 检查下面 targets 里的全部文档
// dart run tool/check_readme_tree.dart README.md      # 只检查指定文档
// ```
//
// 为什么要它：目录树是**结构性快照**。加删文件时它不会自己更新，而 markdown
// 链接检查管不到它 —— 树里的路径是纯文本，不是链接，编辑器与 Git 都不会报错。
// 结果是文档写着 `lib/core/routing/`（早已搬走）、漏着 `run_catching.dart`
// 却一直没人发现。
//
// 两条规则：
//   1. 树里列出的每个路径都必须真实存在 —— 防「文件已删、树里还留着」
//   2. 树里**已展开**的目录，其实际内容（生成物除外）必须全部列出
//      —— 防「加了文件、树里没写」
//
// 「已展开」= 该目录下面还有缩进更深的条目。只写到目录名、不展开子项的
// （如 `features/article/`）视为刻意省略，不检查其内容。
//
// 规则见 `.trellis/spec/guides/comment-guidelines.md` 的「快照式内容要单独标注」。

import 'dart:io';

import 'check_boundaries.dart' show isGeneratedPath;

/// 要检查的「文档 → 目录树根」对。
///
/// 用「对」的列表而不是 doc → root 的映射：一个文档里可以有多棵树
/// （README 同时画了 `lib/` 与 `packages/app_core/`）。
const targets = <(String, String)>[
  ('README.md', 'lib'),
  // 根取 `lib/` 而不是 `packages/app_core`：后者的直接子项里有 .dart_tool / build /
  // coverage / pubspec.lock 这些产物，树里列出它们只会变成噪音。
  ('README.md', 'packages/app_core/lib'),
  ('.trellis/spec/frontend/directory-structure.md', 'lib'),
];

/// 树里的占位写法（`{feature}/`、`*.dart`），没有对应的真实路径。
final _placeholder = RegExp('[{*]');

/// 树里的一行条目。
class TreeEntry {
  const new({
    required this.path,
    required this.isDir,
    required this.depth,
    required this.line,
  });

  /// 相对树根的路径，`/` 分隔（如 `core/base/result.dart`）。
  final String path;

  final bool isDir;

  /// 缩进层级，根下的条目为 0。
  final int depth;

  /// 该条目在文档里的行号（1 起）。
  final int line;

  /// 文档里原本的写法（目录带尾 `/`）。
  String get label => isDir ? '$path/' : path;

  @override
  String toString() => label;
}

/// [parseTree] 解析单行得到的中间结果 —— `path` 还没拼上父目录。
class _TreeLine {
  const new({
    required this.path,
    required this.isDir,
    required this.depth,
    required this.line,
  });

  final String path;
  final bool isDir;
  final int depth;
  final int line;
}

/// 从 markdown 里抽出以 [root] 为根的目录树。
///
/// 只认 ``` 围栏代码块，且块的**第一行非空内容**必须正好是 [root] ——
/// 这类文档里通常还有一堆示例代码块，靠这个把它们排除掉。
///
/// 拆成纯函数是为了能用普通 `test()` 覆盖，不必真的去读文档。
List<TreeEntry> parseTree(String markdown, String root) {
  final entries = <TreeEntry>[];
  final stack = <String>[];
  final accepted = <String>{root, '$root/'};

  var inFence = false;
  var firstContentLineSeen = false;
  var isTree = false;

  final lines = markdown.split('\n');
  for (var index = 0; index < lines.length; index++) {
    final raw = lines[index];
    final trimmed = raw.trim();

    if (trimmed.startsWith('```')) {
      inFence = !inFence;
      firstContentLineSeen = false;
      isTree = false;
      stack.clear();
      continue;
    }
    if (!inFence) continue;

    if (!firstContentLineSeen) {
      if (trimmed.isEmpty) continue;
      firstContentLineSeen = true;
      isTree = accepted.contains(trimmed);
      continue;
    }
    if (!isTree) continue;

    final parsed = _parseLine(raw, index + 1);
    if (parsed == null) continue;

    // 按深度截断栈，再拼出完整路径
    _truncate(stack, parsed.depth);
    final path = [...stack, parsed.path].join('/');
    entries.add(
      TreeEntry(
        path: path,
        isDir: parsed.isDir,
        depth: parsed.depth,
        line: parsed.line,
      ),
    );
    if (parsed.isDir) {
      _truncate(stack, parsed.depth);
      stack.add(parsed.path);
    }
  }

  return entries;
}

/// 解析树里的一行；不是条目的行（空行、只有 `│` 的连接线）返回 `null`。
_TreeLine? _parseLine(String raw, int lineNumber) {
  // 树里的 `#` 一律是注释起点（路径里不会出现）
  final hash = raw.indexOf('#');
  final body = hash >= 0 ? raw.substring(0, hash) : raw;
  if (body.trim().isEmpty) return null;

  // `├` / `└` 的列号决定层级：每 4 列（`│   ` 或 `    `）一层
  final connector = body.indexOf(RegExp('[├└]'));
  if (connector < 0) return null;

  // 跳过连接符本身：`├── `
  final name = body.substring(connector + 4).trim();
  if (name.isEmpty) return null;

  final isDir = name.endsWith('/');
  return _TreeLine(
    path: isDir ? name.substring(0, name.length - 1) : name,
    isDir: isDir,
    depth: connector ~/ 4,
    line: lineNumber,
  );
}

void _truncate(List<String> stack, int depth) {
  if (stack.length > depth) stack.removeRange(depth, stack.length);
}

/// 比对树与实际内容，返回违规描述。纯函数：文件系统由 [exists] / [children] 注入。
///
/// [children] 返回某目录下的**直接**子项名（文件与目录混合）；目录不存在返回空。
/// 生成物由本函数自行过滤 —— 它们不要求在树里列出。
List<String> findTreeViolations({
  required String docPath,
  required List<TreeEntry> entries,
  required bool Function(String path) exists,
  required List<String> Function(String dir) children,
}) {
  final violations = <String>[];

  // 规则 1：树里列出的路径必须存在
  for (final entry in entries) {
    if (_placeholder.hasMatch(entry.path)) continue;
    if (!exists(entry.path)) {
      violations.add('$docPath:${entry.line}  树里列了 `$entry`，但实际不存在');
    }
  }

  // 规则 2：已展开的目录，实际内容必须全部列出
  final listed = {for (final entry in entries) entry.path};
  final expanded = <String>{''}; // 根目录总是展开的
  for (final entry in entries) {
    if (!entry.isDir) continue;
    final children = entries.where(
      (other) =>
          other.depth == entry.depth + 1 && _isUnder(other.path, entry.path),
    );
    if (children.isEmpty) continue; // 只写目录名、刻意不展开
    // 用模板占位符展开的目录（如 `features/{feature}/`）没法逐一比对
    if (children.any((child) => _placeholder.hasMatch(child.path))) continue;
    expanded.add(entry.path);
  }

  for (final dir in expanded) {
    final line = dir.isEmpty
        ? 1
        : entries.firstWhere((entry) => entry.path == dir).line;
    for (final name in children(dir)) {
      final path = dir.isEmpty ? name : '$dir/$name';
      // 生成物（`*.g.dart`、`app_localizations*`…）不要求在树里列出
      if (isGeneratedPath('lib/$path')) continue;
      if (listed.contains(path)) continue;
      final scope = dir.isEmpty ? '根目录' : '`$dir/`';
      violations.add('$docPath:$line  $scope 已展开，但漏了 `$path`');
    }
  }

  return violations;
}

bool _isUnder(String path, String dir) =>
    dir.isEmpty || path.startsWith('$dir/');

void main(List<String> args) {
  final selected = args.isEmpty
      ? targets
      : targets.where((target) => args.contains(target.$1)).toList();
  final violations = <String>[];

  for (final (docPath, root) in selected) {
    final file = File(docPath);
    if (!file.existsSync()) {
      violations.add('$docPath  文档不存在');
      continue;
    }

    final entries = parseTree(file.readAsStringSync(), root);
    if (entries.isEmpty) {
      violations.add('$docPath  没找到以 `$root` 为根的目录树（检查围栏与首行）');
      continue;
    }

    violations.addAll(
      findTreeViolations(
        docPath: docPath,
        entries: entries,
        exists: (path) =>
            FileSystemEntity.typeSync('$root/$path') !=
            FileSystemEntityType.notFound,
        children: (dir) => _childNames(dir.isEmpty ? root : '$root/$dir'),
      ),
    );
  }

  if (violations.isEmpty) {
    stdout.writeln('✅ 目录树与实际内容一致（${selected.length} 棵）');
    return;
  }

  stderr.writeln('❌ 目录树与实际不符 ${violations.length} 处：');
  for (final violation in violations) {
    stderr.writeln('  • $violation');
  }
  exitCode = 1;
}

List<String> _childNames(String dir) {
  final directory = Directory(dir);
  if (!directory.existsSync()) return const [];
  return directory
      .listSync()
      .map((entity) => entity.uri.pathSegments.where((s) => s.isNotEmpty).last)
      .toList();
}
