import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// 为什么有这个测试（规则 1/2 的静默失效防线）：
// `no_upper_import_in_core` 与 `cross_feature_only_data` 靠 `paths.dart` 里
// 硬编码的 `selfPackagePrefix`（`package:my_app/`）把 `package:` URI 解析成
// 仓库相对路径。pubspec 的 `name` 与它不同步时解析静默返回 null —— 规则不报错、
// 也不再报违规，门禁变成空转。`tool/init_project.dart` 改名会同步替换两者，
// 手工改名漏掉一边由这个测试拦下（`just test` 会跑到）。

void main() {
  test('selfPackagePrefix 与根 pubspec.name 一致', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final name = RegExp(
      r'^name:\s*(\S+)',
      multiLine: true,
    ).firstMatch(pubspec)?.group(1);
    expect(name, isNotNull, reason: '根 pubspec.yaml 里取不到 name');

    final paths = File('packages/app_lints/lib/src/paths.dart')
        .readAsStringSync();
    final prefix = RegExp("selfPackagePrefix = 'package:([^/]+)/'")
        .firstMatch(paths)
        ?.group(1);
    expect(prefix, isNotNull, reason: 'paths.dart 里取不到 selfPackagePrefix');

    expect(
      prefix,
      name,
      reason:
          'pubspec.name 与 paths.dart 的 selfPackagePrefix 不一致 —— '
          '规则 1/2（no_upper_import_in_core / cross_feature_only_data） '
          '解析 package: import 时会静默失效，请同步两处 '
          '（用 tool/init_project.dart 改名会一起替换）',
    );
  });
}
