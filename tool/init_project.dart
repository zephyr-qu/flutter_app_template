// 脚手架初始化 CLI：输出直接进终端 —— 此时项目还没有 DI / 日志设施可用。

import 'dart:io';

// ──────────────────────────────────────────────
// 入口
// ──────────────────────────────────────────────

void main(List<String> args) {
  exit(runCli(args, root: Directory.current));
}

/// 跑一遍初始化流程，返回进程退出码（0 = 成功）。
///
/// 返回退出码而不是直接 `exit()`：回归测试可以直接调用它，既不会把测试宿主
/// 干掉，也能断言失败时的退出码与提示文案。`prompt` / `out` 是为了让测试能
/// 喂输入、收输出。
int runCli(
  List<String> args, {
  required Directory root,
  String Function(String label, String fallback)? prompt,
  void Function(String message)? out,
}) {
  final ask = prompt ?? _prompt;
  final say = out ?? print;

  CliOptions options;
  try {
    options = parseArgs(args);
  } on FormatException catch (error) {
    say('❌ ${error.message}');
    say('');
    say(_usage);
    return 1;
  }

  if (options.help) {
    say(_usage);
    return 0;
  }

  final oldName = _readPubspecName(root);
  if (oldName == null) {
    say('❌ 读不到 pubspec.yaml 的 name: —— 请在仓库根目录运行本脚本');
    return 1;
  }

  say('🚀 Flutter Scaffold — Init New Project');
  say('');
  say('Current project name: $oldName');
  say('');

  // 给了任一取值选项（或 --yes）就不再交互提问，缺失项按默认值推导 ——
  // 端到端回归测试就是靠这个把交互流程跑起来的。
  final interactive = !options.hasValues && !options.assumeYes;
  String value(String? given, String label, String fallback) {
    if (given != null) return given;
    return interactive ? ask(label, fallback) : fallback;
  }

  final newName = value(options.name, 'New Dart package name', oldName);
  final applicationId = value(
    options.applicationId,
    'Android applicationId',
    'com.example.$newName',
  );
  final bundleId = value(options.bundleId, 'iOS Bundle ID', applicationId);
  final displayName = value(
    options.displayName,
    'iOS display name (CFBundleDisplayName)',
    newName,
  );
  final description = value(
    options.description,
    'Project description',
    '$displayName app',
  );

  final problem =
      _validatePackageName(newName) ??
      _validateAppId(applicationId, 'applicationId') ??
      _validateAppId(bundleId, 'iOS Bundle ID');
  if (problem != null) {
    say('❌ $problem');
    return 1;
  }

  final plan = RenamePlan(
    oldName: oldName,
    newName: newName,
    applicationId: applicationId,
    bundleId: bundleId,
    displayName: displayName,
    description: description,
  );

  say('This will update:');
  say('  • pubspec.yaml → name: $newName, description: "$description"');
  say('  • 全仓库 → package:$oldName/ → package:$newName/');
  say('  • 根组件类名 ${plan.oldClassName} → ${plan.newClassName}');
  say('  • build.gradle.kts → namespace / applicationId: $applicationId');
  say('  • AndroidManifest.xml → android:label: $displayName');
  say('  • MainActivity.kt → package $applicationId（并移到对应目录）');
  say('  • Info.plist → CFBundleDisplayName: $displayName');
  say('  • project.pbxproj → PRODUCT_BUNDLE_IDENTIFIER: $bundleId');
  say('');

  if (!options.assumeYes) {
    final confirm = ask('Continue? (y/N)', 'n');
    if (confirm.toLowerCase() != 'y') {
      say('❌ Aborted.');
      return 1;
    }
  }

  final result = applyRename(root: root, plan: plan);

  // 必改点没匹配上：一个字节都没写，把「哪里没对上」原样报出来
  if (!result.ok) {
    say('');
    say('❌ 以下必改点没有匹配到，已中止（没有写入任何文件）：');
    for (final failure in result.failures) {
      say('  • $failure');
    }
    say('');
    say('  多半是这几处已经被手工改过：把 pubspec.yaml 的 name 改成现状，或手工完成剩余部分。');
    return 1;
  }

  say('');
  say('  更新 ${result.updated.length} 个文件');
  say(
    '  import 路径 ${result.importReplacements} 处 / '
    '类名 ${result.classReplacements} 处',
  );
  for (final path in result.updated) {
    say('  ✓ $path');
  }
  for (final move in result.moved) {
    say('  → $move');
  }
  for (final skipped in result.skipped) {
    say('  – 跳过：$skipped');
  }

  _ensureEnvDevelopment(root, say);

  say('');
  say('✅ Project initialized!');
  say('');
  say('Next steps:');
  say('  1. Review changes with: git diff');
  say('  2. Regenerate code: dart run build_runner build');
  say('  3. Verify with: flutter analyze');
  say('  4. Set environment: edit .env.development');
  say('  5. Commit: git add -A && git commit -m "chore: init as $newName"');
  return 0;
}

const String _usage = r'''
用法：dart run tool/init_project.dart [选项]

不带选项时进入交互模式，逐项询问。带上任一取值选项（或 --yes）则完全不提问，
缺失项按默认值推导 —— CI / 脚本里用这种写法。

选项：
  --name=<包名>           Dart package name（pubspec.yaml 的 name）
  --application-id=<id>   Android applicationId，同时作为 namespace 与 MainActivity 的 package
  --bundle-id=<id>        iOS PRODUCT_BUNDLE_IDENTIFIER（默认 = applicationId）
  --display-name=<名称>   android:label / CFBundleDisplayName（默认 = 包名）
  --description=<描述>    pubspec.yaml 的 description（默认 = "<显示名> app"）
  --yes, -y               跳过确认，其余取默认值
  --help, -h              显示本帮助

例：
  dart run tool/init_project.dart \
    --yes --name=my_next_app --application-id=com.example.my_next_app
''';

/// 从 `pubspec.yaml` 读 `name:`；文件不存在或没有该字段返回 null。
String? _readPubspecName(Directory root) {
  final file = File('${root.path}/pubspec.yaml');
  if (!file.existsSync()) return null;
  return RegExp(
    r'^name:\s*(\S+)',
    multiLine: true,
  ).firstMatch(file.readAsStringSync())?.group(1);
}

/// 交互式提问；[fallback] 是回车时的默认值。
String _prompt(String label, String fallback) {
  stdout.write('$label [$fallback]: ');
  final input = stdin.readLineSync()?.trim() ?? '';
  return input.isEmpty ? fallback : input;
}

/// `pubspec.yaml` 的 name 走 Dart 包名规则，写错了整仓库的 import 都会解析失败。
String? _validatePackageName(String name) =>
    RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(name)
    ? null
    : '包名 $name 不合法：只能是小写字母、数字、下划线，且以字母开头';

/// applicationId / bundle id 是反向域名，至少两段。
String? _validateAppId(String value, String label) =>
    RegExp(r'^[a-zA-Z][a-zA-Z0-9_]*(\.[a-zA-Z0-9_]+)+$').hasMatch(value)
    ? null
    : '$label $value 不合法：至少两段、以字母开头（如 com.example.my_app）';

/// `.env.development` 不存在时用 `.env.example` 生成一份（缺失也能跑）。
void _ensureEnvDevelopment(Directory root, void Function(String) say) {
  final target = File('${root.path}/.env.development');
  if (target.existsSync()) return;

  final example = File('${root.path}/.env.example');
  if (!example.existsSync()) return;

  target.writeAsStringSync(example.readAsStringSync());
  say('  ✓ Created: .env.development (from .env.example)');
}

// ──────────────────────────────────────────────
// 输入
// ──────────────────────────────────────────────

/// 命令行选项。取值选项一律写成 `--key=value`。
class CliOptions {
  const new({
    this.help = false,
    this.assumeYes = false,
    this.name,
    this.applicationId,
    this.bundleId,
    this.displayName,
    this.description,
  });

  /// `--help` / `-h`
  final bool help;

  /// `--yes` / `-y`：跳过确认。
  final bool assumeYes;

  final String? name;
  final String? applicationId;
  final String? bundleId;
  final String? displayName;
  final String? description;

  /// 是否给了任一取值选项 —— 给了就整体走非交互。
  bool get hasValues =>
      name != null ||
      applicationId != null ||
      bundleId != null ||
      displayName != null ||
      description != null;
}

/// 解析命令行；未知选项、或 `--key` 没带 `=值` 时抛 [FormatException]。
CliOptions parseArgs(List<String> args) {
  var help = false;
  var assumeYes = false;
  String? name;
  String? applicationId;
  String? bundleId;
  String? displayName;
  String? description;

  String requireValue(String key, String? raw) {
    if (raw == null || raw.isEmpty) {
      throw FormatException('$key 需要写成 $key=值');
    }
    return raw;
  }

  for (final arg in args) {
    switch (arg) {
      case '--help':
      case '-h':
        help = true;
      case '--yes':
      case '-y':
        assumeYes = true;
      default:
        final separator = arg.indexOf('=');
        final key = separator < 0 ? arg : arg.substring(0, separator);
        final raw = separator < 0 ? null : arg.substring(separator + 1);
        switch (key) {
          case '--name':
            name = requireValue(key, raw);
          case '--application-id':
            applicationId = requireValue(key, raw);
          case '--bundle-id':
            bundleId = requireValue(key, raw);
          case '--display-name':
            displayName = requireValue(key, raw);
          case '--description':
            description = requireValue(key, raw);
          default:
            throw FormatException('未知选项：$arg');
        }
    }
  }

  return CliOptions(
    help: help,
    assumeYes: assumeYes,
    name: name,
    applicationId: applicationId,
    bundleId: bundleId,
    displayName: displayName,
    description: description,
  );
}

// ──────────────────────────────────────────────
// 改名计划与结果
// ──────────────────────────────────────────────

/// 一次改名需要的全部输入（交互 / 命令行里已经确定好的值）。
class RenamePlan {
  const new({
    required this.oldName,
    required this.newName,
    required this.applicationId,
    required this.bundleId,
    required this.displayName,
    required this.description,
  });

  /// 旧的 Dart 包名：`pubspec.yaml` 的 `name`，也是 `package:<old>/` 的来源。
  final String oldName;

  /// 新的 Dart 包名：`pubspec.yaml` 的 `name`，也是 import 路径的替换目标。
  final String newName;

  /// Android `applicationId`；同时写进 `namespace` 与 `MainActivity.kt` 的
  /// `package` 声明 —— 三者不一致时 R 类找不到。
  final String applicationId;

  /// iOS `PRODUCT_BUNDLE_IDENTIFIER`（不含 `.RunnerTests` 后缀）。
  final String bundleId;

  /// 用户可见的应用名：`android:label` 与 `CFBundleDisplayName`。
  final String displayName;

  /// `pubspec.yaml` 的 `description`。
  final String description;

  /// 旧 / 新根组件类名（`my_app` → `MyApp`）。
  String get oldClassName => _pascalCase(oldName);
  String get newClassName => _pascalCase(newName);
}

/// 改名结果。
class RenameResult {
  const new({
    required this.updated,
    required this.moved,
    required this.skipped,
    required this.failures,
    required this.importReplacements,
    required this.classReplacements,
  });

  /// 被写盘的文件（相对仓库根，已排序）。
  final List<String> updated;

  /// 被移动的文件，形如 `旧路径 → 新路径`。
  final List<String> moved;

  /// 可选替换里没匹配上的项：只提示，不拦截。
  final List<String> skipped;

  /// 必改点没匹配上的项。非空 = 中止，一个字节都没写。
  final List<String> failures;

  /// `package:<old>/` 的替换次数。
  final int importReplacements;

  /// 根组件类名的替换次数。
  final int classReplacements;

  bool get ok => failures.isEmpty;
}

/// 执行改名，[root] 是仓库根，所有路径都相对它解析。
///
/// **先规划、后写盘**：任一必改点没匹配上就整个中止（[RenameResult.failures]
/// 非空），磁盘保持原样。改一半比不改更难收拾 —— 尤其是包名，半改的仓库连
/// `flutter analyze` 都跑不起来，定位成本远高于直接报「哪一处没对上」。
RenameResult applyRename({required Directory root, required RenamePlan plan}) =>
    _Session(root: root, plan: plan).run();

class _Session {
  new({required this.root, required this.plan});

  final Directory root;
  final RenamePlan plan;

  final Map<String, String> _original = <String, String>{};
  final Map<String, String> _content = <String, String>{};
  final List<String> _updated = <String>[];
  final List<String> _moved = <String>[];
  final List<String> _skipped = <String>[];
  final List<String> _failures = <String>[];
  final List<({String from, String to})> _pendingMoves =
      <({String from, String to})>[];
  List<String>? _files;
  var _imports = 0;
  var _classes = 0;

  RenameResult run() {
    _renamePubspec();
    _renameImportPaths();
    _renameRootClass();
    _renameAndroid();
    _renameIos();
    _renameOptional();
    if (_failures.isEmpty) _flush();

    return RenameResult(
      updated: <String>[..._updated]..sort(),
      moved: _moved,
      skipped: _skipped,
      failures: _failures,
      importReplacements: _imports,
      classReplacements: _classes,
    );
  }

  // ── pubspec ──

  void _renamePubspec() {
    const rel = 'pubspec.yaml';
    final text = _read(rel);
    if (text == null) {
      _failures.add('缺少 $rel —— 改名必须以它为基准');
      return;
    }

    final current = RegExp(
      r'^name:\s*(\S+)',
      multiLine: true,
    ).firstMatch(text)?.group(1);
    if (current == null) {
      _failures.add('$rel 里读不到 `name:`');
    } else if (current != plan.oldName) {
      _failures.add('$rel 的 name 是 $current，与预期的旧名 ${plan.oldName} 不一致');
    }

    _replacePattern(
      rel,
      RegExp(r'^name:.*$', multiLine: true),
      (_) => 'name: ${plan.newName}',
      label: 'name:',
      required: true,
    );
    _replacePattern(
      rel,
      RegExp(r'^description:.*$', multiLine: true),
      (_) => 'description: "${plan.description}"',
      label: 'description:',
      required: true,
    );
  }

  // ── import 路径 ──

  /// `package:<old>/` → `package:<new>/`，全仓库（含生成物，省得再跑 codegen）。
  void _renameImportPaths() {
    final from = 'package:${plan.oldName}/';
    if (from == 'package:${plan.newName}/') {
      _skipped.add('新旧包名相同，跳过 import 路径替换');
      return;
    }

    for (final rel in _textFiles()) {
      final text = _read(rel);
      if (text == null || !text.contains(from)) continue;
      _imports += _replaceAll(
        rel,
        from,
        'package:${plan.newName}/',
        label: from,
      );
    }

    if (_imports == 0) {
      _failures.add('全仓库找不到 $from —— 确认在仓库根目录运行，且 name 还是旧名');
    }
  }

  // ── 根组件类名 ──

  /// `class MyApp` 与新类名不一致时，`app.dart` / `bootstrap.dart` 以及引用它的
  /// 测试都会编译失败，所以整词替换所有 `.dart`。
  void _renameRootClass() {
    final from = plan.oldClassName;
    final to = plan.newClassName;

    const appDart = 'lib/app/app.dart';
    final text = _read(appDart);
    if (text == null) {
      _failures.add('缺少 $appDart');
    } else if (!_word(from).hasMatch(text)) {
      _failures.add('$appDart 里没有 $from —— 根组件类名与包名推导结果不一致');
    }

    if (from == to) return;
    for (final rel in _textFiles()) {
      if (!rel.endsWith('.dart')) continue;
      final content = _read(rel);
      if (content == null || !_word(from).hasMatch(content)) continue;
      _classes += _replacePattern(
        rel,
        _word(from),
        (_) => to,
        label: '类名 $from',
      );
    }
  }

  // ── Android ──

  void _renameAndroid() {
    const gradle = 'android/app/build.gradle.kts';
    final oldNamespace = RegExp(r'namespace\s*=\s*"([^"]*)"')
        .firstMatch(_read(gradle) ?? '')
        ?.group(1);

    _replacePattern(
      gradle,
      RegExp(r'namespace\s*=\s*"[^"]*"'),
      (_) => 'namespace = "${plan.applicationId}"',
      label: 'namespace = "…"',
      required: true,
    );
    _replacePattern(
      gradle,
      RegExp(r'applicationId\s*=\s*"[^"]*"'),
      (_) => 'applicationId = "${plan.applicationId}"',
      label: 'applicationId = "…"',
      required: true,
    );

    const manifest = 'android/app/src/main/AndroidManifest.xml';
    _replacePattern(
      manifest,
      RegExp(r'android:label\s*=\s*"[^"]*"'),
      (_) => 'android:label="${plan.displayName}"',
      label: 'android:label="…"',
      required: true,
    );

    _renameKotlinSources(oldNamespace);
  }

  /// Kotlin 源文件的 `package` 必须跟着 `namespace` 走，文件还要落在对应目录里。
  ///
  /// 只处理「包名等于旧 namespace」的文件：别的包（如历史工具类）不属于这次改名。
  void _renameKotlinSources(String? oldNamespace) {
    const base = 'android/app/src/main/kotlin';
    final sources = _textFiles()
        .where((rel) => rel.startsWith('$base/') && rel.endsWith('.kt'))
        .toList();
    if (sources.isEmpty) {
      _failures.add('找不到 $base/ 下的 Kotlin 源文件（MainActivity.kt 应在其下）');
      return;
    }
    if (oldNamespace == null) {
      _failures.add('android/app/build.gradle.kts 里读不到 `namespace = "…"`');
      return;
    }

    // Kotlin 的包声明不带分号，末尾用 \b 兜住（避免误伤 flutter_app_extra 这类同前缀包）
    final declared = RegExp(
      '^package\\s+${RegExp.escape(oldNamespace)}\\b',
      multiLine: true,
    );
    var matched = 0;
    for (final rel in sources) {
      if (!declared.hasMatch(_read(rel) ?? '')) continue;
      matched++;
      _replacePattern(
        rel,
        declared,
        (_) => 'package ${plan.applicationId}',
        label: 'package $oldNamespace',
        required: true,
      );

      final target =
          '$base/${plan.applicationId.replaceAll('.', '/')}/'
          '${rel.split('/').last}';
      if (target == rel) continue;
      if (File('${root.path}/$target').existsSync()) {
        _failures.add('$target 已存在，不覆盖');
        continue;
      }
      _pendingMoves.add((from: rel, to: target));
    }

    if (matched == 0) {
      _failures.add('$base 下没有 `package $oldNamespace;` 的 Kotlin 源文件');
    }
  }

  // ── iOS ──

  void _renameIos() {
    const pbxproj = 'ios/Runner.xcodeproj/project.pbxproj';
    final text = _read(pbxproj);
    if (text == null) {
      _failures.add('缺少 $pbxproj');
    } else {
      final current = RegExp(r'PRODUCT_BUNDLE_IDENTIFIER\s*=\s*([^;\s]+);')
          .firstMatch(text)
          ?.group(1);
      if (current == null) {
        _failures.add('$pbxproj 里找不到 `PRODUCT_BUNDLE_IDENTIFIER`');
      } else {
        // 测试 target 的 bundle id 是主 id + `.RunnerTests`：整体替换主 id
        // 就把两者一起带过去了，不用分别处理。
        const testsSuffix = '.RunnerTests';
        final base = current.endsWith(testsSuffix)
            ? current.substring(0, current.length - testsSuffix.length)
            : current;
        _replaceAll(
          pbxproj,
          base,
          plan.bundleId,
          label: 'PRODUCT_BUNDLE_IDENTIFIER',
          required: true,
        );
      }
    }

    const plist = 'ios/Runner/Info.plist';
    _replacePlistValue(
      plist,
      'CFBundleDisplayName',
      plan.displayName,
      required: true,
    );
    _replacePlistValue(plist, 'CFBundleName', plan.newName);
  }

  void _replacePlistValue(
    String rel,
    String key,
    String value, {
    bool required = false,
  }) {
    _replacePattern(
      rel,
      RegExp('<key>$key</key>\\s*<string>[^<]*</string>'),
      (_) => '<key>$key</key>\n\t<string>$value</string>',
      label: key,
      required: required,
    );
  }

  // ── 可选 ──

  /// 文档、`.gitignore` 等文本里的裸包名，以及 `<旧名>.code-workspace` 文件名。
  ///
  /// 一律不拦提交：这些地方本来就是「顺手改掉更好」，缺了不说明改名失败。
  void _renameOptional() {
    final word = _word(plan.oldName);
    for (final rel in _textFiles()) {
      if (rel.endsWith('.dart')) continue; // Dart 里的包名走 import / 类名两条规则
      final text = _read(rel);
      if (text == null || !word.hasMatch(text)) continue;
      _replacePattern(rel, word, (_) => plan.newName, label: plan.oldName);
    }

    final from = '${plan.oldName}.code-workspace';
    if (!File('${root.path}/$from').existsSync()) return;
    final to = '${plan.newName}.code-workspace';
    if (to == from) return;
    if (File('${root.path}/$to').existsSync()) {
      _skipped.add('$to 已存在，保留 $from 不改名');
      return;
    }
    _pendingMoves.add((from: from, to: to));
  }

  // ── 读写 ──

  /// 扫描范围内的文本文件（相对仓库根，已排序）。
  List<String> _textFiles() => _files ??= _collectTextFiles(root);

  /// 读文件内容；不存在返回 null。首次读取时留一份原文，用于判断「是否真的改了」。
  String? _read(String rel) {
    final cached = _content[rel];
    if (cached != null) return cached;

    final file = File('${root.path}/$rel');
    if (!file.existsSync()) return null;

    final text = file.readAsStringSync();
    _original[rel] = text;
    _content[rel] = text;
    return text;
  }

  /// 整串替换，返回命中次数。
  int _replaceAll(
    String rel,
    String from,
    String to, {
    required String label,
    bool required = false,
  }) {
    final text = _read(rel);
    if (text == null) {
      _missingFile(rel, required);
      return 0;
    }
    if (from.isEmpty || !text.contains(from)) {
      _noMatch(rel, label, required);
      return 0;
    }

    final hits = text.split(from).length - 1;
    _content[rel] = text.replaceAll(from, to);
    return hits;
  }

  /// 正则替换，返回命中次数。
  int _replacePattern(
    String rel,
    RegExp pattern,
    String Function(Match match) to, {
    required String label,
    bool required = false,
  }) {
    final text = _read(rel);
    if (text == null) {
      _missingFile(rel, required);
      return 0;
    }

    final matches = pattern.allMatches(text).toList();
    if (matches.isEmpty) {
      _noMatch(rel, label, required);
      return 0;
    }

    _content[rel] = text.replaceAllMapped(pattern, to);
    return matches.length;
  }

  void _missingFile(String rel, bool required) {
    if (required) {
      _failures.add('缺少文件 $rel');
    } else {
      _skipped.add('缺少文件 $rel（可选）');
    }
  }

  /// 没匹配上：`required` 的记失败（中止且不写盘），其余只提示。
  void _noMatch(String rel, String label, bool required) {
    if (required) {
      _failures.add('$rel 里没有匹配到 `$label`');
    } else {
      _skipped.add('$rel 里没有 `$label`（可选）');
    }
  }

  void _flush() {
    for (final entry in _content.entries) {
      if (_original[entry.key] == entry.value) continue;
      final file = File('${root.path}/${entry.key}');
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(entry.value);
      _updated.add(entry.key);
    }

    for (final move in _pendingMoves) {
      _moveFile(move.from, move.to);
    }
  }

  void _moveFile(String from, String to) {
    final source = File('${root.path}/$from');
    if (!source.existsSync()) {
      _skipped.add('$from 不存在，跳过移动');
      return;
    }

    final target = File('${root.path}/$to')..parent.createSync(recursive: true);
    try {
      source.renameSync(target.path);
    } on FileSystemException {
      // 跨盘符时 rename 会失败：退化成复制 + 删除
      target.writeAsStringSync(source.readAsStringSync());
      source.deleteSync();
    }
    _moved.add('$from → $to');
    _pruneEmptyDirs(from);
  }

  /// 移动后清掉旧包目录：只在 `kotlin/` 之下、且目录确实空了才删。
  void _pruneEmptyDirs(String movedFrom) {
    const base = 'android/app/src/main/kotlin';
    var parent = _parentOf(movedFrom);
    while (parent != null && parent.startsWith('$base/')) {
      final directory = Directory('${root.path}/$parent');
      if (!directory.existsSync() || directory.listSync().isNotEmpty) return;
      directory.deleteSync();
      parent = _parentOf(parent);
    }
  }
}

// ──────────────────────────────────────────────
// 文本工具
// ──────────────────────────────────────────────

/// 改名要跳过的目录：`.git` 与各类构建产物。
///
/// 端到端回归测试复制仓库时也用它（[isBuildArtifactPath]），避免两处清单漂移。
const Set<String> buildArtifactDirs = {
  '.git',
  '.dart_tool',
  'build',
  'coverage',
  '.gradle',
  'Pods',
  'ephemeral',
  'node_modules',
  '.idea',
};

/// 该相对路径是否位于产物目录之下。
bool isBuildArtifactPath(String relativePath) =>
    relativePath.split('/').any(buildArtifactDirs.contains);

/// 会被逐文件扫描的文本后缀。
const Set<String> _textExtensions = {
  '.dart',
  '.md',
  '.yaml',
  '.yml',
  '.json',
  '.arb',
  '.xml',
  '.plist',
  '.pbxproj',
  '.kts',
  '.gradle',
  '.kt',
  '.swift',
  '.sh',
  '.properties',
  '.txt',
  '.toml',
  '.code-workspace',
};

/// 没有常规后缀、但确实是文本的文件。
const Set<String> _textNames = {'.gitignore', '.env', 'pre-commit'};

/// 递归收集要扫描的文本文件（相对 [root]，`/` 分隔，已排序）。
///
/// 跳过产物目录，也跳过 `pubspec.lock` 这类由工具重新生成、且不含包名的文件。
List<String> _collectTextFiles(Directory root) {
  final rootPath = _normalize(root.absolute.path);
  final files = <String>[];

  for (final entity in root.listSync(recursive: true, followLinks: false)) {
    if (entity is! File) continue;

    final path = _normalize(entity.absolute.path);
    final rel = path.startsWith('$rootPath/')
        ? path.substring(rootPath.length + 1)
        : path;
    if (isBuildArtifactPath(rel)) continue;

    final name = rel.split('/').last;
    if (!_textExtensions.contains(_extensionOf(name)) &&
        !_textNames.contains(name) &&
        !name.startsWith('.env') &&
        !rel.endsWith('/pre-commit')) {
      continue;
    }

    files.add(rel);
  }

  files.sort();
  return files;
}

String _normalize(String path) =>
    path.replaceAll(r'\', '/').replaceAll(RegExp(r'/+$'), '');

/// `name.dart` → `.dart`；无后缀或以点开头（`.gitignore`）返回空串。
String _extensionOf(String name) {
  final index = name.lastIndexOf('.');
  return index <= 0 ? '' : name.substring(index);
}

String? _parentOf(String path) {
  final index = path.lastIndexOf('/');
  return index <= 0 ? null : path.substring(0, index);
}

/// 整词匹配：避免 `my_app` 波及 `my_app_lint`。
RegExp _word(String value) => RegExp('\\b${RegExp.escape(value)}\\b');

/// 把 snake_case / kebab-case 名称转成 PascalCase。
String _pascalCase(String name) => name
    .split(RegExp(r'[-_.\s]+'))
    .map(
      (part) => part.isEmpty ? '' : part[0].toUpperCase() + part.substring(1),
    )
    .join();
