// 文件遍历与生成物判定：`tool/` 下的检查脚本共用的最小工具集。
//
// 边界与形态约定已改由 `packages/app_lints` 的分析插件实现，脚本侧只剩覆盖率与
// 目录树两道门禁 —— 它们都要「扫某个根下的手写 dart 文件」，所以把这三件事单独
// 放在这里，不必为了一个函数 import 一整个规则脚本。
//
// ```bash
// dart run tool/check_coverage.dart coverage/lcov.info --src=lib
// dart run tool/check_readme_tree.dart
// ```

import 'dart:io';

/// 生成的文件不参与检查：里面的违规没法手工修（要改的是注解 / 源文件），
/// 而且它们经常跨层引用（如 DI 注册文件必须 import 每个 feature 的 logic）。
///
/// 判定被覆盖率与目录树两道门禁复用：生成代码的行覆盖率不是人能守的，算进
/// 阈值只会稀释门禁；目录树里也不必列出它们。
///
/// 口径与根 `.gitignore`、`packages/app_lints/lib/src/paths.dart` 一致，
/// 任何一处改动都要同时改另两处。
bool isGeneratedPath(String path) =>
    path.endsWith('.g.dart') ||
    path.endsWith('.freezed.dart') ||
    path.endsWith('.gr.dart') ||
    path.endsWith('.config.dart') ||
    path.endsWith('.gen.dart') ||
    path.contains('/gen/') ||
    path.contains('app_localizations');

String normalizePath(String path) => path.replaceAll(r'\', '/');

/// [root] 下的手写 dart 文件（含子目录，生成物已剔除）。
Iterable<File> dartFiles(String root) sync* {
  if (!Directory(root).existsSync()) return;

  for (final entity in Directory(root).listSync(recursive: true)) {
    if (entity is! File) continue;

    final path = normalizePath(entity.path);
    if (!path.endsWith('.dart') || isGeneratedPath(path)) continue;

    yield entity;
  }
}
