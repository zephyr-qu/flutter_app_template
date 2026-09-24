// 一次跑完「改完必跑」的整套门禁。
//
// ```bash
// dart run tool/verify.dart          # 全套 9 项，首个失败即停
// ```
//
// 三条约定：
//
// 1. **一条命令**。原先要记 9 条，漏一条就是漏一道门禁；要单跑某一项时，
//    下面 `steps` 里就是对应的原始命令。
// 2. **首个失败即停**。修好再往下跑，不必等整块跑完才发现第一条就红了。
// 3. **口径与阈值不在这里定义**：每条都原样转发给对应的脚本 / CLI，本文件只管
//    「顺序」与「停下来」，所以不存在第二个真相来源。子进程的输出原样透传
//    （`ProcessStartMode.inheritStdio`），看到的与逐条手跑一致。
//
// 4 道脚本门禁是**在同一个进程里**调的（它们本来就是「纯函数 + 薄 main」，见各自的
// `run()`），因此省掉 3 次 `dart run` 的 VM 启动与 sqlite3 build hook。
//
// **别指望它快多少**：2026-09-24 本机（Windows，缓存已热）实测，9 条独立命令 44.3s
// → verify 39.1s；而那 4 道脚本门禁单跑合计才 11.8s，整块的大头是 `flutter test`
// 与两次 analyze。它省的是「记住 9 条命令」与「等整块跑完」，不是时间。
//
// 各道门禁的语义、阈值与理由见 `.trellis/spec/cross-cutting.md`。

import 'dart:io';

import 'check_boundaries.dart' as boundaries;
import 'check_conventions.dart' as conventions;
import 'check_coverage.dart' as coverage;
import 'check_readme_tree.dart' as readme_tree;

Future<void> main() async => exitCode = await run();

/// 依次跑完全部门禁，返回退出码（0 = 全绿）。
///
/// 拆出 `run()` 是为了有个可被调用的入口，而不是把逻辑埋在 `main` 里。
Future<int> run() async {
  // 顺序 = AGENTS.md「改完必跑」的顺序：先便宜的后贵的。
  // 覆盖率门禁排最后，因为它依赖 `flutter test --coverage` 产出的 lcov。
  final steps = <(String, Future<int> Function())>[
    (
      'dart format --set-exit-if-changed lib test tool',
      () => _exec('dart', [
        'format',
        '--output=none',
        '--set-exit-if-changed',
        'lib',
        'test',
        'tool',
      ]),
    ),
    ('架构边界（check_boundaries）', () async => boundaries.run(const [])),
    ('形态约定（check_conventions）', () async => conventions.run(const [])),
    ('目录树一致性（check_readme_tree）', () async => readme_tree.run(const [])),
    (
      '依赖声明（dependency_validator）',
      () => _exec('dart', ['run', 'dependency_validator']),
    ),
    (
      'flutter analyze lib/ test/',
      () => _exec('flutter', ['analyze', 'lib/', 'test/']),
    ),
    ('dart analyze tool/', () => _exec('dart', ['analyze', 'tool/'])),
    ('flutter test --coverage', () => _exec('flutter', ['test', '--coverage'])),
    (
      '覆盖率门禁（check_coverage --src=lib）',
      () async => coverage.run(const ['coverage/lcov.info', '--src=lib']),
    ),
  ];

  final ran = <String>[];

  for (final (label, body) in steps) {
    stdout.writeln('\n▶ $label');
    final code = await body();
    if (code == 0) {
      ran.add(label);
      continue;
    }

    stderr
      ..writeln('\n❌ 门禁未通过：$label（退出码 $code）')
      ..writeln('   已通过 ${ran.length}/${steps.length}：');
    for (final step in ran) {
      stderr.writeln('     ✅ $step');
    }
    stderr.writeln('   ⛔ 后面的步骤没有跑 —— 修好这一条再重跑。');
    return 1;
  }

  stdout.writeln('\n✅ 全套门禁通过（${steps.length} 项）');
  return 0;
}

/// 跑一个子进程，输出原样透传，返回退出码。
///
/// Windows 上 `flutter` 只有 `flutter.bat`（CreateProcess 起不来 `.bat`），必须经
/// shell；`dart` 有真正的 `dart.exe`，不套 shell（少一层引号解析）。
Future<int> _exec(String executable, List<String> args) async {
  final process = await Process.start(
    executable,
    args,
    mode: ProcessStartMode.inheritStdio,
    runInShell: Platform.isWindows && executable == 'flutter',
  );
  return await process.exitCode;
}
