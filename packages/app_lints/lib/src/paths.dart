import 'package:analyzer/analysis_rule/rule_context.dart';

/// 路径与 import 解析的纯函数。
///
/// 与根 `justfile` 的路径口径一致：
/// 一律用 `/` 分隔的**仓库相对路径**判断，如 `lib/features/sample/logic/x.dart`。

/// 当前被分析文件的仓库相对路径；拿不到（不在包内 / 无上下文）返回 null。
///
/// 规则拿到 null 就该直接放弃——宁可漏检，也不要因为路径判不出来而误报。
String? currentPath(RuleContext context) {
  final unit = context.currentUnit;
  final package = context.package;
  if (unit == null || package == null) return null;

  final root = _normalize(package.root.path);
  final file = _normalize(unit.file.path);
  if (!file.startsWith('$root/')) return null;
  return file.substring(root.length + 1);
}

/// 生成物豁免。
///
/// 生成器只保证产物「能编译」，不保证遵守本仓库的层次约定（路由要汇总所有
/// feature 的 page/）；而且里面的违规没法手工修（要改的是注解 / 源文件）。
/// 生成物已 gitignore（门禁列表天然列不到），IDE 或手工 analyze 单文件时
/// 仍可能碰到——口径与根 `.gitignore` 一致，改动时要一起改。
bool isGeneratedPath(String path) =>
    path.endsWith('.g.dart') ||
    path.endsWith('.freezed.dart') ||
    path.endsWith('.gr.dart') ||
    path.endsWith('.config.dart') ||
    path.endsWith('.gen.dart') ||
    path.contains('/gen/') ||
    path.contains('app_localizations');

/// 本包名。`tool/init_project.dart` 会全仓库替换 `package:my_app/`，
/// 改名后这里会一起被换掉。
const String selfPackagePrefix = 'package:my_app/';

/// 把 import 的 URI 解析成仓库相对路径；外部包 / `dart:` 返回 null。
///
/// [fromPath] 是发出这条 import 的文件（仓库相对路径），相对导入要靠它定位。
String? resolveImport(String rawUri, String fromPath) {
  if (rawUri.startsWith(selfPackagePrefix)) {
    return 'lib/${rawUri.substring(selfPackagePrefix.length)}';
  }
  if (rawUri.startsWith('package:') || rawUri.startsWith('dart:')) return null;
  if (!rawUri.startsWith('.')) return null;

  final segments = fromPath.split('/')..removeLast();
  for (final part in rawUri.split('/')) {
    if (part == '.' || part.isEmpty) continue;
    if (part == '..') {
      if (segments.isNotEmpty) segments.removeLast();
    } else {
      segments.add(part);
    }
  }
  return segments.join('/');
}

/// 从 `lib/features/<name>/...` 取出 `<name>`；不在 feature 内返回 null。
String? featureOf(String path) =>
    RegExp('(?:^|/)features/([^/]+)/').firstMatch(path)?.group(1);

/// 取出 feature 内第一层目录名（page / logic / data …）；没有则 null。
String? layerOf(String path) {
  final feature = featureOf(path);
  if (feature == null) return null;

  const marker = 'features/';
  final start =
      path.indexOf('$marker$feature/') + marker.length + feature.length + 1;
  final rest = path.substring(start);
  if (rest.isEmpty || !rest.contains('/')) return null;

  return rest.split('/').first;
}

String _normalize(String path) => path.replaceAll(r'\', '/');
