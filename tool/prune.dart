// 正交裁剪：把脚手架裁成更小的变体。
//
// ```bash
// dart run tool/prune.dart --l10n=single     # 裁成单语言（中文）
// dart run tool/prune.dart --l10n=multi      # 默认值，不改任何东西
// dart run tool/prune.dart --theme=default   # 未实现的轴 → 报错退出
// dart run tool/prune.dart --dry-run --l10n=single   # 只报告会改什么
// ```
//
// 三条约定（与 tool/init_project.dart 同源）：
//
// 1. **全有或全无**：先把全部改动收集成一份计划（改写 / 删除 / 配置），任一 recipe
//    没匹配到就报出「哪一个、在哪个文件」并以非零退出码结束，**磁盘不变**。
//    半裁的仓库连 `flutter analyze` 都跑不起来，定位成本远高于直接报位置。
// 2. **幂等**：重复执行同一轴不产生额外差异；已经在单语言仓库上再跑 `--l10n=single`
//    会报「没有可裁的内容」而不是报错。
// 3. **未实现的轴不静默忽略**：传了 `--theme` 之类必须报错，否则使用者会以为裁掉了。
//
// 为什么 l10n 做成参数而不是分支：它横切 `core/ui/failure_message.dart` 与
// `core/config/user_preferences.dart`，做成分支会在这些文件上与其它分支反复冲突。
// 详见 .trellis/tasks/09-22-prune-l10n/prd.md。

import 'dart:convert';
import 'dart:io';

/// 已实现的轴 → 允许的取值。未列出的轴一律「未实现」。
const Map<String, Set<String>> supportedAxes = <String, Set<String>>{
  'l10n': <String>{'multi', 'single'},
};

/// 默认取值（等于「什么都不裁」）。
const Map<String, String> defaultAxes = <String, String>{'l10n': 'multi'};

const String arbPath = 'lib/l10n/app_zh.arb';

const List<String> l10nOwnedPaths = <String>[
  'l10n.yaml',
  'lib/l10n',
  'test/l10n',
];

void main(List<String> args) {
  final parsed = _parseArgs(args);
  if (parsed.help) {
    stdout.writeln(_usage);
    return;
  }
  if (parsed.error != null) {
    stderr
      ..writeln('❌ ${parsed.error}')
      ..writeln(_usage);
    exitCode = 1;
    return;
  }

  final l10n = parsed.axes['l10n']!;
  if (l10n == 'multi') {
    stdout.writeln('✅ --l10n=multi：多语言是仓库的默认形态，没有可裁的内容');
    return;
  }

  final plan = PrunePlan();

  // 幂等：已经裁过一轮的仓库里 ARB 已被删除，再跑一次应当是无害的空操作，
  // 而不是崩在「找不到文件」。
  if (!File(arbPath).existsSync()) {
    stdout.writeln('✅ 已经是单语言形态（找不到 $arbPath），没有可裁的内容');
    return;
  }

  final messages = parseArb(File(arbPath).readAsStringSync());

  _planL10nSingle(plan, messages);

  if (plan.failures.isNotEmpty) {
    stderr.writeln('❌ 裁剪中止，磁盘未改动。以下 recipe 没匹配到：');
    for (final failure in plan.failures) {
      stderr.writeln('  • $failure');
    }
    stderr.writeln(
      // 中文句子在换行处本来就不加空格，这条规则的前提是英文长句
      // ignore: missing_whitespace_between_adjacent_strings
      '   源文件已经变了 —— 请同步更新 tool/prune.dart 里对应的 recipe'
      '（改完重跑即可，本脚本全有或全无）。',
    );
    exitCode = 1;
    return;
  }

  if (plan.isEmpty) {
    stdout.writeln('✅ 已经是单语言形态，没有可裁的内容');

    return;
  }

  stdout.writeln('将做以下改动（--dry-run 时只报告不落盘）：');
  for (final path in plan.rewrites.keys.toList()..sort()) {
    stdout.writeln('  ✏️  $path');
  }
  for (final path in plan.deletes.toList()..sort()) {
    stdout.writeln('  🗑️  $path');
  }

  if (parsed.dryRun) {
    stdout.writeln('\n（--dry-run：没有写入任何文件）');
    return;
  }

  for (final entry in plan.rewrites.entries) {
    File(entry.key).writeAsStringSync(entry.value);
  }
  for (final path in plan.deletes) {
    final entity = FileSystemEntity.typeSync(path);
    if (entity == FileSystemEntityType.directory) {
      Directory(path).deleteSync(recursive: true);
    } else if (entity == FileSystemEntityType.file) {
      File(path).deleteSync();
    }
  }

  // `l10n.x` 是 getter，所在构造器原本无法 const；换成中文字面量后就可以 const 了。
  // 用 `dart fix` 自动把 `const` 补上（PRD 要求「→ const 中文字符串」），再统一格式——
  // 否则 analyze 会因 `prefer_const_constructors` 报 info，而本仓库 `flutter analyze`
  // 默认把 info 也算失败。
  // 只作用于 lib / test，避免把 `tool/` 下的脚本一并改写（脚本不该自我修改）。
  for (final dir in <String>['lib', 'test']) {
    final fix = Process.runSync('dart', <String>['fix', '--apply', dir]);
    if (fix.exitCode != 0) {
      stderr
        ..writeln('❌ `dart fix --apply $dir` 失败：')
        ..writeln('${fix.stdout}${fix.stderr}');
      exitCode = 1;
      return;
    }
  }
  Process.runSync('dart', <String>['format', 'lib', 'test']);

  stdout
    ..writeln('\n✅ 裁剪完成（--l10n=single）。接下来请手动确认：')
    ..writeln('   1. just verify')
    ..writeln('   2. .trellis/spec/frontend/localization.md 描述的是多语言形态，')
    ..writeln('      单语言分支上它已过期 —— 删掉或改写，并同步 frontend/index.md 的链接');
}

// ──────────────────────────────────────────────
// 参数
// ──────────────────────────────────────────────

class ParsedArgs {
  const new({
    required this.axes,
    this.help = false,
    this.dryRun = false,
    this.error,
  });

  final Map<String, String> axes;
  final bool help;
  final bool dryRun;
  final String? error;
}

ParsedArgs _parseArgs(List<String> args) {
  final axes = Map<String, String>.from(defaultAxes);
  var dryRun = false;

  for (final arg in args) {
    if (arg == '--help' || arg == '-h') {
      return const ParsedArgs(axes: <String, String>{}, help: true);
    }
    if (arg == '--dry-run') {
      dryRun = true;
      continue;
    }
    if (!arg.startsWith('--') || !arg.contains('=')) {
      return ParsedArgs(axes: axes, error: '无法识别的参数「$arg」（只接受 --key=value）');
    }

    final eq = arg.indexOf('=');
    final key = arg.substring(2, eq);
    final value = arg.substring(eq + 1);

    final allowed = supportedAxes[key];
    if (allowed == null) {
      return ParsedArgs(
        axes: axes,
        error: '轴「$key」尚未实现（已实现：${supportedAxes.keys.join('、')}）',
      );
    }
    if (!allowed.contains(value)) {
      return ParsedArgs(
        axes: axes,
        error: '轴「$key」不接受取值「$value」（可选：${allowed.join(' / ')}）',
      );
    }
    axes[key] = value;
  }

  return ParsedArgs(axes: axes, dryRun: dryRun);
}

const String _usage = '''
用法：dart run tool/prune.dart --<轴>=<取值> [--dry-run]

已实现的轴：
  --l10n=multi|single    多语言 / 单语言（中文）。multi 是默认值，等于不裁。

未实现的轴（传了会报错，不会静默忽略）：--theme 等。

选项：
  --dry-run              只打印会改哪些文件，不落盘
  -h, --help             显示本帮助
''';

// ──────────────────────────────────────────────
// 计划：收集 → 校验 → 落盘（全有或全无）
// ──────────────────────────────────────────────

class PrunePlan {
  /// 路径 → 完整新内容
  final Map<String, String> rewrites = <String, String>{};

  /// 要删除的路径（文件或目录）
  final List<String> deletes = <String>[];

  /// recipe 没匹配到等硬错误
  final List<String> failures = <String>[];

  bool get isEmpty => rewrites.isEmpty && deletes.isEmpty;

  /// 读一份文件的**当前**计划内容（已改写则取改写后的，保证 recipe 可叠加）。
  ///
  /// 首次从磁盘加载时把 CRLF 归一为 LF：仓库里混有 CRLF 文件，依赖行尾的
  /// 正则（`_l10nImport` / `_l10nDeclaration`）与精确 `\n` recipe 在 CRLF 上会漏匹配。
  String read(String path) =>
      rewrites[path] ?? File(path).readAsStringSync().replaceAll('\r\n', '\n');

  void write(String path, String content) => rewrites[path] = content;
}

/// 精确替换。`old` 必须存在，否则记一条 failure。
class Replacement {
  const new(
    this.path,
    this.description,
    this.old,
    this.newText, {
    this.all = false,
  });

  final String path;
  final String description;
  final String old;
  final String newText;

  /// true = 替换全部出现；false = 只替换第一处（要求唯一）
  final bool all;
}

/// 删除 `[start .. end]`（含两端锚点）。两个锚点都必须存在。
class Removal {
  const new(this.path, this.description, this.start, this.end);

  final String path;
  final String description;
  final String start;
  final String end;
}

void _applyReplacements(PrunePlan plan, List<Replacement> list) {
  for (final r in list) {
    final current = plan.read(r.path);
    final count = r.old.allMatches(current).length;
    if (count == 0) {
      plan.failures.add('${r.path}  替换「${r.description}」没找到目标文本');
      continue;
    }
    if (!r.all && count > 1) {
      plan.failures.add(
        // 中文句子在换行处本来就不加空格，这条规则的前提是英文长句
        // ignore: missing_whitespace_between_adjacent_strings
        '${r.path}  替换「${r.description}」在文件里出现 $count 次，无法确定改哪一处'
        '（要么补足上下文使其唯一，要么显式用 all: true）',
      );
      continue;
    }
    plan.write(
      r.path,
      r.all
          ? current.replaceAll(r.old, r.newText)
          : current.replaceFirst(r.old, r.newText),
    );
  }
}

void _applyRemovals(PrunePlan plan, List<Removal> list) {
  for (final r in list) {
    final current = plan.read(r.path);
    final startIndex = current.indexOf(r.start);
    if (startIndex < 0) {
      plan.failures.add('${r.path}  删除「${r.description}」的起始锚点没找到');
      continue;
    }
    final endIndex = current.indexOf(r.end, startIndex);
    if (endIndex < 0) {
      plan.failures.add('${r.path}  删除「${r.description}」的结束锚点没找到');
      continue;
    }
    final cut = endIndex + r.end.length;
    plan.write(
      r.path,
      current.substring(0, startIndex) + current.substring(cut),
    );
  }
}

// ──────────────────────────────────────────────
// 通用改写：ARB 驱动的调用点替换
// ──────────────────────────────────────────────

/// 解析 ARB，返回 key → 文案。跳过 `@@locale` 与 `@key` 元数据。
///
/// 纯函数，便于单测（见 test/tool/prune_test.dart）。
Map<String, String> parseArb(String content) {
  final decoded = jsonDecode(content) as Map<String, dynamic>;
  final messages = <String, String>{};

  for (final entry in decoded.entries) {
    if (entry.key.startsWith('@')) continue;
    final value = entry.value;
    if (value is! String) continue;
    messages[entry.key] = value;
  }

  return messages;
}

/// 调用点的接收者：`l10n` 或 `AppLocalizations.of(context)`。
final RegExp _receiverPattern = RegExp(
  r'(?:AppLocalizations\.of\(context\)|l10n)\.([A-Za-z_][A-Za-z0-9_]*)',
);

/// 形如 `final l10n = AppLocalizations.of(context);` 的整行声明。
final RegExp _l10nDeclaration = RegExp(
  r'^[ \t]*final (?:AppLocalizations )?l10n = AppLocalizations\.of\(context\);[ \t]*\n',
  multiLine: true,
);

/// `package:my_app/l10n/app_localizations*.dart` 的 import。
final RegExp _l10nImport = RegExp(
  r"^import 'package:my_app/l10n/app_localizations[^']*';\n",
  multiLine: true,
);

/// `localizedMessage(...)` —— 单语言形态下参数被删，统一剥成无参调用
/// （覆盖 `localizedMessage(l10n)` / `localizedMessage(AppLocalizations.of(context))` /
/// `localizedMessage(zh)` 等所有遗留实参）。
final RegExp _localizedMessageCall = RegExp(r'\.localizedMessage\([^)]*\)');

/// 测试里 `wrapPage(..., locale: <val>)` / `pumpPage(..., locale: <val>)` 的命名实参。
/// `<val>` 可能是 `const Locale('en')`（自带括号）或裸标识符 `locale`，两种都要整段摘掉；
/// 注意不能吞掉外层调用的 `)`。
final RegExp _localeArg = RegExp(
  r",[ \t]*locale:[ \t]*(?:const Locale\('[^']*'\)|[A-Za-z_][A-Za-z0-9_]*)",
);

/// 还Reference 了 l10n 但**没有** `l10n.`/`AppLocalizations.of(context)` 调用的文件：
/// 测试里直接写 `const Locale('en')`、给 `MaterialApp` 挂 `localizationsDelegates` 等。
/// 这类文件也要进通用改写（摘掉 MaterialApp 的 l10n 三件套、去掉 `wrapPage` 的
/// `locale:` 实参），否则只靠 `l10n.` 判定会漏掉它们。
final RegExp _l10nRelated = RegExp(
  r'AppLocalizations|localizationsDelegates|supportedLocales|Locale\(',
);

/// 把调用点换成中文字面量，并移除 `l10n` 声明与 import。
///
/// **带占位符的调用**（如 `l10n.errorRequestFailed(...)`）用**配对括号扫描**取实参，
/// 而不是正则：实参可能跨行、可能含括号（`'${statusCode ?? '?'}'`），正则吃不干净。
///
/// 纯函数：`content` 进、`content` 出；不确定的 key 记进 `failures` 而不是猜。
String rewriteLocalizations(
  String content,
  Map<String, String> messages,
  List<String> failures,
  String path,
) {
  final buffer = StringBuffer();
  var cursor = 0;

  for (final match in _receiverPattern.allMatches(content)) {
    if (match.start < cursor) continue; // 落在上一次替换的实参里

    final key = match.group(1)!;
    final value = messages[key];
    if (value == null) {
      failures.add('$path  l10n key「$key」不在 $arbPath 里（拼错了？还是该走 recipe？）');
      continue;
    }

    // 紧跟 `(` 说明是带占位符的调用，需要取实参
    var after = match.end;
    while (after < content.length && content[after] == ' ') {
      after++;
    }

    String replacement;
    var consumedTo = match.end;

    if (after < content.length && content[after] == '(') {
      final close = _matchingParen(content, after);
      if (close < 0) {
        failures.add('$path  `$key` 的实参括号不匹配，放弃解析');
        continue;
      }
      // 实参里可能嵌套别的 l10n 调用（如
      // `l10n.homeGreeting(user?.name ?? l10n.userFallback)`），递归改写；
      // 并剥掉 Dart 允许的参数尾逗号（否则 `l10n.x('...',)` 会把逗号带进插值）。
      final rawArg = content.substring(after + 1, close);
      final argRewritten = rewriteLocalizations(
        rawArg,
        messages,
        failures,
        path,
      );
      var argument = argRewritten.trim();
      if (argument.endsWith(',')) {
        argument = argument.substring(0, argument.length - 1).trim();
      }
      replacement = _literal(value, argument: argument);
      consumedTo = close + 1;
    } else {
      if (value.contains('{')) {
        failures.add('$path  `$key` 的文案带占位符，但调用点没有传实参');
        continue;
      }
      replacement = _literal(value);
    }

    buffer
      ..write(content.substring(cursor, match.start))
      ..write(replacement);
    cursor = consumedTo;
  }
  buffer.write(content.substring(cursor));

  var out = buffer.toString();
  out = out.replaceAll(_l10nDeclaration, '');
  out = out.replaceAll(_l10nImport, '');
  // `localizedMessage` 在单语言形态下无参数：剥掉所有遗留实参
  // （`localizedMessage(l10n)` / `localizedMessage(AppLocalizations.of(context))`）。
  out = out.replaceAllMapped(
    _localizedMessageCall,
    (m) => '.localizedMessage()',
  );

  // 单语言形态下，页面/测试里给 `MaterialApp` 挂的 l10n 三件套也要摘掉。
  // 行尾与缩进都放过：生成物可能 CRLF，且不同文件缩进不一致。
  out = out.replaceAllMapped(
    RegExp(
      r'^[ \t]*localizationsDelegates: AppLocalizations\.localizationsDelegates,[ \t]*\n',
      multiLine: true,
    ),
    (_) => '',
  );
  out = out.replaceAllMapped(
    RegExp(
      r'^[ \t]*supportedLocales: AppLocalizations\.supportedLocales,[ \t]*\n',
      multiLine: true,
    ),
    (_) => '',
  );
  out = out.replaceAllMapped(
    RegExp(r'^[ \t]*locale: const Locale\([^)]*\),[ \t]*\n', multiLine: true),
    (_) => '',
  );
  // 测试里 `wrapPage(..., locale: <val>)` 的实参（含 `locale: locale` 简写与
  // `const Locale('en')` 形态）。只删实参本身，保留外层调用的 `)`。
  out = out.replaceAll(_localeArg, '');
  return out;
}

/// 从 `openIndex`（指向 `(`）开始找配对的 `)`；失败返回 -1。
///
/// 会被 `'...'` / `"..."` 里的括号骗到的情况在本项目不存在（文案里没有括号），
/// 所以不处理字符串转义 —— 真遇到了会在 analyze 阶段暴露，而不是静默改错。
int _matchingParen(String content, int openIndex) {
  var depth = 0;
  for (var i = openIndex; i < content.length; i++) {
    final ch = content[i];
    if (ch == '(') depth++;
    if (ch == ')') {
      depth--;
      if (depth == 0) return i;
    }
  }
  return -1;
}

/// 把 ARB 文案转成 Dart 字面量。
///
/// [argument] 非空时用于替换模板里的 `{占位符}` —— 字面量部分照常转义，
/// 代入的实参**不转义**（它本来就是 Dart 表达式）。
String _literal(String value, {String? argument}) {
  if (argument == null) return "'${_escape(value)}'";

  final parts = value.split(RegExp(r'\{[^}]+\}'));
  if (parts.length == 1) return "'${_escape(value)}'";

  final buffer = StringBuffer("'");
  for (var i = 0; i < parts.length; i++) {
    buffer.write(_escape(parts[i]));
    if (i < parts.length - 1) buffer.write('\${$argument}');
  }
  buffer.write("'");
  return buffer.toString();
}

String _escape(String value) => value
    .replaceAll(r'\', r'\\')
    .replaceAll("'", r"\'")
    .replaceAll(r'$', r'\$');

// ──────────────────────────────────────────────
// --l10n=single 的全部改动
// ──────────────────────────────────────────────

void _planL10nSingle(PrunePlan plan, Map<String, String> messages) {
  // ① 结构性改动：**必须在通用改写之前**跑 —— 锚点用的是源码里的写法
  //    （`l10n.settingsLanguage`），通用改写之后就找不到它们了。
  _applyReplacements(plan, _l10nReplacements);
  _applyRemovals(plan, _l10nRemovals);

  // ② 通用改写：剩下的 `l10n.<key>` 全部变成中文字面量
  for (final path in _localizationAwareFiles()) {
    final current = plan.read(path);
    final rewritten = rewriteLocalizations(
      current,
      messages,
      plan.failures,
      path,
    );
    if (rewritten != current) plan.write(path, rewritten);
  }

  // ③ 删除 l10n 自有文件
  for (final path in l10nOwnedPaths) {
    final type = FileSystemEntity.typeSync(path);
    if (type != FileSystemEntityType.notFound) plan.deletes.add(path);
  }
}

/// 需要做通用改写的文件：`lib/` 与 `test/` 下所有引用 l10n 的 Dart 文件。
///
/// 用「扫全目录 + 判定是否含 l10n 调用」而不是维护一份清单：清单会漂移，
/// 而判定条件（出现 `l10n.` 或 `AppLocalizations`）本身就是「要不要改」的定义。
Iterable<String> _localizationAwareFiles() sync* {
  for (final root in <String>['lib', 'test']) {
    final dir = Directory(root);
    if (!dir.existsSync()) continue;

    for (final entity in dir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;

      final path = entity.path.replaceAll(r'\', '/');
      // 生成物直接随目录一起删，不参与改写
      if (path.contains('/l10n/')) continue;
      // 工具脚本的测试（test/tool/**）刻意用 `l10n.` / `package:.../l10n/...` 当
      // fixture 喂给本脚本，属于测试数据，不是真实调用点，别把它们一起改了。
      if (path.startsWith('test/tool/')) continue;

      final content = entity.readAsStringSync().replaceAll('\r\n', '\n');
      if (_receiverPattern.hasMatch(content) ||
          _l10nDeclaration.hasMatch(content) ||
          _l10nImport.hasMatch(content) ||
          _l10nRelated.hasMatch(content)) {
        yield path;
      }
    }
  }
}

/// 小范围精确替换。
final List<Replacement> _l10nReplacements = <Replacement>[
  // ── failure_message：翻译不再需要 l10n 参数 ──
  const Replacement(
    'lib/core/ui/failure_message.dart',
    'localizedMessage 去掉 l10n 参数',
    '  String localizedMessage(AppLocalizations l10n) {',
    '  String localizedMessage() {',
  ),
  // ── error_text / profile_page：调用点同步去掉实参 ──
  const Replacement(
    'lib/core/ui/error_text.dart',
    'localizedMessage 调用去掉实参',
    'final Failure failure => failure.localizedMessage(l10n),',
    'final Failure failure => failure.localizedMessage(),',
  ),
  const Replacement(
    'lib/features/profile/page/profile_page.dart',
    'localizedMessage 调用去掉实参',
    'Text(error.localizedMessage(AppLocalizations.of(context)))',
    'Text(error.localizedMessage())',
  ),
  // ── pubspec：移除 l10n 相关依赖与开关 ──
  const Replacement(
    'pubspec.yaml',
    '移除 flutter_localizations 依赖',
    '  # ── 国际化（l10n） ──\n  flutter_localizations:\n    sdk: flutter\n',
    '',
  ),
  const Replacement(
    'pubspec.yaml',
    '移除 intl 依赖（只被 l10n 生成物使用）',
    '  intl: ^0.20.3\n',
    '',
  ),
  const Replacement(
    'pubspec.yaml',
    '关闭 generate（不再生成 AppLocalizations）',
    '  # 由 l10n.yaml 驱动，在 build / run 时生成 AppLocalizations\n  generate: true\n',
    '',
  ),
  // ── 文档目录树：去掉 l10n/ ──
  const Replacement(
    'README.md',
    'README 目录树去掉 l10n/',
    '├── l10n/                                   # 国际化文案（ARB + 生成物）\n'
        '│   ├── app_zh.arb                          #   模板语言：中文\n'
        '│   └── app_en.arb                          #   第二语言：英文\n'
        '│\n',
    '',
  ),
  const Replacement(
    '.trellis/spec/frontend/directory-structure.md',
    'spec 目录树去掉 l10n/',
    '├── l10n/                      # 国际化（见 localization.md）\n'
        '│   ├── app_zh.arb             #   模板语言：中文\n'
        '│   └── app_en.arb             #   第二语言：英文\n'
        '│\n',
    '',
  ),
  // ── 以下原在 _l10nRemovals 内，属精确替换，归位到此 ──
  const Replacement(
    'lib/core/config/user_preferences.dart',
    '移除只被语言加载使用的 logging import',
    "import 'package:my_app/core/logging/logging.dart';\n",
    '',
  ),
  const Replacement(
    'test/support/app_test_harness.dart',
    'wrapPage 去掉 locale 参数',
    "Widget wrapPage(Widget page, {Locale locale = const Locale('zh')}) {",
    'Widget wrapPage(Widget page) {',
  ),
  const Replacement(
    'test/support/app_test_harness.dart',
    '修正 wrapPage 文档注释',
    '/// 两件必须做的事：\n'
        '/// - 挂上 l10n delegate（页面通过 `AppLocalizations.of(context)` 取文案，缺了会空断言）\n'
        '/// - 用 `buildLightTheme()`（页面通过 `AppThemeExtension.of(context)!` 取圆角等 token）\n',
    '/// 必须做的事：用 `buildLightTheme()` —— 页面通过 `AppThemeExtension.of(context)!`\n'
        '/// 取圆角等 token，缺了会空断言。\n',
  ),
  const Replacement(
    'test/core/ui/failure_message_test.dart',
    '移除 l10n 的三个 import',
    "import 'package:my_app/l10n/app_localizations.dart';\n"
        "import 'package:my_app/l10n/app_localizations_en.dart';\n"
        "import 'package:my_app/l10n/app_localizations_zh.dart';\n",
    '',
  ),
  const Replacement(
    'test/core/ui/failure_message_test.dart',
    'localizedMessage 调用去掉实参',
    '.localizedMessage(zh)',
    '.localizedMessage()',
    all: true,
  ),
  const Replacement(
    'test/core/ui/failure_message_test.dart',
    '修正文件头注释',
    '/// Failure 只带 code，文案在这里翻译 —— 所以「切英文后错误提示是英文」\n'
        '/// 这件事就落在这一层，值得直接测。\n',
    '/// Failure 只带 code，文案在这里翻译；单语言形态下它只可能返回中文。\n',
  ),
  const Replacement(
    'test/features/demo/page/storage_demo_page_test.dart',
    'pumpPage 去掉 locale 形参与空命名参数块',
    "    WidgetTester tester, {\n    Locale locale = const Locale('zh'),\n"
        '  }) async {\n',
    '    WidgetTester tester,\n  ) async {\n',
  ),
  // 英文用例删掉后，这些测试文件只剩中文用例，material 里用到的 `Locale`
  // 也随之消失，import 变成未使用（warning，会让 analyze 门禁挂）。
  const Replacement(
    'test/features/home/page/home_page_test.dart',
    '移除未使用的 material import',
    "import 'package:flutter/material.dart';\n",
    '',
  ),
  // 语言选择器整块删掉后，主题相关的文档注释里指向已删符号的 `[...]` 成了
  // 悬空引用（`comment_references`，dart fix 不修），顺手改掉。
  const Replacement(
    'lib/features/profile/page/profile_page.dart',
    '去掉注释里对 _languageLabel 的引用',
    '  /// 与 [_languageLabel] 相反，主题名用当前界面语言书写（见 frontend/localization.md）\n',
    '  /// 主题名用当前界面语言书写（见 frontend/localization.md）\n',
  ),
  const Replacement(
    'lib/features/profile/page/profile_page.dart',
    '去掉注释里对 _LanguageChoice 的引用',
    '  /// 那样另立枚举把 null 让给「跟随系统」（见 [_LanguageChoice]）。\n',
    '  /// 那样另立枚举把 null 让给「跟随系统」。\n',
  ),
];
final List<Removal> _l10nRemovals = <Removal>[
  // ── app.dart：不再需要 locale / delegates ──
  const Removal(
    'lib/app/app.dart',
    '移除 locale 信号订阅',
    '    final Locale? locale = useSignalValue(preferences.locale);\n',
    '    final Locale? locale = useSignalValue(preferences.locale);\n',
  ),
  const Removal(
    'lib/app/app.dart',
    '移除 MaterialApp 的 locale / delegates',
    '      // locale 为 null 时跟随系统\n      locale: locale,\n',
    '      supportedLocales: AppLocalizations.supportedLocales,\n',
  ),

  // ── user_preferences.dart：语言偏好整体移除 ──
  const Removal(
    'lib/core/config/user_preferences.dart',
    '移除 locale 信号',
    '  /// 应用语言；`null` 表示跟随系统\n',
    '  final FlutterSignal<Locale?> locale = signal<Locale?>(null);\n',
  ),
  const Removal(
    'lib/core/config/user_preferences.dart',
    '移除 _keyLocale',
    "  static const String _keyLocale = 'app.locale';\n",
    "  static const String _keyLocale = 'app.locale';\n",
  ),
  const Removal(
    'lib/core/config/user_preferences.dart',
    '移除 _loadLocale 调用',
    '    _loadLocale();\n',
    '    _loadLocale();\n',
  ),
  const Removal(
    'lib/core/config/user_preferences.dart',
    '移除 _loadLocale 方法',
    '  /// 只接受 `supportedLocales` 内的值，脏数据回退到跟随系统\n',
    "      Logging.warning('本地保存的语言「\$code」不在支持范围内，已回退到跟随系统');\n    }\n  }\n",
  ),
  const Removal(
    'lib/core/config/user_preferences.dart',
    '移除 setLocale 方法',
    '  /// 传 `null` 表示跟随系统\n',
    '      unawaited(_prefs.setString(_keyLocale, value.languageCode));\n'
        '    }\n  }\n',
  ),

  // ── profile_page.dart：语言设置入口整体移除 ──
  const Removal(
    'lib/features/profile/page/profile_page.dart',
    '移除「设置 → 语言」入口',
    '                _SettingItem(\n'
        '                  icon: Icons.language_outlined,\n',
    '                _Divider(colorScheme: colorScheme),\n',
  ),
  const Removal(
    'lib/features/profile/page/profile_page.dart',
    '移除 locale 信号订阅',
    '    final Locale? locale = useSignalValue(preferences.locale);\n',
    '    final Locale? locale = useSignalValue(preferences.locale);\n',
  ),
  const Removal(
    'lib/features/profile/page/profile_page.dart',
    '移除 _languageLabel',
    '  /// 语言名用它自己的语言书写（见 frontend/localization.md）\n',
    '      _ => AppLocalizations.of(context).languageSystem,\n    };\n  }\n',
  ),
  const Removal(
    'lib/features/profile/page/profile_page.dart',
    '移除 _pickLanguage',
    '  /// 弹出语言选择，结果写入 UserPreferences（null = 跟随系统）\n',
    "      _LanguageChoice.english => const Locale('en'),\n    });\n  }\n",
  ),
  const Removal(
    'lib/features/profile/page/profile_page.dart',
    '移除 _LanguageChoice 枚举',
    '/// 语言选择项。不用 `null` 表示「跟随系统」',
    'enum _LanguageChoice { system, chinese, english }\n',
  ),

  // ── app_test_harness.dart：页面外壳不再挂 l10n delegate ──
  const Removal(
    'test/support/app_test_harness.dart',
    '移除 locale 传参',
    '    locale: locale,\n',
    '    locale: locale,\n',
  ),
  const Removal(
    'test/support/app_test_harness.dart',
    '移除 MaterialApp 的 delegates',
    '    localizationsDelegates: AppLocalizations.localizationsDelegates,\n',
    '    supportedLocales: AppLocalizations.supportedLocales,\n',
  ),

  // ── user_preferences_test.dart：语言相关的测试整组移除 ──
  const Removal(
    'test/core/config/user_preferences_test.dart',
    '移除「语言」测试组',
    "  group('UserPreferences — 语言', () {\n",
    '      expect(loaded.locale.value, isNull);\n    });\n  });\n\n',
  ),

  // ── failure_message_test.dart：只留中文，并去掉 l10n 实例 ──
  const Removal(
    'test/core/ui/failure_message_test.dart',
    '移除英文测试组',
    "  group('FailureMessage — 英文', () {\n",
    '\n  });\n',
  ),
  const Removal(
    'test/core/ui/failure_message_test.dart',
    '移除 l10n 实例',
    '  final zh = AppLocalizationsZh();\n',
    '  final en = AppLocalizationsEn();\n\n',
  ),

  // ── 以下为单语言下不再成立的「英文 / 语言」测试，整段删除 ──
  const Removal(
    'test/features/home/page/home_page_test.dart',
    '移除英文问候语测试',
    "    testWidgets('英文下问候语与兜底称呼都变英文', (tester) async {\n",
    '\n    });\n',
  ),
  const Removal(
    'test/features/home/page/home_page_test.dart',
    '移除英文区块文案测试',
    "    testWidgets('英文下这些区块也变英文', (tester) async {\n",
    '\n    });\n',
  ),
  const Removal(
    'test/features/auth/page/login_page_test.dart',
    '移除英文文案测试',
    "    testWidgets('英文语言下显示英文文案', (tester) async {\n",
    '\n    });\n',
  ),
  const Removal(
    'test/features/article/page/article_list_page_test.dart',
    '移除英文错误文案测试',
    "    testWidgets('英文下显示英文错误文案（同一个 Failure）', (tester) async {\n",
    '\n    });\n',
  ),
  const Removal(
    'test/features/profile/page/profile_page_test.dart',
    '移除英文标题/设置项测试',
    "    testWidgets('英文语言下标题与设置项都是英文', (tester) async {\n",
    '\n    });\n',
  ),
  const Removal(
    'test/features/profile/page/profile_page_test.dart',
    '移除语言选择器整组',
    "  group('ProfilePage — 语言选择器', () {\n",
    '\n  });\n',
  ),
  const Removal(
    'test/features/profile/page/profile_page_test.dart',
    '移除英文主题文案测试',
    "    testWidgets('英文界面下主题文案也是英文', (tester) async {\n",
    '\n    });\n',
  ),
  const Removal(
    'test/features/demo/page/storage_demo_page_test.dart',
    '移除英文整页测试',
    "    testWidgets('英文语言下整页都是英文', (tester) async {\n",
    '\n    });\n',
  ),
];
