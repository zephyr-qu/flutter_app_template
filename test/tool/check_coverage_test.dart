import 'package:flutter_test/flutter_test.dart';

import '../../tool/check_coverage.dart';

/// 覆盖率门禁是脚本 + 纯函数，所以能用普通 `test()` 覆盖，
/// 不必真的跑一遍 `flutter test --coverage`。
void main() {
  group('parseLcov', () {
    test('解析 SF / LF / LH 三段', () {
      const lcov = '''
SF:lib/core/base/failure.dart
DA:1,1
LF:10
LH:8
end_of_record
SF:lib/core/base/result.dart
LF:4
LH:1
end_of_record
''';

      final files = parseLcov(lcov);

      expect(files, hasLength(2));
      expect(files.first.path, 'lib/core/base/failure.dart');
      expect(files.first.hit, 8);
      expect(files.first.found, 10);
      expect(files.last.ratio, moreOrLessEquals(0.25));
    });

    test('Windows 反斜杠路径统一成正斜杠', () {
      const lcov =
          'SF:lib\\core\\base\\failure.dart\nLF:2\nLH:2\nend_of_record';

      expect(parseLcov(lcov).single.path, 'lib/core/base/failure.dart');
    });

    test('缺少 LH / LF 时按 0 处理，不会抛', () {
      final files = parseLcov('SF:lib/a.dart\nLF:3\nend_of_record');

      expect(files.single.hit, 0);
      expect(files.single.found, 3);
    });

    test('没有 end_of_record 的残缺段落被忽略', () {
      const lcov = 'SF:lib/a.dart\nLF:3\nLH:1\n';

      expect(parseLcov(lcov), isEmpty);
    });
  });

  group('handwrittenOnly', () {
    test('剔除各类生成文件', () {
      final files = parseLcov('''
SF:lib/core/models/user.g.dart
LF:5
LH:5
end_of_record
SF:lib/features/auth/data/models/login_response.freezed.dart
LF:20
LH:10
end_of_record
SF:lib/di/service_locator.config.dart
LF:3
LH:3
end_of_record
SF:lib/app/routing/router.gr.dart
LF:4
LH:2
end_of_record
SF:lib/l10n/app_localizations.dart
LF:2
LH:2
end_of_record
SF:lib/core/base/failure.dart
LF:10
LH:10
end_of_record
''');

      final handwritten = handwrittenOnly(files);

      expect(handwritten, hasLength(1));
      expect(handwritten.single.path, 'lib/core/base/failure.dart');
    });
  });

  group('lineCoverage', () {
    test('按行数加权，而不是按文件平均', () {
      final files = [
        const FileCoverage(path: 'lib/a.dart', hit: 1, found: 1), // 100%
        const FileCoverage(path: 'lib/b.dart', hit: 0, found: 99), // 0%
      ];

      expect(lineCoverage(files), moreOrLessEquals(1));
    });

    test('没有可统计的行时视为 100%', () {
      expect(lineCoverage(const []), 100);
    });
  });

  group('lowestCovered', () {
    test('按覆盖率升序取前 N 个', () {
      final files = [
        const FileCoverage(path: 'lib/high.dart', hit: 9, found: 10),
        const FileCoverage(path: 'lib/zero.dart', hit: 0, found: 10),
        const FileCoverage(path: 'lib/mid.dart', hit: 5, found: 10),
      ];

      final lowest = lowestCovered(files, 2);

      expect(lowest.map((f) => f.path), ['lib/zero.dart', 'lib/mid.dart']);
    });
  });

  // ── 差集检查（--src）──
  group('coversPath', () {
    test('完全相同即覆盖', () {
      expect(coversPath('lib/a.dart', 'lib/a.dart'), isTrue);
    });

    test('SF 是相对包根的路径：按完整路径段后缀匹配', () {
      expect(
        coversPath(
          'vendor/core/lib/data/token_store.dart',
          'lib/data/token_store.dart',
        ),
        isTrue,
      );
    });

    test('后缀必须落在路径段边界上', () {
      // 少了这个边界，xlib/a.dart 会被 lib/a.dart 误判成已覆盖
      expect(coversPath('xlib/a.dart', 'lib/a.dart'), isFalse);
      expect(coversPath('vendor/core/xlib/a.dart', 'lib/a.dart'), isFalse);
    });

    test('文件名相同但目录不同不算覆盖', () {
      expect(coversPath('lib/other/a.dart', 'lib/a.dart'), isFalse);
    });
  });

  group('missingFrom', () {
    test('返回扫描到但没被 lcov 记录的文件', () {
      final missing = missingFrom(
        handwritten: ['lib/a.dart', 'lib/b.dart', 'lib/c.dart'],
        covered: [
          const FileCoverage(path: 'lib/a.dart', hit: 1, found: 1),
          const FileCoverage(path: 'lib/c.dart', hit: 1, found: 1),
        ],
      );

      expect(missing, ['lib/b.dart']);
    });

    test('结果排序，输出稳定', () {
      final missing = missingFrom(
        handwritten: ['lib/z.dart', 'lib/a.dart', 'lib/m.dart'],
        covered: const <FileCoverage>[],
      );

      expect(missing, ['lib/a.dart', 'lib/m.dart', 'lib/z.dart']);
    });

    test('全部缺失时返回全部', () {
      final missing = missingFrom(
        handwritten: ['lib/unloaded/x.dart'],
        covered: [const FileCoverage(path: 'lib/y.dart', hit: 0, found: 9)],
      );

      expect(missing, ['lib/unloaded/x.dart']);
    });
  });

  group('nonBlankLines', () {
    test('空行与纯空白行不计入', () {
      const content = 'a\n\n   \nb\n\t\nc\n';

      expect(nonBlankLines(content), 3);
    });

    test('空文件为 0', () {
      expect(nonBlankLines(''), 0);
    });
  });

  group('withUnloaded', () {
    test('未加载文件按 0 命中并入，行数取代理值', () {
      final files = withUnloaded(
        files: [const FileCoverage(path: 'lib/covered.dart', hit: 5, found: 5)],
        unloadedLines: {'lib/never_loaded.dart': 40},
      );

      expect(files, hasLength(2));
      expect(files.last.path, 'lib/never_loaded.dart');
      expect(files.last.hit, 0);
      expect(files.last.found, 40);
      // 分母涨了，比例必然被拉下来 —— 这正是差集检查的意义
      expect(lineCoverage(files), moreOrLessEquals(5 * 100 / 45));
    });

    test('没有未加载文件时原样返回', () {
      final files = withUnloaded(
        files: [const FileCoverage(path: 'lib/a.dart', hit: 1, found: 1)],
        unloadedLines: const {},
      );

      expect(lineCoverage(files), moreOrLessEquals(100));
    });
  });

  group('unexemptedFiles / staleExemptions', () {
    const exemptions = {'lib/main.dart': '入口，只被集成测试加载'};

    test('豁免条目不进分母', () {
      final unexempted = unexemptedFiles([
        'lib/main.dart',
        'lib/forgotten.dart',
      ], exemptions: exemptions);

      expect(unexempted, ['lib/forgotten.dart']);
    });

    test('挂在扫描根下、已不再缺失的豁免算过期', () {
      final stale = staleExemptions(
        missing: const ['lib/forgotten.dart'],
        scanRoot: 'lib',
        exemptions: exemptions,
      );

      expect(stale, ['lib/main.dart']);
    });

    test('别的扫描根下的豁免不算过期（否则每份 lcov 都会误报）', () {
      final stale = staleExemptions(
        missing: const <String>[],
        scanRoot: 'tool',
        exemptions: exemptions,
      );

      expect(stale, isEmpty);
    });

    test('仍然缺失的豁免不算过期', () {
      final stale = staleExemptions(
        missing: const ['lib/main.dart'],
        scanRoot: 'lib',
        exemptions: exemptions,
      );

      expect(stale, isEmpty);
    });

    test('扫描根边界：lib 不该管到 libx/ 下的文件', () {
      final stale = staleExemptions(
        missing: const <String>[],
        scanRoot: 'lib',
        exemptions: const {'libx/a.dart': '无关'},
      );

      expect(stale, isEmpty);
    });
  });
}
