// 覆盖率门禁。
//
// ```bash
// flutter test --coverage                 # 生成 coverage/lcov.info
// dart run tool/check_coverage.dart       # 默认阈值 80%
// dart run tool/check_coverage.dart --min=85
// dart run tool/check_coverage.dart path/to/lcov.info
// dart run tool/check_coverage.dart coverage/lcov.info packages/app_core/coverage/lcov.info
// ```
//
// 传多份 lcov 时**逐份独立**校验（不合并）：两份的路径都是相对各自包根的
// `lib/...`，合并会把命名空间搅在一起；而且包内的低覆盖不该被 lib/ 稀释。
//
// 只统计**手写**代码：`*.g.dart` / `*.freezed.dart` / DI 注册 / l10n 生成文件的
// 行数不是人能守的，算进阈值只会稀释门禁。生成文件的判定复用
// `tool/check_boundaries.dart` 的 [isGeneratedPath]，避免两处定义漂移。
//
// 阈值与理由见 `.trellis/spec/frontend/quality-guidelines.md`。

import 'dart:io';

import 'check_boundaries.dart' show isGeneratedPath;

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

void main(List<String> args) {
  if (args.contains('--help') || args.contains('-h')) {
    stdout.writeln(_usage);
    return;
  }

  final paths = args.where((arg) => !arg.startsWith('-')).toList();
  final inputs = paths.isEmpty ? const ['coverage/lcov.info'] : paths;
  final min = _minFrom(args) ?? defaultMinCoverage;

  var failed = false;

  // 逐份独立校验，**不合并**：两份 lcov 的路径都是相对各自包根的 `lib/...`，
  // 合并会让两个命名空间撞在一起。而且「每个包守自己的阈值」本来就比
  // 「用一个加权数字盖住两套代码」更有意义——包内的低覆盖不该被 lib/ 的高覆盖稀释。
  for (final input in inputs) {
    final report = File(input);
    if (!report.existsSync()) {
      stderr.writeln('❌ 找不到 $input —— 先执行 `flutter test --coverage`');
      failed = true;
      continue;
    }

    final files = handwrittenOnly(parseLcov(report.readAsStringSync()));
    final coverage = lineCoverage(files);

    stdout.writeln(
      '$input\n'
      '  覆盖率（手写代码，${files.length} 个文件）: '
      '${coverage.toStringAsFixed(1)}%'
      '   阈值 ${min.toStringAsFixed(1)}%',
    );

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

  if (failed) exitCode = 1;
}

double? _minFrom(List<String> args) {
  for (final arg in args) {
    if (arg.startsWith('--min=')) {
      return double.tryParse(arg.substring('--min='.length));
    }
  }
  return null;
}

const String _usage = '''
用法：dart run tool/check_coverage.dart [lcov 路径 ...] [--min=80]

先生成覆盖率数据：
  flutter test --coverage                          # 根工程 → coverage/lcov.info
  (cd packages/app_core && flutter test --coverage) # 共享包 → 包内 coverage/lcov.info

默认读取 coverage/lcov.info，默认阈值 80%（手写代码口径，剔除生成文件）。
可传多份 lcov：每份**独立**校验，任一份不达标即失败。
''';
