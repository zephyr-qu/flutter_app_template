// 覆盖率门禁。
//
// ```bash
// flutter test --coverage                 # 生成 coverage/lcov.info
// dart run tool/check_coverage.dart       # 默认阈值 80%
// dart run tool/check_coverage.dart --min=85
// dart run tool/check_coverage.dart path/to/lcov.info
//
// # 带差集检查（--src 指定扫描根）
// dart run tool/check_coverage.dart coverage/lcov.info --src=lib
// ```
//
// 传多份 lcov 时**逐份独立**校验（不合并）：路径都是相对各自包根的 `lib/...`，
// 合并会把命名空间搅在一起。本分支已单包化，通常只传一份。
//
// 只统计**手写**代码：`*.g.dart` / `*.freezed.dart` / `*.gr.dart` 这些生成物的
// 行数不是人能守的，算进阈值只会稀释门禁。生成文件的判定复用
// `tool/check_boundaries.dart` 的 [isGeneratedPath]，避免两处定义漂移。
//
// ── 差集检查（--src）──
//
// 覆盖率的分母历来是「lcov 里出现的文件」，于是**一个从未被任何测试加载的文件
// 不出现、也就不进分母**：新增一个完全没测的大文件不会让阈值下降。所以这里补上
// 差集：拿扫描根下的手写文件清单，减去该 lcov 的 `SF:` 集合。
//
// 差集里的文件按 `0 命中 / 非空行数` **计入分母**（不是只报告）：没有豁免时门禁
// 自动变严，不必等谁记得加规则。行数是代理值——lcov 里根本没有这些文件，拿不到
// 精确的可执行行数，用非空行数刻意从严。
//
// 唯一的逃生口是 [loadingExemptions]：只放**结构上不可能被加载**的文件，且必须
// 写理由。过期豁免（已进分母）只打 warning，不拦提交。
//
// 阈值与理由见 `.trellis/spec/cross-cutting.md`。

import 'dart:io';

import 'check_boundaries.dart' show dartFiles, isGeneratedPath, normalizePath;

/// 默认行覆盖率阈值（百分点）。
const double defaultMinCoverage = 80;

/// 浮点比较容差：84.999999… 不该被判失败。
const double _epsilon = 1e-9;

/// 一个文件在 lcov 里的行覆盖情况。
class FileCoverage {
  const new({required this.path, required this.hit, required this.found});

  /// `lib/xxx/yyy.dart` 形式（分隔符统一成 `/`）。
  final String path;

  /// 命中的行数（lcov 的 `LH`）。
  final int hit;

  /// 可执行的总行数（lcov 的 `LF`）。
  final int found;

  double get ratio => found == 0 ? 1 : hit / found;

  @override
  String toString() =>
      '${(ratio * 100).toStringAsFixed(1)}%  $hit/$found  $path';
}

/// 解析 lcov（`SF:` / `LF:` / `LH:` / `end_of_record`）。
///
/// 拆成纯函数是为了能用普通 `test()` 覆盖，不必真的跑一遍
/// `flutter test --coverage`。
List<FileCoverage> parseLcov(String content) {
  final files = <FileCoverage>[];
  var path = '';
  var found = 0;
  var hit = 0;

  for (final raw in content.split('\n')) {
    final line = raw.trim();
    if (line.startsWith('SF:')) {
      path = line.substring('SF:'.length).replaceAll(r'\', '/');
      found = 0;
      hit = 0;
    } else if (line.startsWith('LF:')) {
      found = int.tryParse(line.substring('LF:'.length)) ?? 0;
    } else if (line.startsWith('LH:')) {
      hit = int.tryParse(line.substring('LH:'.length)) ?? 0;
    } else if (line == 'end_of_record' && path.isNotEmpty) {
      files.add(FileCoverage(path: path, hit: hit, found: found));
      path = '';
    }
  }

  return files;
}

/// 手写代码（剔除生成文件）的覆盖数据。
List<FileCoverage> handwrittenOnly(Iterable<FileCoverage> files) =>
    files.where((file) => !isGeneratedPath(file.path)).toList();

/// 结构上**不可能**出现在 lcov 里的手写文件 → 理由。
///
/// 差集里的其它文件一律按 `0 / 非空行数` 计入分母；只有这些能免。两条纪律：
///
/// 1. 理由必须写清楚「为什么它不该被加载」，而不是「暂时来不及测」
/// 2. 条目变多就是信号——多半是有人在拿豁免代替测试
///
/// 抽象声明（`abstract class` / Retrofit 接口 / redirecting factory）与只被
/// `integration_test` 加载的入口是典型情况：它们没有可执行行，或 `flutter test
/// --coverage` 根本不会执行到。
const Map<String, String> loadingExemptions = <String, String>{
  // ── 根工程：入口与纯声明 ──
  'lib/main.dart': '一行转发到 bootstrap()，只被 integration_test 执行',
  'lib/bootstrap.dart': '要真实 .env + runApp，只在真机 / integration_test 里跑',
  'lib/features/sample/data/sample_api.dart':
      'Retrofit 抽象接口 + redirecting factory，没有可执行行',
  'lib/features/sample/data/sample_repository.dart': '纯 abstract class，没有可执行行',
};

/// 该文件是否被这条 lcov 记录覆盖。
///
/// `SF:` 记录与扫描根路径的基准可能不同（前者相对包根、后者仓库相对），
/// 用边界感知的后缀匹配把两者对上，不需要额外传前缀。
bool coversPath(String repoPath, String sfPath) =>
    repoPath == sfPath || repoPath.endsWith('/$sfPath');

/// 扫描到、但没有任何测试加载过的文件（按仓库相对路径排序）。
///
/// [handwritten] 传扫描根下的手写文件（仓库相对路径，`/` 分隔），
/// [covered] 传该 lcov 的覆盖记录。
List<String> missingFrom({
  required Iterable<String> handwritten,
  required Iterable<FileCoverage> covered,
}) {
  final coveredPaths = covered.map((file) => file.path).toList();
  final missing = handwritten
      .where((path) => !coveredPaths.any((sfPath) => coversPath(path, sfPath)))
      .toList();
  return missing..sort();
}

/// 非空行数——未加载文件的分母代理。
///
/// lcov 里没有这些文件，精确的可执行行数拿不到；用非空行数刻意从严：
/// 注释与空行不算，但 `import` / `}` 这类不可执行行会算进去。
int nonBlankLines(String content) =>
    content.split('\n').where((line) => line.trim().isNotEmpty).length;

/// 把未加载文件按 0 命中并入统计。
///
/// [unloadedLines] 是「仓库相对路径 → 非空行数」，只有已剔除豁免的才该进来。
List<FileCoverage> withUnloaded({
  required Iterable<FileCoverage> files,
  required Map<String, int> unloadedLines,
}) => [
  ...files,
  for (final entry in unloadedLines.entries)
    FileCoverage(path: entry.key, hit: 0, found: entry.value),
];

/// 差集里要真正计入分母的部分：剔除 [loadingExemptions] 里的条目。
List<String> unexemptedFiles(
  Iterable<String> missing, {
  Map<String, String> exemptions = loadingExemptions,
}) => missing.where((path) => !exemptions.containsKey(path)).toList();

/// 过期豁免：挂在 [scanRoot] 下、但已经不再缺失的条目。
///
/// 留着它会让下一个人以为这里还有坑；而剔除与否都不影响数字，所以只提示、不拦提交。
List<String> staleExemptions({
  required Iterable<String> missing,
  required String scanRoot,
  Map<String, String> exemptions = loadingExemptions,
}) => [
  for (final path in exemptions.keys)
    if (_isUnder(path, scanRoot) && !missing.contains(path)) path,
];

/// 行覆盖率（百分点）。
///
/// 按行数加权，不是按文件数平均——一个 500 行的文件和一个 5 行的文件，
/// 权重必须不同。没有可统计的行时返回 100：没有代码就没有未覆盖的代码。
double lineCoverage(Iterable<FileCoverage> files) {
  var hit = 0;
  var found = 0;
  for (final file in files) {
    hit += file.hit;
    found += file.found;
  }
  return found == 0 ? 100 : hit * 100 / found;
}

/// 覆盖率最低的 [count] 个文件（门禁失败时用来定位）。
List<FileCoverage> lowestCovered(List<FileCoverage> files, int count) {
  final sorted = [...files]..sort((a, b) => a.ratio.compareTo(b.ratio));
  return sorted.take(count).toList();
}

void main(List<String> args) => exitCode = run(args);

/// 跑一遍检查，返回退出码（0 = 通过）。
///
/// 拆出来是为了让 `tool/verify.dart` 能在**同一个进程**里依次调四道脚本门禁。
/// 注意它**依赖 `coverage/lcov.info`**：调用方必须先跑过 `flutter test --coverage`。
int run(List<String> args) {
  if (args.contains('--help') || args.contains('-h')) {
    stdout.writeln(_usage);
    return 0;
  }

  final paths = args.where((arg) => !arg.startsWith('-')).toList();
  final inputs = paths.isEmpty ? const ['coverage/lcov.info'] : paths;
  final min = _minFrom(args) ?? defaultMinCoverage;
  final srcs = _srcsFrom(args);

  // 差集检查靠**按序配对**认扫描根，参数错位不会报错、只会静默算错分母——
  // 这是这里最坏的失败形态，所以宁可直接停下来
  if (srcs.length != inputs.length) {
    stderr
      ..writeln('❌ --src 个数（${srcs.length}）与 lcov 个数（${inputs.length}）不一致：')
      ..writeln('   --src 与位置参数按序配对，1 份 lcov 配 1 个扫描根；只想校验阈值就别传 --src。');
    return 1;
  }
  final emptySrc = srcs.indexWhere((src) => src.trim().isEmpty);
  if (emptySrc >= 0) {
    stderr.writeln('❌ --src= 后面是空的（第 ${emptySrc + 1} 个）');
    return 1;
  }

  var failed = false;

  // 逐份独立校验，**不合并**：两份 lcov 的路径都是相对各自包根的 `lib/...`，
  // 合并会让两个命名空间撞在一起。而且「每个包守自己的阈值」本来就比
  // 「用一个加权数字盖住两套代码」更有意义——包内的低覆盖不该被 lib/ 的高覆盖稀释。
  for (var index = 0; index < inputs.length; index++) {
    final input = inputs[index];
    final report = File(input);
    if (!report.existsSync()) {
      stderr.writeln('❌ 找不到 $input —— 先执行 `flutter test --coverage`');
      failed = true;
      continue;
    }

    var files = handwrittenOnly(parseLcov(report.readAsStringSync()));

    // 扫描根下的手写文件清单：与 handwrittenOnly 同一口径（都过 isGeneratedPath）
    final unloadedLines = <String, int>{};
    var stale = const <String>[];
    if (srcs.isNotEmpty) {
      final scanned = dartFiles(srcs[index])
          .map((file) => normalizePath(file.path));
      final missing = missingFrom(handwritten: scanned, covered: files);

      for (final path in unexemptedFiles(missing)) {
        unloadedLines[path] = nonBlankLines(File(path).readAsStringSync());
      }
      stale = staleExemptions(missing: missing, scanRoot: srcs[index]);

      files = withUnloaded(files: files, unloadedLines: unloadedLines);
    }

    final coverage = lineCoverage(files);

    stdout.writeln(
      '$input\n'
      '  覆盖率（手写代码，${files.length} 个文件）: '
      '${coverage.toStringAsFixed(1)}%'
      '   阈值 ${min.toStringAsFixed(1)}%',
    );

    if (unloadedLines.isNotEmpty) {
      stdout.writeln('  未加载 ${unloadedLines.length} 个手写文件（按 0 命中 / 非空行数计入分母）：');
      for (final entry in unloadedLines.entries) {
        stdout.writeln('    • ${entry.key}  (0/${entry.value})');
      }
    }
    if (stale.isNotEmpty) {
      stderr.writeln(
        '  ⚠️ 过期豁免（已进分母，可从 loadingExemptions 删掉）：${stale.join('、')}',
      );
    }

    if (coverage + _epsilon >= min) {
      stdout.writeln('  ✅ 达标');
      continue;
    }

    stderr.writeln('  ❌ 低于阈值，最低的 5 个文件：');
    for (final file in lowestCovered(files, 5)) {
      stderr.writeln('    • $file');
    }
    failed = true;
  }

  return failed ? 1 : 0;
}

double? _minFrom(List<String> args) {
  for (final arg in args) {
    if (arg.startsWith('--min=')) {
      return double.tryParse(arg.substring('--min='.length));
    }
  }
  return null;
}

/// 可重复的 `--src=<扫描根>`，与位置参数里的 lcov **按序配对**。
List<String> _srcsFrom(List<String> args) => [
  for (final arg in args)
    if (arg.startsWith('--src=')) arg.substring('--src='.length),
];

bool _isUnder(String path, String prefix) =>
    path == prefix ||
    path.startsWith(prefix.endsWith('/') ? prefix : '$prefix/');

const String _usage = '''
用法：dart run tool/check_coverage.dart [lcov 路径 ...] [--src=扫描根 ...] [--min=80]

先生成覆盖率数据：
  flutter test --coverage                          # → coverage/lcov.info

默认读取 coverage/lcov.info，默认阈值 80%（手写代码口径，剔除生成文件）。

--src 指定扫描根，开启差集检查：扫描根下没有被这份 lcov 覆盖的手写文件，
按「0 命中 / 非空行数」计入分母（结构上不可能被加载的见脚本里的 loadingExemptions）：

  dart run tool/check_coverage.dart coverage/lcov.info --src=lib
''';
