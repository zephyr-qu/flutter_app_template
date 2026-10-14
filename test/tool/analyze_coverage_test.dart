import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// 为什么有这个测试：`just analyze` 的扫描面由根 justfile 里两条
// `list_dart_files.dart` 调用的 root 列表决定。root 漏掉一个顶层目录、或被改名 /
// 删掉时 analyze **不报错**：`git ls-files` 对不存在的路径返回空、退出码 0，
// 门禁只是少扫一批文件，依旧全绿。这个测试把两条断言钉成会拦提交的门：
//   R2 每个含 Dart 源码的顶层目录都被某个 root 覆盖（或在排除名单里）
//   R3 每个声明的 root 各自都列得到 .dart 文件
// 不新增工具 / recipe 的理由见 .trellis/spec/cross-cutting.md「架构边界与代码形态」。

/// 显式排除在扫描面之外的顶层目录（不是「隐藏目录」规则，而是本仓库自己的取舍）。
///
/// `.agents/` —— vendored 第三方 skill 的示例代码
/// （`dart-use-path-package/examples/*.dart`）：不是本仓库源码，改了也会被
/// 下次 vendoring 覆盖。它当前已被 [topLevelDirsWithDart] 的「隐藏目录」规则跳过，
/// 仍在这里显式留名，是为了让「为什么它不在扫描面」在断言处就能被 review 读到。
const excludedTopLevelDirs = <String>{'.agents'};

/// 反引号命令替换里的 `dart run tool/list_dart_files.dart <root>...`。
final _listDartFilesInvocation = RegExp(
  r'`[^`]*list_dart_files\.dart\s+([^`]*)`',
);

void main() {
  group('topLevelDirsWithDart', () {
    test('取顶层目录、去重排序', () {
      expect(
        topLevelDirsWithDart([
          'test/tool/a_test.dart',
          'lib/main.dart',
          'lib/a.dart',
          'tool/x.dart',
        ]),
        ['lib', 'test', 'tool'],
      );
    });

    test('跳过 `.` 开头的隐藏目录', () {
      expect(
        topLevelDirsWithDart([
          '.agents/skills/x.dart',
          '.dart_tool/y.dart',
          'lib/z.dart',
        ]),
        ['lib'],
      );
    });

    test('根目录下的单个 .dart 文件不产生目录', () {
      expect(topLevelDirsWithDart(['main.dart']), isEmpty);
    });

    test('空输入 → 空结果', () {
      expect(topLevelDirsWithDart(const []), isEmpty);
    });
  });

  group('uncoveredDirs', () {
    test('被 root 覆盖的目录不报', () {
      expect(
        uncoveredDirs(['lib', 'test'], {'lib', 'test'}, const {}),
        isEmpty,
      );
    });

    test('root 是上层目录时也覆盖（root `lib` 覆盖 `lib/features`）', () {
      expect(uncoveredDirs(['lib/features'], {'lib'}, const {}), isEmpty);
    });

    test('root 比目录更深不算覆盖（`lib/main.dart` 会漏扫）', () {
      expect(uncoveredDirs(['lib'], {'lib/features'}, const {}), ['lib']);
    });

    test('点名未被覆盖的目录', () {
      expect(
        uncoveredDirs(['example', 'lib', 'test'], {'lib', 'test'}, const {}),
        ['example'],
      );
    });

    test('排除名单里的目录不报，且容忍结尾斜杠', () {
      expect(uncoveredDirs(['.agents', 'lib'], {'lib'}, {'.agents/'}), isEmpty);
    });

    test('空输入 → 空结果', () {
      expect(uncoveredDirs(const [], const {}, const {}), isEmpty);
    });
  });

  group('parseAnalyzeRoots', () {
    test('合并去重所有 list_dart_files 调用的参数', () {
      const justfile =
          'app_files := `dart run tool/list_dart_files.dart lib test`\n'
          'tool_files := `dart run tool/list_dart_files.dart tool packages`\n';

      expect(parseAnalyzeRoots(justfile), ['lib', 'packages', 'test', 'tool']);
    });

    test('注释行里的同名命令不算', () {
      const justfile =
          '# 例：`dart run tool/list_dart_files.dart example`\n'
          'app_files := `dart run tool/list_dart_files.dart lib`\n';

      expect(parseAnalyzeRoots(justfile), ['lib']);
    });

    test('解析不到 → 空列表（调用方负责 fail，不静默通过）', () {
      expect(parseAnalyzeRoots('verify: analyze test\n'), isEmpty);
    });
  });

  group('仓库现状（读真实 justfile 与真实文件清单）', () {
    final roots = parseAnalyzeRoots(File('justfile').readAsStringSync());

    test('R2：每个含 Dart 源码的顶层目录都被 analyze root 覆盖（或在排除名单里）', () {
      expect(
        roots,
        isNotEmpty,
        reason:
            '没能从根 justfile 解析出 analyze roots —— 解析正则与 justfile 的写法脱节了；\n'
            '不要让它退化成「无 root」而静默通过',
      );

      final dirs = topLevelDirsWithDart(_analyzeDartFiles(const []));
      final uncovered = uncoveredDirs(
        dirs,
        roots.toSet(),
        excludedTopLevelDirs,
      );

      expect(
        uncovered,
        isEmpty,
        reason:
            '这些顶层目录含 Dart 源码，却不在 analyze 的 roots 里：'
            '${uncovered.join('、')}\n'
            '`dart analyze` 不会因为漏掉一个目录而报错，只会少扫它 —— '
            '门禁绿得毫无差别。请二选一：\n'
            '  1) 把目录名加进根 justfile 的 app_files / tool_files；\n'
            '  2) 若它本就不该扫描（vendored 第三方 / 生成物），\n'
            '写进本文件的 excludedTopLevelDirs 并说明理由。',
      );
    });

    test('R3：每个 analyze root 各自都列得到 .dart 文件', () {
      expect(
        roots,
        isNotEmpty,
        reason: '没能从根 justfile 解析出 analyze roots —— 见 R2 的说明',
      );

      for (final root in roots) {
        expect(
          _analyzeDartFiles([root]),
          isNotEmpty,
          reason:
              'root `$root` 产出 0 个 .dart 文件 —— 它可能已被改名 / 删除，\n'
              '或 justfile 里的名字写错了。`dart analyze` 对不存在的路径不报错，\n'
              '只会静默少扫（该 root 的文件全部漏出扫描面）。',
        );
      }
    });
  });
}

/// 取 [paths]（仓库相对路径）里出现过的顶层目录，去重排序。
///
/// 跳过 `.` 开头的隐藏目录 —— `.dart_tool` / `.trellis` / `.agents` / `.pi`
/// 都不是本仓库的 analyze 扫描面。根目录下的单个 `.dart` 文件不产生目录，
/// R2 只管顶层目录，不管它。
List<String> topLevelDirsWithDart(Iterable<String> paths) {
  final dirs = <String>{};

  for (final path in paths) {
    final slash = path.indexOf('/');
    if (slash <= 0) continue;
    final top = path.substring(0, slash);
    if (top.startsWith('.')) continue;
    dirs.add(top);
  }

  return dirs.toList()..sort();
}

/// [dirs] 里既不被任一 [roots] 覆盖、也不在 [excluded] 里的目录，排序返回。
///
/// 「被 root 覆盖」= 目录就是该 root，或在该 root 之下（`lib` 覆盖 `lib/features`）。
/// 反过来不成立：root 比目录更深（`lib/features`）不算覆盖 `lib` ——
/// `lib/main.dart` 并不在扫描面内，正是要拦下的形态。
///
/// [excluded] 与 [roots] 都容忍结尾斜杠，比较前先归一化。
List<String> uncoveredDirs(
  Iterable<String> dirs,
  Set<String> roots,
  Set<String> excluded,
) {
  final normalizedRoots = roots.map(_normalizePath).toList();
  final normalizedExcluded = excluded.map(_normalizePath).toSet();

  final uncovered = <String>{};
  for (final raw in dirs) {
    final dir = _normalizePath(raw);
    if (dir.isEmpty || normalizedExcluded.contains(dir)) continue;

    final covered = normalizedRoots.any(
      (root) => dir == root || dir.startsWith('$root/'),
    );
    if (!covered) uncovered.add(dir);
  }

  return uncovered.toList()..sort();
}

/// 从根 justfile 的文本里解析所有 `list_dart_files.dart <root>...` 调用的参数，
/// 去重排序 —— analyze 的扫描面**唯一真相是 justfile**，这里不抄第二份 root 列表。
///
/// 注释行（`#` 开头）不参与解析。解析不到时返回空列表：调用方必须显式 fail，
/// 不要让它退化成「无 root」而静默通过。
List<String> parseAnalyzeRoots(String justfile) {
  final roots = <String>{};

  for (final line in const LineSplitter().convert(justfile)) {
    if (line.trimLeft().startsWith('#')) continue;
    for (final match in _listDartFilesInvocation.allMatches(line)) {
      roots.addAll(
        match.group(1)!.split(RegExp(r'\s+')).where((root) => root.isNotEmpty),
      );
    }
  }

  return roots.toList()..sort();
}

/// 跑一次 `git ls-files` 并挑出参与 analyze 的 Dart 源码（[pathspec] 为空则全仓库）。
///
/// 与 `tool/list_dart_files.dart` 同一命令：测试看到的文件清单必须与门禁看到的一致，
/// 所以这里不自己遍历目录。只要 `.dart`、磁盘上存在（index 里可能还留着已删文件）、
/// 且不是生成物（生成物已被 `.gitignore` 排除，`--exclude-standard` 天然不带它们）。
List<String> _analyzeDartFiles(List<String> pathspec) {
  final result = Process.runSync(
    'git',
    [
      'ls-files',
      '--cached',
      '--others',
      '--exclude-standard',
      if (pathspec.isNotEmpty) ...['--', ...pathspec],
    ],
    stdoutEncoding: utf8,
    stderrEncoding: utf8,
  );

  expect(result.exitCode, 0, reason: 'git ls-files 失败：${result.stderr}');

  return LineSplitter.split(result.stdout as String)
      .map((path) => path.replaceAll(r'\', '/'))
      .where((path) => path.endsWith('.dart'))
      .where((path) => File(path).existsSync())
      .toList();
}

/// 去掉结尾斜杠、统一成 `/` 分隔。
String _normalizePath(String path) {
  var normalized = path.replaceAll(r'\', '/');
  while (normalized.endsWith('/')) {
    normalized = normalized.substring(0, normalized.length - 1);
  }
  return normalized;
}
