import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/init_project.dart';

// ──────────────────────────────────────────────
// fixture 的取名与路径
// ──────────────────────────────────────────────
//
// fixture 的包名与类名是**测试自己的常量**，与仓库当前叫什么无关。
//
// 因此这里刻意不写字面量：仓库自己被改名时，`tool/init_project.dart` 会重写所有
// `.dart` 文件里的 `package:<当前名>/` 与整词出现的旧根组件类名 —— 字面量会被改掉，
// 而 `_plan` 不会。两边一旦失配，这份测试在「刚被改名的新仓库」里就是自己骂自己。
// 做法：包名一律经 [_import] 拼，类名一律从 [_plan] 的 `oldClassName` / `newClassName` 取。

const _oldName = 'my_app';
const _newName = 'renamed_app';
const _newApplicationId = 'com.example.renamed_app';
const _newBundleId = 'com.example.renamedApp';
const _newDisplayName = 'Renamed App';

const _plan = RenamePlan(
  oldName: _oldName,
  newName: _newName,
  applicationId: _newApplicationId,
  bundleId: _newBundleId,
  displayName: _newDisplayName,
  description: '改名回归测试',
);

/// fixture 里出现的 import 路径，用插值拼出来（源码里不留 `package:` 字面量）。
String _import(String path) => 'package:$_oldName/$path';
String _newImport(String path) => 'package:$_newName/$path';

const _pubspec = 'pubspec.yaml';
const _gradle = 'android/app/build.gradle.kts';
const _manifest = 'android/app/src/main/AndroidManifest.xml';
const _pbxproj = 'ios/Runner.xcodeproj/project.pbxproj';
const _plist = 'ios/Runner/Info.plist';

/// `android/app/src/main/kotlin/<applicationId 展开成目录>/<文件名>`。
String _kotlinSource(String applicationId, String fileName) {
  final dir = applicationId.replaceAll('.', '/');
  return 'android/app/src/main/kotlin/$dir/$fileName';
}

/// 旧 MainActivity 路径：`com.example.flutter_app` 是 Flutter 模板的默认 namespace。
final String _oldActivity = _kotlinSource(
  'com.example.flutter_app',
  'MainActivity.kt',
);

// ──────────────────────────────────────────────
// fixture 读写
// ──────────────────────────────────────────────

/// 造一个「最小可改名」的仓库快照：每个必改点各一份，外加两个文档文件。
///
/// 名字沿用 Flutter 模板的原始形态（`com.example.flutter_app` 等），
/// 因为脚本要处理的就是「pubspec 名与 Android/iOS 标识并不一致」这种真实情况。
Directory _createFixture() {
  final root = Directory.systemTemp.createTempSync('init_project_');

  void write(String path, String content) {
    final file = File('${root.path}/$path');
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
  }

  write(
    _pubspec,
    'name: $_oldName\n'
    'description: "旧描述"\n'
    '\n'
    'environment:\n'
    '  sdk: ">=3.13.0 <4.0.0"\n',
  );
  write('lib/main.dart', "import '${_import('bootstrap.dart')}';\n");
  write(
    'lib/bootstrap.dart',
    "import '${_import('app/app.dart')}';\n"
        '\n'
        'void run() => runApp(const ${_plan.oldClassName}());\n',
  );
  write(
    'lib/app/app.dart',
    "import '${_import('core/logging/logging.dart')}';\n"
        '\n'
        'class ${_plan.oldClassName} {\n'
        '  const new();\n'
        '}\n',
  );
  write('lib/core/logging/logging.dart', 'class Logging {}\n');
  write(
    'test/app_test.dart',
    "import '${_import('app/app.dart')}';\n"
        '\n'
        'void main() => ${_plan.oldClassName}();\n',
  );
  write('test/features/x_test.dart', "import '${_import('main.dart')}';\n");
  write('tool/check_something.dart', "const prefix = '${_import('')}';\n");

  write(
    _gradle,
    'android {\n'
    '    namespace = "com.example.flutter_app"\n'
    '\n'
    '    defaultConfig {\n'
    '        applicationId = "com.example.flutter_app"\n'
    '    }\n'
    '}\n',
  );
  write(
    _manifest,
    '<manifest xmlns:android="http://schemas.android.com/apk/res/android">\n'
    '    <application\n'
    '        android:label="flutter_app"\n'
    '        android:icon="@mipmap/ic_launcher">\n'
    '    </application>\n'
    '</manifest>\n',
  );
  write(
    _oldActivity,
    'package com.example.flutter_app\n'
    '\n'
    'class MainActivity : FlutterActivity()\n',
  );

  write(
    _plist,
    '<?xml version="1.0" encoding="UTF-8"?>\n'
    '<plist version="1.0">\n'
    '<dict>\n'
    '\t<key>CFBundleDisplayName</key>\n'
    '\t<string>Flutter App</string>\n'
    '\t<key>CFBundleName</key>\n'
    '\t<string>flutter_app</string>\n'
    '</dict>\n'
    '</plist>\n',
  );
  write(
    _pbxproj,
    '// !\$*UTF8*\$!\n'
    'PRODUCT_BUNDLE_IDENTIFIER = com.example.flutterApp;\n'
    'PRODUCT_BUNDLE_IDENTIFIER = com.example.flutterApp.RunnerTests;\n',
  );

  write('.gitignore', 'build/\n$_oldName.code-workspace\n');
  write('README.md', '# $_oldName\n\n跑 `dart run tool/init_project.dart`。\n');
  write('$_oldName.code-workspace', '{"folders": [{"path": "."}]}\n');
  write('.env.development', 'BASE_URL=http://localhost:3000\n');

  return root;
}

String _readFile(Directory root, String path) =>
    File('${root.path}/$path').readAsStringSync();

void _writeFile(Directory root, String path, String content) {
  final file = File('${root.path}/$path');
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(content);
}

/// 删掉文件里的一整行（用来制造「必改点缺失」）。
void _dropLine(Directory root, String path, String line) {
  final content = _readFile(root, path);
  _writeFile(root, path, content.replaceFirst('$line\n', ''));
}

Iterable<File> _dartFiles(Directory root) => ['lib', 'test', 'tool']
    .map((dir) => Directory('${root.path}/$dir'))
    .where((dir) => dir.existsSync())
    .expand((dir) => dir.listSync(recursive: true))
    .whereType<File>()
    .where((file) => file.path.endsWith('.dart'));

void main() {
  late Directory root;

  setUp(() => root = _createFixture());
  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  group('改名成功', () {
    late RenameResult result;

    setUp(() => result = applyRename(root: root, plan: _plan));

    test('没有必改点落空', () {
      expect(result.failures, isEmpty);
      expect(result.ok, isTrue);
    });

    test('pubspec 的 name 与 description 一起换掉', () {
      final pubspec = _readFile(root, _pubspec);
      expect(pubspec, contains('name: $_newName'));
      expect(pubspec, contains('description: "改名回归测试"'));
      expect(pubspec, isNot(contains('name: $_oldName')));
      expect(pubspec, contains('sdk: ">=3.13.0 <4.0.0"'));
    });

    test('全仓库 import 路径都换掉，且不留旧包名', () {
      expect(result.importReplacements, 6);
      expect(
        _readFile(root, 'lib/main.dart'),
        contains(_newImport('bootstrap.dart')),
      );
      expect(
        _readFile(root, 'test/features/x_test.dart'),
        contains(_newImport('main.dart')),
      );
      expect(
        _readFile(root, 'tool/check_something.dart'),
        contains("'package:$_newName/'"),
      );

      for (final file in _dartFiles(root)) {
        expect(
          file.readAsStringSync(),
          isNot(contains('package:$_oldName/')),
          reason: file.path,
        );
      }
    });

    test('根组件类名连 test/ 里的引用一起换掉', () {
      expect(result.classReplacements, greaterThanOrEqualTo(3));
      expect(
        _readFile(root, 'lib/app/app.dart'),
        contains('class ${_plan.newClassName}'),
      );
      for (final path in [
        'lib/app/app.dart',
        'lib/bootstrap.dart',
        'test/app_test.dart',
      ]) {
        expect(
          _readFile(root, path),
          isNot(contains(_plan.oldClassName)),
          reason: path,
        );
      }
    });

    test('Android namespace 与 applicationId 同步成同一个值', () {
      final gradle = _readFile(root, _gradle);
      expect(gradle, contains('namespace = "$_newApplicationId"'));
      expect(gradle, contains('applicationId = "$_newApplicationId"'));
      expect(gradle, isNot(contains('com.example.flutter_app')));
    });

    test('android:label 换成显示名', () {
      expect(
        _readFile(root, _manifest),
        contains('android:label="$_newDisplayName"'),
      );
    });

    test('MainActivity 的 package 与所在目录一起搬家，旧目录清空', () {
      expect(File('${root.path}/$_oldActivity').existsSync(), isFalse);
      final moved = File(
        '${root.path}/${_kotlinSource(_newApplicationId, 'MainActivity.kt')}',
      );
      expect(moved.existsSync(), isTrue);
      expect(moved.readAsStringSync(), contains('package $_newApplicationId'));
      // 新旧包名共享 `com/example` 前缀，所以被清掉的只有最里层那一级
      expect(
        Directory(
          '${root.path}/android/app/src/main/kotlin/com/example'
          '/flutter_app',
        ).existsSync(),
        isFalse,
      );
      expect(
        Directory('${root.path}/android/app/src/main/kotlin').existsSync(),
        isTrue,
      );
    });

    test('iOS bundle id 连 RunnerTests 后缀一起换', () {
      final pbxproj = _readFile(root, _pbxproj);
      expect(pbxproj, contains('PRODUCT_BUNDLE_IDENTIFIER = $_newBundleId;'));
      expect(
        pbxproj,
        contains('PRODUCT_BUNDLE_IDENTIFIER = $_newBundleId.RunnerTests;'),
      );
      expect(pbxproj, isNot(contains('com.example.flutterApp')));
    });

    test('CFBundleDisplayName 换显示名，CFBundleName 跟着包名', () {
      final plist = _readFile(root, _plist);
      expect(
        plist,
        contains(
          '<key>CFBundleDisplayName</key>\n\t<string>$_newDisplayName</string>',
        ),
      );
      expect(
        plist,
        contains('<key>CFBundleName</key>\n\t<string>$_newName</string>'),
      );
    });

    test('文档与 .gitignore 里的裸包名顺手改掉，工作区文件改名', () {
      expect(_readFile(root, 'README.md'), contains('# $_newName'));
      expect(
        _readFile(root, '.gitignore'),
        contains('$_newName.code-workspace'),
      );
      expect(
        File('${root.path}/$_newName.code-workspace').existsSync(),
        isTrue,
      );
      expect(
        File('${root.path}/$_oldName.code-workspace').existsSync(),
        isFalse,
      );
    });

    test('结果里列出被改的文件与被移动的文件', () {
      expect(result.updated, contains(_pubspec));
      expect(result.updated, contains(_gradle));
      expect(result.moved, hasLength(2));
    });
  });

  group('必改点没匹配上就中止', () {
    test('缺 description 时失败，且一个字节都没写', () {
      _dropLine(root, _pubspec, 'description: "旧描述"');

      final result = applyRename(root: root, plan: _plan);

      expect(result.ok, isFalse);
      expect(result.failures.join('\n'), contains('description:'));
      expect(_readFile(root, _pubspec), contains('name: $_oldName'));
      expect(_readFile(root, 'lib/main.dart'), contains('package:$_oldName/'));
      expect(result.updated, isEmpty);
    });

    test('pubspec 的 name 已经被手工改过时，明确指出对不上', () {
      _writeFile(root, _pubspec, 'name: hand_renamed\ndescription: "x"\n');

      final result = applyRename(root: root, plan: _plan);

      final message = result.failures.join('\n');
      expect(result.ok, isFalse);
      expect(message, contains('不一致'));
      expect(message, contains('hand_renamed'));
    });

    test('gradle 里没有 applicationId 时失败', () {
      _writeFile(
        root,
        _gradle,
        'android {\n    namespace = "com.example.x"\n}\n',
      );

      final result = applyRename(root: root, plan: _plan);

      expect(result.failures.join('\n'), contains('applicationId'));
    });

    test('MainActivity 的 package 与 namespace 对不上时失败', () {
      _writeFile(
        root,
        _oldActivity,
        'package com.other.app\n\nclass MainActivity\n',
      );

      final result = applyRename(root: root, plan: _plan);

      expect(
        result.failures.join('\n'),
        contains('package com.example.flutter_app'),
      );
    });

    test('iOS 缺 PRODUCT_BUNDLE_IDENTIFIER 时失败', () {
      _writeFile(root, _pbxproj, '// 没有 bundle id\n');

      final result = applyRename(root: root, plan: _plan);

      expect(result.failures.join('\n'), contains('PRODUCT_BUNDLE_IDENTIFIER'));
    });

    test('Info.plist 缺 CFBundleDisplayName 时失败', () {
      _writeFile(root, _plist, '<plist>\n<dict>\n</dict>\n</plist>\n');

      final result = applyRename(root: root, plan: _plan);

      expect(result.failures.join('\n'), contains('CFBundleDisplayName'));
    });

    test('没有 pubspec.yaml 时直接失败', () {
      File('${root.path}/$_pubspec').deleteSync();

      final result = applyRename(root: root, plan: _plan);

      expect(result.failures.join('\n'), contains('pubspec.yaml'));
    });
  });

  test('改过名的仓库还能再改一次（不依赖脚手架原有字面量）', () {
    expect(applyRename(root: root, plan: _plan).ok, isTrue);

    const second = RenamePlan(
      oldName: _newName,
      newName: 'third_app',
      applicationId: 'io.example.third',
      bundleId: 'io.example.third',
      displayName: 'Third App',
      description: '第二次改名',
    );
    final result = applyRename(root: root, plan: second);

    expect(result.ok, isTrue, reason: result.failures.join('\n'));
    expect(
      File(
        '${root.path}/${_kotlinSource('io.example.third', 'MainActivity.kt')}',
      ).existsSync(),
      isTrue,
    );
    expect(
      _readFile(root, _gradle),
      contains('namespace = "io.example.third"'),
    );
    expect(_readFile(root, _pubspec), contains('name: third_app'));
    expect(_readFile(root, 'README.md'), contains('# third_app'));
  });

  group('parseArgs', () {
    test('解析取值选项与开关', () {
      final options = parseArgs(const [
        '--yes',
        '--name=next_app',
        '--application-id=com.example.next_app',
        '--bundle-id=com.example.nextApp',
        '--display-name=Next App',
        '--description=desc',
      ]);

      expect(options.assumeYes, isTrue);
      expect(options.name, 'next_app');
      expect(options.applicationId, 'com.example.next_app');
      expect(options.bundleId, 'com.example.nextApp');
      expect(options.displayName, 'Next App');
      expect(options.description, 'desc');
      expect(options.hasValues, isTrue);
    });

    test('只给 --yes 时仍是「取默认值」而不是「不给值」', () {
      final options = parseArgs(const ['-y']);

      expect(options.assumeYes, isTrue);
      expect(options.hasValues, isFalse);
      expect(options.help, isFalse);
    });

    test('未知选项 / 缺值都抛 FormatException', () {
      expect(() => parseArgs(const ['--nope']), throwsFormatException);
      expect(() => parseArgs(const ['--name']), throwsFormatException);
      expect(() => parseArgs(const ['--name=']), throwsFormatException);
    });
  });

  group('runCli', () {
    List<String> outputOf(void Function(List<String>) body) {
      final output = <String>[];
      body(output);
      return output;
    }

    test('全参数非交互跑通，返回 0', () {
      final output = outputOf((log) {
        final code = runCli(
          const [
            '--yes',
            '--name=$_newName',
            '--application-id=$_newApplicationId',
            '--bundle-id=$_newBundleId',
            '--display-name=$_newDisplayName',
            '--description=回归',
          ],
          root: root,
          out: log.add,
        );
        expect(code, 0, reason: log.join('\n'));
      });

      expect(output.join('\n'), contains('Project initialized'));
      expect(_readFile(root, _pubspec), contains('name: $_newName'));
      expect(_readFile(root, _plist), contains('$_newDisplayName</string>'));
    });

    test('交互模式：回车吃默认值，确认后跑通', () {
      final output = outputOf((log) {
        final code = runCli(
          const [],
          root: root,
          prompt: (label, fallback) =>
              label.startsWith('Continue') ? 'y' : fallback,
          out: log.add,
        );
        expect(code, 0, reason: log.join('\n'));
      });

      expect(output.join('\n'), contains('Current project name: $_oldName'));
      // 默认 applicationId 由新包名推导；这里包名没变，所以只验证它已被写进 gradle
      expect(
        _readFile(root, _gradle),
        contains('applicationId = "com.example.$_oldName"'),
      );
    });

    test('交互模式：确认时回 n 就中止，不写盘', () {
      final output = outputOf((log) {
        final code = runCli(
          const [],
          root: root,
          prompt: (label, fallback) =>
              label.startsWith('Continue') ? 'n' : fallback,
          out: log.add,
        );
        expect(code, 1);
      });

      expect(output.join('\n'), contains('Aborted'));
      expect(_readFile(root, _pubspec), contains('name: $_oldName'));
      expect(_readFile(root, 'lib/main.dart'), contains('package:$_oldName/'));
    });

    test('非法包名直接失败', () {
      final output = outputOf((log) {
        expect(
          runCli(const ['--yes', '--name=Bad-Name'], root: root, out: log.add),
          1,
        );
      });

      expect(output.join('\n'), contains('不合法'));
    });

    test('--help 打印用法并返回 0', () {
      final output = outputOf((log) {
        expect(runCli(const ['--help'], root: root, out: log.add), 0);
      });

      expect(output.join('\n'), contains('用法：'));
    });

    test('未知选项 / 缺值：打印用法并返回 1', () {
      final output = outputOf((log) {
        expect(runCli(const ['--nope'], root: root, out: log.add), 1);
        expect(runCli(const ['--name'], root: root, out: log.add), 1);
      });

      expect(output.join('\n'), contains('未知选项'));
      expect(output.join('\n'), contains('用法：'));
    });

    test('没有 pubspec.yaml 时返回 1', () {
      final empty = Directory.systemTemp.createTempSync('init_empty_');
      addTearDown(() => empty.deleteSync(recursive: true));

      final output = outputOf((log) {
        expect(runCli(const [], root: empty, out: log.add), 1);
      });

      expect(output.join('\n'), contains('pubspec.yaml'));
    });

    test('改名失败时返回 1，并说明「已中止」', () {
      _dropLine(root, _pubspec, 'description: "旧描述"');

      final output = outputOf((log) {
        expect(
          runCli(const ['--yes', '--name=$_newName'], root: root, out: log.add),
          1,
        );
      });

      expect(output.join('\n'), contains('已中止'));
      expect(_readFile(root, 'lib/main.dart'), contains('package:$_oldName/'));
    });
  });

  group('端到端（默认跳过）', () {
    // 真正在临时目录里改一遍名，再用 flutter analyze 验证改名是自洽的。
    // 复制整个仓库 + flutter pub get + analyze 有分钟级开销，所以默认不跑：
    // 本地要验证时设 SCAFFOLD_E2E=1，CI 的 analyze job 会带上它。
    final enabled = Platform.environment['SCAFFOLD_E2E'] == '1';

    test(
      '复制真实仓库 → 改名 → flutter analyze 干净（也没改到本测试自己）',
      () async {
        final repo = _repoRoot();
        final flutter = _flutterCommand();
        final temp = Directory.systemTemp.createTempSync('init_e2e_');
        addTearDown(() {
          if (temp.existsSync()) temp.deleteSync(recursive: true);
        });

        _copyTree(repo, temp);

        final output = <String>[];
        final code = runCli(
          const [
            '--yes',
            '--name=$_newName',
            '--application-id=$_newApplicationId',
            '--bundle-id=$_newBundleId',
            '--display-name=$_newDisplayName',
          ],
          root: temp,
          out: output.add,
        );
        expect(code, 0, reason: output.join('\n'));

        // 改完的仓库里不该再留着旧包名与旧标识
        expect(
          _grep(Directory('${temp.path}/lib'), 'package:$_oldName/'),
          isEmpty,
        );
        expect(
          _grep(Directory('${temp.path}/lib'), 'package:$_newName/'),
          isNotEmpty,
        );
        expect(
          File('${temp.path}/$_pubspec').readAsStringSync(),
          contains('name: $_newName'),
        );
        final activity = _kotlinSource(_newApplicationId, 'MainActivity.kt');
        expect(File('${temp.path}/$activity').existsSync(), isTrue);
        final gradle = File('${temp.path}/$_gradle').readAsStringSync();
        expect(gradle, contains('namespace = "$_newApplicationId"'));
        expect(gradle, contains('applicationId = "$_newApplicationId"'));
        final pbxproj = File('${temp.path}/$_pbxproj').readAsStringSync();
        expect(pbxproj, contains('PRODUCT_BUNDLE_IDENTIFIER = $_newBundleId;'));
        expect(pbxproj, isNot(contains('com.example.flutterApp')));

        await _pubGet(flutter, temp);

        // `--no-fatal-infos`：仓库本身就有若干既存 info，而改名还会顺带改变
        // import 的字母序（`directives_ordering`）。要抓的是「改名把 import
        // 改断了」——那种情况一律以 error 出现，info 宽容不影响结论。
        final analyze = await Process.run(
          flutter,
          ['analyze', '--no-fatal-infos'],
          workingDirectory: temp.path,
          runInShell: Platform.isWindows,
        );
        final report = '${analyze.stdout}\n${analyze.stderr}';
        expect(analyze.exitCode, 0, reason: '改名后 analyze 失败：\n$report');
        expect(report, isNot(contains('error -')), reason: report);

        // 改名**不该动这份测试自己**：它用固定常量造 fixture，一旦这里出现字面量
        // 包名或旧根组件类名（见文件头），改完名的仓库里 `_plan` 就会和 fixture 失配 ——
        // 而 analyze 抓不到这种失配（两边都是合法 Dart）。
        const selfPath = 'test/tool/init_project_test.dart';
        expect(
          File('${temp.path}/$selfPath').readAsStringSync(),
          File('${repo.path}/$selfPath').readAsStringSync(),
          reason: '改名脚本改到了这份测试：包名要走 _import，类名要走 _plan.oldClassName',
        );
      },
      skip: enabled
          ? false
          : '设 SCAFFOLD_E2E=1 开启（会复制整个仓库并跑 flutter pub get / analyze）',
      timeout: const Timeout(Duration(minutes: 20)),
    );
  });
}

// ──────────────────────────────────────────────
// 端到端辅助
// ──────────────────────────────────────────────

/// 从当前目录向上找到仓库根（测试可能在任意子目录被拉起）。
Directory _repoRoot() {
  var dir = Directory.current.absolute;
  while (true) {
    if (File('${dir.path}/pubspec.yaml').existsSync() &&
        File('${dir.path}/tool/init_project.dart').existsSync()) {
      return dir;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError('从 ${Directory.current.path} 向上没找到仓库根目录');
    }
    dir = parent;
  }
}

/// `flutter` 可执行文件：优先用 `FLUTTER_ROOT`（`flutter test` 一定会设置它），
/// 否则退回 PATH 上的 `flutter`。
String _flutterCommand() {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null) {
    final path = '$root/bin/flutter${Platform.isWindows ? '.bat' : ''}';
    if (File(path).existsSync()) return path;
  }
  return 'flutter';
}

/// 复制仓库到 [target]，跳过产物目录（[isBuildArtifactPath] 是改名脚本的同一份清单）。
void _copyTree(Directory source, Directory target) {
  for (final entity in source.listSync(recursive: true, followLinks: false)) {
    final relative = entity.path
        .substring(source.path.length + 1)
        .replaceAll(r'\', '/');
    if (isBuildArtifactPath(relative)) continue;

    final destination = '${target.path}/$relative';
    if (entity is Directory) {
      Directory(destination).createSync(recursive: true);
    } else if (entity is File) {
      File(destination)
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync(entity.readAsBytesSync());
    }
  }
}

/// `flutter pub get`：先试离线（依赖已在 pub cache 里就能过），失败再联网。
Future<void> _pubGet(String flutter, Directory dir) async {
  final offline = await Process.run(
    flutter,
    ['pub', 'get', '--offline'],
    workingDirectory: dir.path,
    runInShell: Platform.isWindows,
  );
  if (offline.exitCode == 0) return;

  final online = await Process.run(
    flutter,
    ['pub', 'get'],
    workingDirectory: dir.path,
    runInShell: Platform.isWindows,
  );
  expect(
    online.exitCode,
    0,
    reason: 'flutter pub get 失败：\n${online.stdout}\n${online.stderr}',
  );
}

/// 在 [dir] 下的文本文件里找 [needle]，返回 `路径:行号` 列表。
List<String> _grep(Directory dir, String needle) {
  if (!dir.existsSync()) return const [];

  final hits = <String>[];
  for (final entity in dir.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final lines = entity.readAsStringSync().split('\n');
    for (var index = 0; index < lines.length; index++) {
      if (lines[index].contains(needle)) {
        hits.add('${entity.path}:${index + 1}');
      }
    }
  }
  return hits;
}
