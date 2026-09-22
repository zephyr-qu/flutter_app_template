import 'package:flutter_test/flutter_test.dart';

import '../../tool/check_coverage.dart';

/// 覆盖率门禁是脚本 + 纯函数，所以能用普通 `test()` 覆盖，
/// 不必真的跑一遍 `flutter test --coverage`。同 `check_boundaries_test.dart`。
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
}
