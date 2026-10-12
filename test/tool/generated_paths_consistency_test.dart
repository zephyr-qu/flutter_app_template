import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/generated_paths.dart' as tool;

// 为什么有这个测试（生成物口径的漂移防线）：
// 「哪些文件是生成物」有三处口径：根 `.gitignore`（决定谁不入库）、
// `tool/generated_paths.dart`（决定门禁扫描面）、`packages/app_lints/lib/src/paths.dart`
// （决定插件豁免）。三处必须一致，但此前没有任何断言 —— 改一处漏另两处，
// 规则照旧全绿。这里把 `.gitignore` 的生成物段落当**唯一真源**，归一成谓词集合，
// 与两份 Dart 实现抽取的谓词集合互相比对；任何一处漂移都点名具体差异。
// 不引入第三份长期维护的样例表（那只是又一个副本，抓不到漂移），
// 只用三条转换规则把 `.gitignore` 翻成谓词（见 cross-cutting.md「代码生成与生成物」）。

/// 归一化后的单条谓词，与两份 Dart 实现的写法同构。
///
/// 用 record 而非类：值相等由语言给，测试里可以直接比较集合。
typedef GeneratedPredicate = ({String kind, String argument});

const String _isGeneratedPathSignature = 'bool isGeneratedPath(String path) =>';

void main() {
  group('parseGitignoreGeneratedPatterns', () {
    test('取注释头到下一个注释行之间的模式', () {
      const gitignore = '''
# 别的段落
*.log

# 代码生成物：不入库，clone 后跑 `just codegen`。
# 口径与 packages/app_lints 的 isGeneratedPath() 对齐；策略见
# .trellis/spec/cross-cutting.md「代码生成与生成物」。
*.g.dart
*.freezed.dart
# Platform specific
**/ios/Pods/
''';

      expect(parseGitignoreGeneratedPatterns(gitignore), [
        '*.g.dart',
        '*.freezed.dart',
      ]);
    });

    test('找不到注释头 → 空列表（调用方 fail）', () {
      expect(parseGitignoreGeneratedPatterns('*.log\n'), isEmpty);
    });
  });

  group('gitignorePredicate', () {
    test('`*.g.dart` → endsWith(.g.dart)', () {
      expect(gitignorePredicate('*.g.dart'), (
        kind: 'endsWith',
        argument: '.g.dart',
      ));
    });

    test('`**/gen/` → contains(/gen/)', () {
      expect(gitignorePredicate('**/gen/'), (
        kind: 'contains',
        argument: '/gen/',
      ));
    });

    test('`*app_localizations*` → contains(app_localizations)', () {
      expect(gitignorePredicate('*app_localizations*'), (
        kind: 'contains',
        argument: 'app_localizations',
      ));
    });

    test('认不出的形态 → null（调用方 fail）', () {
      expect(gitignorePredicate('build/**'), isNull);
    });
  });

  group('parseDartPredicates', () {
    test('抽 endsWith / contains 谓词项', () {
      const source = '''
    path.endsWith('.g.dart') ||
    path.contains('/gen/') ||
    path.contains('app_localizations');''';

      expect(parseDartPredicates(source), {
        (kind: 'endsWith', argument: '.g.dart'),
        (kind: 'contains', argument: '/gen/'),
        (kind: 'contains', argument: 'app_localizations'),
      });
    });
  });

  group('extractFunctionBody', () {
    test('从签名到第一个分号', () {
      const source = '''
bool isGeneratedPath(String path) =>
    path.endsWith('.g.dart') ||
    path.contains('/gen/');

// 后面的内容不算
void other() {}
''';

      final body = extractFunctionBody(source, _isGeneratedPathSignature);

      expect(body, isNotNull);
      expect(body, contains("path.endsWith('.g.dart')"));
      expect(body, isNot(contains('void other')));
    });

    test('签名不存在 → null', () {
      expect(
        extractFunctionBody('void x() {}', _isGeneratedPathSignature),
        isNull,
      );
    });
  });

  group('仓库现状（读真实文件）', () {
    final gitignore = File('.gitignore').readAsStringSync();
    final toolSource = File('tool/generated_paths.dart').readAsStringSync();
    final pluginSource = File('packages/app_lints/lib/src/paths.dart')
        .readAsStringSync();

    /// `.gitignore` 生成物段落归一化出的谓词集合；无法归一化的模式显式失败。
    Set<GeneratedPredicate> gitignorePredicates() {
      final patterns = parseGitignoreGeneratedPatterns(gitignore);
      expect(
        patterns,
        isNotEmpty,
        reason:
            '根 .gitignore 里找不到「代码生成物」段落 '
            '（注释头 `# 代码生成物：不入库`）——\n'
            '段落被改名 / 删掉了，这条口径守卫随之失明。',
      );

      final unparsed = <String>[];
      final predicates = <GeneratedPredicate>{};
      for (final pattern in patterns) {
        final predicate = gitignorePredicate(pattern);
        if (predicate == null) {
          unparsed.add(pattern);
        } else {
          predicates.add(predicate);
        }
      }

      expect(
        unparsed,
        isEmpty,
        reason:
            '.gitignore 的生成物模式有认不出的形态：${unparsed.join('、')}\n'
            '归一化规则只认 `*.x` / `**/x/` / `*x*` 三种； '
            '出现新形态时要同步扩展本测试。',
      );

      return predicates;
    }

    Set<GeneratedPredicate> dartPredicates(String source, String label) {
      final body = extractFunctionBody(source, _isGeneratedPathSignature);
      expect(
        body,
        isNotNull,
        reason:
            '$label 里找不到 `$_isGeneratedPathSignature` —— '
            '函数被改名 / 搬走了。',
      );

      final predicates = parseDartPredicates(body!);
      expect(
        predicates,
        isNotEmpty,
        reason: '$label 的 isGeneratedPath 里没抽到任何谓词项 —— 解析正则脱节了。',
      );

      return predicates;
    }

    test('D2：三处谓词集合一致', () {
      final fromGitignore = gitignorePredicates();
      final fromTool = dartPredicates(toolSource, 'tool/generated_paths.dart');
      final fromPlugin = dartPredicates(
        pluginSource,
        'packages/app_lints/lib/src/paths.dart',
      );

      expect(
        fromTool,
        equals(fromGitignore),
        reason:
            'tool/generated_paths.dart 与根 .gitignore 的生成物口径对不上：\n'
            '${_diffPredicates('只在 tool 实现出现', fromTool, fromGitignore)}\n'
            '${_diffPredicates('只在 .gitignore 出现', fromGitignore, fromTool)}',
      );
      expect(
        fromPlugin,
        equals(fromGitignore),
        reason:
            'packages/app_lints/lib/src/paths.dart 与根 .gitignore 的生成物 '
            '口径对不上：\n'
            '${_diffPredicates('只在 plugin 实现出现', fromPlugin, fromGitignore)}\n'
            '${_diffPredicates('只在 .gitignore 出现', fromGitignore, fromPlugin)}',
      );
    });

    test('D4：样例路径上三处判定返回值一致', () {
      final fromGitignore = gitignorePredicates();
      final fromPlugin = dartPredicates(
        pluginSource,
        'packages/app_lints/lib/src/paths.dart',
      );

      for (final path in _samplePaths) {
        final expected = tool.isGeneratedPath(path);
        final gitignoreResult = fromGitignore.any(
          (predicate) => _predicateMatches(predicate, path),
        );
        final pluginResult = fromPlugin.any(
          (predicate) => _predicateMatches(predicate, path),
        );

        expect(
          gitignoreResult,
          expected,
          reason:
              '样例路径 `$path`：`.gitignore` 归一化判定为 $gitignoreResult， '
              '而 tool/generated_paths.dart 判定为 $expected。',
        );
        expect(
          pluginResult,
          expected,
          reason:
              '样例路径 `$path`：plugin 实现判定为 $pluginResult， '
              '而 tool/generated_paths.dart 判定为 $expected。',
        );
      }
    });
  });
}

/// 根 `.gitignore` 生成物段落里的模式行。
///
/// 段落由注释头 `# 代码生成物：不入库` 界定；跳过紧随其后的注释行，
/// 从第一条模式行开始收集，遇到下一个注释行或空行结束。
/// 找不到注释头返回空列表 —— 调用方必须显式 fail。
List<String> parseGitignoreGeneratedPatterns(String gitignore) {
  final lines = const LineSplitter().convert(gitignore);
  final start = lines.indexWhere(
    (line) => line.trimLeft().startsWith('# 代码生成物：不入库'),
  );
  if (start < 0) return const [];

  final patterns = <String>[];
  var collecting = false;

  for (var index = start + 1; index < lines.length; index++) {
    final line = lines[index].trim();
    if (line.startsWith('#')) {
      if (collecting) break;
      continue;
    }
    if (line.isEmpty) {
      if (collecting) break;
      continue;
    }
    collecting = true;
    patterns.add(line);
  }

  return patterns;
}

/// 把 `.gitignore` 的生成物模式归一成单谓词；认不出的形态返回 null。
///
/// 只覆盖现有的三种形态：`*.x` → `endsWith('.x')`、
/// `**/x/` → `contains('/x/')`、`*x*` → `contains('x')`。
GeneratedPredicate? gitignorePredicate(String pattern) {
  final value = pattern.trim();
  if (value.isEmpty || value.startsWith('#')) return null;

  final dirPattern = RegExp(r'^\*\*/(.+)/$').firstMatch(value);
  if (dirPattern != null) {
    return (kind: 'contains', argument: '/${dirPattern.group(1)}/');
  }

  final wrapped = RegExp(r'^\*(.+)\*$').firstMatch(value);
  if (wrapped != null) {
    return (kind: 'contains', argument: wrapped.group(1)!);
  }

  if (value.startsWith('*') && value.indexOf('*', 1) == -1) {
    return (kind: 'endsWith', argument: value.substring(1));
  }

  return null;
}

/// 从 Dart 源码里抽 `path.endsWith('…')` / `path.contains('…')` 谓词项。
Set<GeneratedPredicate> parseDartPredicates(String source) =>
    RegExp(r"path\.(endsWith|contains)\('([^']*)'\)")
        .allMatches(source)
        .map((match) {
          return (kind: match.group(1)!, argument: match.group(2)!);
        })
        .toSet();

/// 从函数签名到第一个 `;` 的正文；签名不存在返回 null。
String? extractFunctionBody(String source, String signature) {
  final start = source.indexOf(signature);
  if (start < 0) return null;

  final end = source.indexOf(';', start);
  if (end < 0) return null;

  return source.substring(start, end);
}

/// 按归一化谓词判断一条路径是不是生成物。
bool _predicateMatches(GeneratedPredicate predicate, String path) =>
    predicate.kind == 'endsWith'
    ? path.endsWith(predicate.argument)
    : path.contains(predicate.argument);

/// 覆盖各种形态的样例路径（生成物与非生成物都要有）。
const List<String> _samplePaths = [
  'lib/main.dart',
  'lib/features/a/logic/a.dart',
  'lib/features/a/data/a.g.dart',
  'lib/features/a/data/a.freezed.dart',
  'lib/features/a/data/a.gr.dart',
  'lib/features/a/di.config.dart',
  'lib/features/a/gen/assets.gen.dart',
  'lib/features/a/gen/x.dart',
  'gen/foo.dart',
  'lib/l10n/app_localizations.dart',
  'lib/l10n/app_localizations_en.dart',
  'lib/foo_gen.dart',
];

/// 描述 [a] 里比 [b] 多出的谓词项，用于失败信息点名差异。
String _diffPredicates(
  String label,
  Set<GeneratedPredicate> a,
  Set<GeneratedPredicate> b,
) {
  final extra = a.difference(b).map(_predicateLabel).toList()..sort();
  return extra.isEmpty ? '$label：无' : '$label：${extra.join('、')}';
}

String _predicateLabel(GeneratedPredicate predicate) =>
    '${predicate.kind}(${predicate.argument})';
