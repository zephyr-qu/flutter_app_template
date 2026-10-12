import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// 为什么有这个测试（`packages/app_lints` 插件的接线防线）：
// 规则本身写对了，不代表插件真的被加载、真的被注册、文档真的跟得上。
// 「插件没加载」这类失效全是静默的：`dart analyze` 照常退出 0，门禁毫无差别。
// 所以这里钉四条静态断言（都不 spawn `dart analyze`，见 cross-cutting.md
// 「架构边界与代码形态」）：
//   W1 `analysis_options.yaml` 的 `plugins.app_lints.path` 指向真实入口
//   W2 注册的规则集合 == `rules.dart` 里声明的具体规则类集合
//   W3 `LintCode` 名字集合 == cross-cutting.md 规则表格里的清单
//   W4 插件单测的 locator 桩形态 == 生产代码 `lib/di/service_locator.dart` 的形态
// 每条解析不到都显式 fail，失败信息点名「哪一处对不上」。

void main() {
  group('parsePluginPath', () {
    test('取顶层 plugins 块里的 app_lints.path', () {
      const yaml = '''
plugins:
  app_lints:
    path: packages/app_lints
''';

      expect(parsePluginPath(yaml), 'packages/app_lints');
    });

    test('注释与其它顶层键不干扰', () {
      const yaml = '''
# plugins:
linter:
  rules:
    public_member_api_docs: false

plugins:
  app_lints:
    path: packages/app_lints

# trailing comment
analyzer:
  errors:
''';

      expect(parsePluginPath(yaml), 'packages/app_lints');
    });

    test('解析不到 → null（调用方负责 fail，不静默通过）', () {
      expect(parsePluginPath('linter:\n  rules:\n'), isNull);
    });
  });

  group('parseRegisteredRules / parseDeclaredRules', () {
    test('注册行取类名', () {
      const main = '''
    registry
      ..registerWarningRule(CoreImportsRule())
      ..registerWarningRule(LogicImportsMaterialRule());
''';

      expect(parseRegisteredRules(main), [
        'CoreImportsRule',
        'LogicImportsMaterialRule',
      ]);
    });

    test('注释行不参与', () {
      const main = '''
    registry
      ..registerWarningRule(CoreImportsRule())
      // ..registerWarningRule(PageInjectionPointRule());
''';
      expect(parseRegisteredRules(main), ['CoreImportsRule']);
    });

    test('具体规则类 = extends AnalysisRule / _ImportRule，排除下划线基类', () {
      const rules = '''
class CoreImportsRule extends _ImportRule {}

abstract class _ImportRule extends AnalysisRule {}

class CommentBlockTooLongRule extends AnalysisRule {}
''';

      expect(parseDeclaredRules(rules), [
        'CoreImportsRule',
        'CommentBlockTooLongRule',
      ]);
    });
  });

  group('parseLintCodeNames / parseSpecRuleTable', () {
    test('注释掉的 LintCode 不算', () {
      const rules = '''
  static const LintCode code = LintCode('a_rule', 'x');
  // static const LintCode other = LintCode('b_rule', 'y');
''';
      expect(parseLintCodeNames(rules), ['a_rule']);
    });

    test('取 LintCode 的第一个字符串实参', () {
      const rules = '''
  static const LintCode code = LintCode(
    'no_service_locator_in_logic',
    '说明',
  );

  static const LintCode other = LintCode('avoid_async_state_map', 'x');
''';

      expect(parseLintCodeNames(rules), [
        'no_service_locator_in_logic',
        'avoid_async_state_map',
      ]);
    });

    test('只取「架构边界与代码形态」小节的第一张表', () {
      const spec = '''
## 架构边界与代码形态

| 规则 | 效果 |
|------|------|
| `a_rule` | x |
| `b_rule` | y |

| 想看什么 | 文件 |
|---|---|
| `not_a_rule` | z |

## 有意不设的项

| 不设 | 为什么 |
|------|------|
| `dart pub outdated` | w |
''';

      expect(parseSpecRuleTable(spec), ['a_rule', 'b_rule']);
    });

    test('无该小节 → 空列表（调用方 fail）', () {
      expect(parseSpecRuleTable('# 别的文档\n'), isEmpty);
    });
  });

  group('locatorShape / extractConstBlock', () {
    test('对象形态', () {
      expect(locatorShape('final GetIt getIt = GetIt.instance;\n'), 'object');
    });

    test('函数形态', () {
      expect(locatorShape('T getIt<T>() => _zero as T;\n'), 'function');
    });

    test('跳过注释行', () {
      const text = '''
/// 生产代码里 `getIt` 是对象（`final GetIt getIt = GetIt.instance;`）
final GetIt getIt = GetIt.instance;
''';

      expect(locatorShape(text), 'object');
    });

    test('抽出 const 桩块', () {
      const source = '''
const String _locatorStub = \'\'\'
final GetIt getIt = GetIt.instance;
\'\'\';

const String other = 'x';
''';
      final block = extractConstBlock(source, '_locatorStub');

      expect(block, isNotNull);
      expect(block, contains('final GetIt getIt = GetIt.instance;'));
    });
  });

  group('仓库现状（读真实文件）', () {
    final analysisOptions = File('analysis_options.yaml').readAsStringSync();
    final rulesDart = File('packages/app_lints/lib/src/rules.dart')
        .readAsStringSync();
    final mainDart = File('packages/app_lints/lib/main.dart')
        .readAsStringSync();
    final spec = File('.trellis/spec/cross-cutting.md').readAsStringSync();

    test('W1：plugins.app_lints.path 存在且含 lib/main.dart', () {
      final path = parsePluginPath(analysisOptions);
      expect(
        path,
        isNotNull,
        reason:
            '没能从根 analysis_options.yaml 解析出 plugins.app_lints.path ——\n'
            '插件根本没被声明，`dart analyze` 不会加载它，七条规则全部空转。\n'
            '解析正则与文件写法脱节时也要在这里显式失败，不要退化成静默通过。',
      );

      final dir = Directory(path!);
      expect(
        dir.existsSync(),
        isTrue,
        reason:
            'plugins.app_lints.path 指向 `$path`，但该目录不存在 ——\n'
            '插件不会被加载，门禁对架构边界零覆盖。',
      );
      expect(
        File('$path/lib/main.dart').existsSync(),
        isTrue,
        reason:
            '`$path` 存在，但缺 `lib/main.dart` —— 插件入口不在，\n'
            'analysis server 找不到顶层 `plugin` 变量。',
      );
    });

    test('W2：注册的规则集合 == rules.dart 声明的具体规则类集合', () {
      final registered = parseRegisteredRules(mainDart).toSet();
      final declared = parseDeclaredRules(rulesDart).toSet();

      expect(
        declared,
        isNotEmpty,
        reason: '没能从 rules.dart 解析出任何具体规则类 —— 解析正则与源码写法脱节了。',
      );
      expect(
        registered,
        isNotEmpty,
        reason: '没能从 main.dart 解析出任何 registerWarningRule 调用 —— 解析正则脱节了。',
      );

      final registeredOnly = _diff('只在 main.dart 注册', registered, declared);
      final declaredOnly = _diff('只在 rules.dart 声明', declared, registered);

      expect(
        registered,
        equals(declared),
        reason:
            '插件注册的规则与 rules.dart 声明的规则对不上：\n'
            '$registeredOnly\n'
            '$declaredOnly\n'
            '漏注册 = 规则写了但从不生效；注册了不存在的类 = 编译不过。',
      );
    });

    test('W3：LintCode 名字集合 == cross-cutting.md 规则表格清单', () {
      final codes = parseLintCodeNames(rulesDart).toSet();
      final documented = parseSpecRuleTable(spec).toSet();

      expect(
        codes,
        isNotEmpty,
        reason: '没能从 rules.dart 解析出任何 LintCode 名字 —— 解析正则脱节了。',
      );
      expect(
        documented,
        isNotEmpty,
        reason:
            '没能从 cross-cutting.md「架构边界与代码形态」表格解析出规则名 ——\n'
            '解析正则脱节，或那张表已改名 / 被删。',
      );

      final codeOnly = _diff('只在 rules.dart', codes, documented);
      final documentedOnly = _diff('只在 spec 表格', documented, codes);

      expect(
        codes,
        equals(documented),
        reason:
            '规则名与 spec 表格对不上：\n'
            '$codeOnly\n'
            '$documentedOnly\n'
            '规则改名后文档漂移就发生在这里。',
      );
    });

    test('W4：locator 桩形态 == 生产声明形态，且生产侧是对象', () {
      final production = File('lib/di/service_locator.dart').readAsStringSync();
      final tests = File('packages/app_lints/test/rules_test.dart')
          .readAsStringSync();

      final productionShape = locatorShape(production);
      final stubBlock = extractConstBlock(tests, '_locatorStub');
      final stubShape = stubBlock == null ? null : locatorShape(stubBlock);

      expect(
        productionShape,
        isNotNull,
        reason:
            '没能从 lib/di/service_locator.dart 认出 `getIt` 的声明形态 ——\n'
            '生产形态变了（对象 / 函数 / 其它），规则判据与插件单测的桩要一起改。',
      );
      expect(
        productionShape,
        'object',
        reason:
            '生产代码的 `getIt` 不再是「对象」形态（当前识别为 `$productionShape`）。\n'
            '对象形态走的隐式 `call` 会解析成 FunctionExpressionInvocation ——\n'
            '规则判据与单测桩必须一起改，否则规则再次对生产代码静默失效。',
      );
      expect(
        stubShape,
        isNotNull,
        reason:
            '没能从 rules_test.dart 的 `_locatorStub` 认出 locator 形态 ——\n'
            '桩的形状变了，或者常量名被改了。',
      );
      expect(
        stubShape,
        productionShape,
        reason:
            '插件单测的 locator 桩形态（`$stubShape`）与生产代码（`$productionShape`）不一致。\n'
            '桩退回函数形态时，规则的真实判据就脱离覆盖 —— 那正是 F1 复发的形态。',
      );
    });
  });
}

/// 从根 `analysis_options.yaml` 的顶层 `plugins:` 块里取出 `app_lints.path`。
///
/// 只解析这一段，不引入 yaml 依赖。解析不到返回 null —— 调用方必须显式 fail。
String? parsePluginPath(String yaml) {
  var inPlugins = false;
  var inAppLints = false;

  for (final line in const LineSplitter().convert(yaml)) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;

    final indent = line.length - line.trimLeft().length;
    if (trimmed == 'plugins:') {
      inPlugins = true;
      inAppLints = false;
      continue;
    }
    if (!inPlugins) continue;
    if (indent == 0) {
      inPlugins = false;
      continue;
    }
    if (indent == 2 && trimmed.endsWith(':')) {
      inAppLints = trimmed == 'app_lints:';
      continue;
    }
    if (inAppLints) {
      final match = RegExp(r'^path:\s*(\S+)\s*$').firstMatch(trimmed);
      if (match != null) return match.group(1);
    }
  }

  return null;
}

/// `main.dart` 里 `registerWarningRule(<XxxRule>())` 的类名列表。
///
/// 注释行不参与：把一条注册注释掉时集合必须真的变小，否则这条断言测不出漏注册。
List<String> parseRegisteredRules(String mainDart) =>
    RegExp(r'registerWarningRule\(\s*([A-Za-z_]\w*)\s*\(\s*\)\s*\)')
        .allMatches(_withoutCommentLines(mainDart))
        .map((match) => match.group(1)!)
        .toList();

/// `rules.dart` 里具体规则类的类名（`extends AnalysisRule` / `_ImportRule`），
/// 排除下划线开头的抽象基类。注释行不参与。
List<String> parseDeclaredRules(String rulesDart) =>
    RegExp(r'class\s+([A-Za-z_]\w*)\s+extends\s+(?:_ImportRule|AnalysisRule)\b')
        .allMatches(_withoutCommentLines(rulesDart))
        .map((match) => match.group(1)!)
        .where((name) => !name.startsWith('_'))
        .toList();

/// `rules.dart` 里全部 `LintCode('<name>', …)` 的名字。注释行不参与。
List<String> parseLintCodeNames(String rulesDart) =>
    RegExp(r"LintCode\(\s*'([a-z0-9_]+)'")
        .allMatches(_withoutCommentLines(rulesDart))
        .map((match) => match.group(1)!)
        .toList();

/// 把整行注释（`//` / `///` / `*` / `/*`）抹成空行，保留行数。
///
/// 不自作主张剥行尾注释（字符串里的 `//` 会被误伤）；把整行注释掉是本仓库的写法。
String _withoutCommentLines(String source) => const LineSplitter()
    .convert(source)
    .map((line) {
      final trimmed = line.trimLeft();
      final isComment =
          trimmed.startsWith('//') ||
          trimmed.startsWith('*') ||
          trimmed.startsWith('/*');
      return isComment ? '' : line;
    })
    .join('\n');

/// cross-cutting.md「架构边界与代码形态」小节第一张表里 `` | `name` | `` 形态的规则名。
///
/// 只取这张表：本文件里还有别的表格（生成物形态、供应链），它们的首列不是规则名。
List<String> parseSpecRuleTable(String spec) {
  final lines = const LineSplitter().convert(spec);
  final start = lines.indexWhere((line) => line.startsWith('## 架构边界与代码形态'));
  if (start < 0) return const [];

  final names = <String>[];
  var inTable = false;

  for (var index = start + 1; index < lines.length; index++) {
    final line = lines[index];
    if (line.startsWith('## ')) break;

    if (line.startsWith('|')) {
      inTable = true;
      final match = RegExp(r'^\|\s*`([a-z0-9_]+)`\s*\|').firstMatch(line);
      if (match != null) names.add(match.group(1)!);
      continue;
    }
    if (inTable) break;
  }

  return names;
}

/// `getIt` 的声明形态：`object`（变量 + 初始化）或 `function`（函数声明）。
///
/// 逐行扫描并跳过注释行；认不出返回 null（调用方 fail）。
String? locatorShape(String text) {
  for (final line in const LineSplitter().convert(text)) {
    final trimmed = line.trimLeft();
    if (trimmed.startsWith('//') || trimmed.startsWith('*')) continue;
    if (!RegExp(r'\bgetIt\b').hasMatch(line)) continue;
    if (RegExp(r'\bgetIt\s*=').hasMatch(line)) return 'object';
    if (RegExp(r'\bgetIt\s*[<(]').hasMatch(line)) return 'function';
  }

  return null;
}

/// 抽出 `const String <name> = '''…''';` 的正文；解析不到返回 null。
String? extractConstBlock(String source, String name) {
  final marker = "const String $name = '''";
  final start = source.indexOf(marker);
  if (start < 0) return null;

  final bodyStart = start + marker.length;
  final end = source.indexOf("''';", bodyStart);
  if (end < 0) return null;

  return source.substring(bodyStart, end);
}

/// 描述 [a] 里比 [b] 多出的项，用于失败信息点名差异。
String _diff(String label, Set<String> a, Set<String> b) {
  final extra = a.difference(b).toList()..sort();
  return extra.isEmpty ? '$label：无' : '$label：${extra.join('、')}';
}
