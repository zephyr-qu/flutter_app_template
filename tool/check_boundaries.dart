// 架构边界检查（FSD）。
//
// ```bash
// dart run tool/check_boundaries.dart        # 默认扫 defaultRoots
// dart run tool/check_boundaries.dart lib    # 也可只扫指定根
// ```
//
// 规则与「为什么是脚本而不是 analyzer 插件」见 .trellis/spec/cross-cutting.md。
//
// 四条规则：core/ 不得依赖上层；跨 feature 只共享 data/ 层；
// features/*/logic 不得手动创建 ProviderContainer；
// features/*/logic 不得 import package:flutter/material.dart。
//
// 脚本另外会对「import/export 行没被正则完整解析」打 warning：warning 只提示、
// 不影响退出码，用来暴露正则级检查的已知缺口（条件导入、跨行指令）。

import 'dart:io';

/// 跨 feature 时允许共享的层：只有 `data/` 是对外能力，`page/` `logic/` 是内部实现。
const Set<String> sharedLayers = {'data'};

/// 组合层目录：FSD 的 app 层（根组件、路由、全局页面），可以 import 任何东西。
final List<String> compositionDirs = ['lib/app/'];

/// 默认扫描的根。
///
/// `packages/app_core` 已拍平回 `lib/core/`，因此只扫 `lib`。
const List<String> defaultRoots = ['lib'];

/// 规则 3 的提示语。
const String _containerMessage =
    // 中文句子在换行处本来就不加空格，这条规则的前提是英文长句
    // ignore: missing_whitespace_between_adjacent_strings
    'features/*/logic 里不得手动创建 ProviderContainer —— 依赖从 ref 或构造器取，'
    '容器只在测试里出现';

/// 规则 4 的提示语。
const String _logicUiMessage =
    // 中文句子在换行处本来就不加空格，这条规则的前提是英文长句
    // ignore: missing_whitespace_between_adjacent_strings
    'features/*/logic 不得 import package:flutter/material.dart —— logic 层是纯 Dart，'
    '出现 material 通常意味着把 Widget / BuildContext 塞进了状态层';

class BoundaryViolation {
  const new({
    required this.file,
    required this.line,
    required this.message,
    this.isWarning = false,
  });

  final String file;
  final int line;
  final String message;

  /// true = 「这一行可能没被检查到」的提示，**不影响退出码**。
  ///
  /// 规则本身（[isWarning] 为 false）才拦截提交：warning 只说明脚本的解析能力
  /// 覆盖不到这行，硬拦会把「工具看不懂」变成「代码有问题」。
  final bool isWarning;

  @override
  String toString() => '$file:$line  ${isWarning ? '⚠️ ' : ''}$message';
}

void main(List<String> args) {
  final roots = args.isNotEmpty ? args : defaultRoots;
  final violations = <BoundaryViolation>[];

  for (final root in roots) {
    for (final file in dartFiles(root)) {
      violations.addAll(
        findViolations(
          path: normalizePath(file.path),
          content: file.readAsStringSync(),
        ),
      );
    }
  }

  final errors = violations.where((v) => !v.isWarning).toList();
  final warnings = violations.where((v) => v.isWarning).toList();

  // warning 先打：它解释的是「下面这些违规为什么可能不止这些」
  for (final warning in warnings) {
    stderr.writeln('⚠️  疑似漏检：$warning');
  }
  if (warnings.isNotEmpty) {
    stderr.writeln(
      '   ${warnings.length} 行 import/export 未完整解析：正则级检查的已知缺口，触发条件见 docs/architecture-review.md P4',
    );
  }

  if (errors.isEmpty) {
    final suffix = warnings.isEmpty ? '' : '，另有 ${warnings.length} 条疑似漏检提示';
    stdout.writeln('✅ 架构边界检查通过（${roots.join('、')}）$suffix');
    return;
  }

  stderr.writeln('❌ 架构边界违规 ${errors.length} 处：');
  for (final violation in errors) {
    stderr.writeln('  • $violation');
  }
  exitCode = 1;
}

/// 检查单个文件的内容，返回其中的违规项与漏检提示（用 [BoundaryViolation.isWarning] 区分），
/// 按行号升序。
///
/// [path] 用 `/` 分隔、相对仓库根（如 `lib/features/profile/page/profile_page.dart`）。
/// 拆成纯函数是为了能用普通 `test()` 覆盖，不必真的去扫整个 `lib/`。
List<BoundaryViolation> findViolations({
  required String path,
  required String content,
}) {
  final violations = <BoundaryViolation>[];
  final lines = content.split('\n');

  for (var index = 0; index < lines.length; index++) {
    final line = lines[index];
    final lineNumber = index + 1;

    // 规则 3：logic 层里不得手动建容器
    if (_isFeatureLogic(path) && _containerPattern.hasMatch(line)) {
      violations.add(
        BoundaryViolation(
          file: path,
          line: lineNumber,
          message: _containerMessage,
        ),
      );
    }

    // 规则 1 / 2 / 4：import 与 export 的边界
    final directive = _directivePattern.firstMatch(line);

    // 行以 import/export 开头，却没在**这一行**里解析出 URI：指令被折行了，
    // 正则看不到下一行 —— 不能静默跳过（见 architecture-review.md P4）。
    if (directive == null) {
      if (_directiveHeadPattern.hasMatch(line)) {
        violations.add(
          BoundaryViolation(
            file: path,
            line: lineNumber,
            isWarning: true,
            message: '以 import/export 开头但没解析出 URI —— 这一行不会被边界规则检查（指令跨行？）',
          ),
        );
      }
      continue;
    }

    // 解析出了 URI，但这一行还有正则没吃下去的部分：条件导入的 `if` 分支、
    // 或折行后的续行都会把第二个 URI 藏在规则之外。
    final unparsed = _unparsedRemainder(line, directive);
    if (unparsed != null) {
      violations.add(
        BoundaryViolation(
          file: path,
          line: lineNumber,
          isWarning: true,
          message: '$unparsed —— 边界规则只检查了第一个 URI',
        ),
      );
    }

    final rawUri = directive.group(2)!;

    // 规则 4：logic 层不得依赖 Flutter UI
    if (_isFeatureLogic(path) && rawUri == 'package:flutter/material.dart') {
      violations.add(
        BoundaryViolation(
          file: path,
          line: lineNumber,
          message: _logicUiMessage,
        ),
      );
    }

    final target = _resolveImport(rawUri, path);
    if (target == null) continue;

    final message = _checkImport(path: path, target: target);
    if (message != null) {
      violations.add(
        BoundaryViolation(file: path, line: lineNumber, message: message),
      );
    }
  }

  return violations;
}

final RegExp _directivePattern = RegExp(
  r'''^\s*(import|export)\s+['"]([^'"]+)['"]''',
);

/// 手动建容器的调用点：`ProviderContainer(...)` / `ProviderContainer.test(...)`。
///
/// 规则 3 的判据。取依赖要靠 `ref` 或构造器注入；`ProviderContainer` 是装配层的
/// 工具，出现在 `features/*/logic/` 里就意味着状态层自己绕过了注入。
final RegExp _containerPattern = RegExp(r'\bProviderContainer\s*[.(]');

/// 指令的**开头**，不要求同行有 URI：用来识别「正则没能解析出 URI」的行。
final RegExp _directiveHeadPattern = RegExp(r'^\s*(?:import|export)\b');

/// 条件导入的 `if` 子句，如 `import 'a.dart' if (dart.library.io) 'b.dart';`。
final RegExp _conditionalClausePattern = RegExp(r'''\bif\s*\([^)]*\)\s*['"]''');
final RegExp _featurePattern = RegExp('(?:^|/)features/([^/]+)/');

/// 一条已解析出 URI 的指令，行内还有多少内容没被 [_directivePattern] 覆盖。
///
/// 返回 `null` = 这条指令在这行上被完整吃下了，没有漏检；否则返回漏检原因的
/// 描述（中文短句，可直接拼进 warning）。
String? _unparsedRemainder(String line, RegExpMatch directive) {
  // 丢弃 URI 之后的部分：`;`、`as x`、`show A, B` 都无所谓，
  // 真正关心的是「还有没有第二个 URI」和「语句有没有在这行结束」。
  final remainder = line.substring(directive.end).trim();

  if (_conditionalClausePattern.hasMatch(remainder)) {
    return '这一行是条件导入，if 分支里的 URI 不被解析';
  }
  if (!remainder.contains(';')) {
    return '指令没有以 `;` 结束，URI 可能在续行里（dart format 会折行条件导入）';
  }
  return null;
}

/// 依赖方向：`core/` 是底座，不能反向依赖上层
String? _checkImport({required String path, required String target}) {
  if (_isUnder(path, 'lib/core/') &&
      (_isUnder(target, 'lib/features/') || _isUnder(target, 'lib/app/'))) {
    return 'core/ 不能 import $target —— 依赖方向只能是 features → core';
  }

  // 组合层（app 层）负责装配，可以 import 任何东西
  if (_isCompositionRoot(path)) return null;

  final fromFeature = featureOf(path);
  final toFeature = featureOf(target);

  // 不在 feature 内、或引用的是自己所在的 feature
  if (toFeature == null || toFeature == fromFeature) return null;

  final layer = _layerOf(target);

  // 没有层（feature 根目录下的文件）或属于可共享层
  if (layer == null || sharedLayers.contains(layer)) return null;

  // 中文句子在换行处本来就不加空格，这条规则的前提是英文长句
  // ignore: missing_whitespace_between_adjacent_strings
  return '不能引用 features/$toFeature/$layer/ —— 跨 feature 只共享 data 层'
      '（page/logic 属于 feature 内部，改成用 core 的共享能力或对方 data 层）';
}

bool _isUnder(String path, String prefix) => path.startsWith(prefix);

bool _isCompositionRoot(String path) =>
    compositionDirs.any((dir) => path.startsWith(dir));

bool _isFeatureLogic(String path) =>
    RegExp('(?:^|/)features/[^/]+/logic/').hasMatch(path);

/// 从 `lib/features/<name>/...` 取出 `<name>`；不在 feature 内返回 null
String? featureOf(String path) => _featurePattern.firstMatch(path)?.group(1);

/// 取出 feature 内的第一层目录名（page / logic / data ...）；没有则返回 null
String? _layerOf(String path) {
  final feature = featureOf(path);
  if (feature == null) return null;

  final rest = path.substring(
    path.indexOf('features/$feature/') + 'features/$feature/'.length,
  );
  if (rest.isEmpty || !rest.contains('/')) return null;

  return rest.split('/').first;
}

/// 把 import 里的字符串解析成相对仓库根的路径；外部包返回 null
String? _resolveImport(String raw, String fromPath) {
  if (raw.startsWith('package:my_app/')) {
    return 'lib/${raw.substring('package:my_app/'.length)}';
  }
  if (raw.startsWith('package:') || raw.startsWith('dart:')) return null;
  if (!raw.startsWith('.')) return null;

  final segments = fromPath.substring(0, fromPath.lastIndexOf('/')).split('/');
  for (final part in raw.split('/')) {
    if (part == '.' || part.isEmpty) continue;
    if (part == '..') {
      if (segments.isNotEmpty) segments.removeLast();
    } else {
      segments.add(part);
    }
  }
  return segments.join('/');
}

String normalizePath(String path) => path.replaceAll(r'\', '/');

/// 生成的文件不参与检查：里面的违规没法手工修（要改的是注解 / 源文件），
/// 而且它们经常跨层引用（如 DI 注册文件必须 import 每个 feature 的 logic）。
///
/// 注意 `lib/app/routing/router.dart` 是**手写**的，不属于这里——它引用各
/// feature 的 page 是靠 [compositionDirs] 放行的。
///
/// 这个判定同时被 `tool/check_coverage.dart` 复用：生成代码的行覆盖率不是
/// 人能守的，算进阈值只会稀释门禁。
bool isGeneratedPath(String path) =>
    path.endsWith('.g.dart') ||
    path.endsWith('.freezed.dart') ||
    path.endsWith('.gr.dart') ||
    path.endsWith('.config.dart') ||
    path.endsWith('.gen.dart') ||
    path.contains('/gen/') ||
    path.contains('app_localizations');

Iterable<File> dartFiles(String root) sync* {
  if (!Directory(root).existsSync()) return;

  for (final entity in Directory(root).listSync(recursive: true)) {
    if (entity is! File) continue;

    final path = normalizePath(entity.path);
    if (!path.endsWith('.dart') || isGeneratedPath(path)) continue;

    yield entity;
  }
}
