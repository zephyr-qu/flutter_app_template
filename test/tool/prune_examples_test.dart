import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/init_project.dart' show isBuildArtifactPath;
import '../../tool/prune_examples.dart';

// ──────────────────────────────────────────────
// 这份测试分三层，各自兜不同的失效
// ──────────────────────────────────────────────
//
// 1. 机制层：参数解析、拒绝分支、全或无（改坏一处锚点后夹具必须零改动）。
//    夹具从**真实仓库的文件内容**派生，而不是另抄一份 —— 抄一份的话夹具会和
//    仓库一起漂，测试照样绿。
// 2. 锚点层：对真实仓库调 buildPlan，断言每条清理点都恰好命中 1 次。锚点一漂
//    这个测试立刻红，是「工具认知 == 仓库现状」的长期保护。
// 3. 端到端层（SCAFFOLD_E2E=1）：复制真实仓库 → 剪枝 → just codegen → just verify。
//
// 工具函数是顶层可 import 的（`runCli` / `buildPlan` / `pruneModules`），
// 与 tool/init_project.dart 同一种形态：main() 只是薄壳。

/// `--modules=auth` 的拒绝码；其余码见 tool/prune_examples.dart 顶部注释。
const int _ok = 0;
const int _failed = 1;
const int _rejected = 2;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory repo;
  late Directory temp;

  // 模板仓库里示例模块在；派生项目里它们已经被剪掉。依赖「示例还在」的用例届时显式
  // 跳过而不是留一堆红 —— 「已剪枝」本来就是工具的一等状态（幂等分支）。
  final hasExamples = Directory('${_repoRoot().path}/lib/features/article')
      .existsSync();
  final skipNoExamples = hasExamples ? null : '示例模块已被剪掉（这是派生项目，不是模板仓库）';

  setUp(() {
    repo = _repoRoot();
    temp = Directory.systemTemp.createTempSync('prune_examples_');
  });

  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  // ──────────────────────────────────────────────
  // 1. 参数解析
  // ──────────────────────────────────────────────

  group('parseArgs', () {
    test('未知选项 / 缺值都抛 FormatException', () {
      expect(() => parseArgs(['--nope']), throwsFormatException);
      expect(() => parseArgs(['--modules']), throwsFormatException);
      expect(() => parseArgs(['--modules=']), throwsFormatException);
    });

    test('识别 --yes / -y / --no-verify / --force / --help / -h', () {
      final options = parseArgs([
        '--yes',
        '--no-verify',
        '--force',
        '--modules=article,demo',
      ]);
      expect(options.assumeYes, isTrue);
      expect(options.skipVerify, isTrue);
      expect(options.force, isTrue);
      expect(options.modules, 'article,demo');
      expect(parseArgs(['-y']).assumeYes, isTrue);
      expect(parseArgs(['-h']).help, isTrue);
      expect(parseArgs(['--help']).help, isTrue);
    });

    test('没有取值选项时不走非交互', () {
      expect(parseArgs(const []).hasValues, isFalse);
    });
  });

  group('runCli — 参数被拒', () {
    test('--help 打印用法并返回 0', () async {
      final output = <String>[];
      final code = await runCli(
        ['--help'],
        root: temp,
        out: output.add,
        runProcess: _fakeRunner(),
      );
      expect(code, _ok);
      expect(
        output.join('\n'),
        contains('用法：dart run tool/prune_examples.dart'),
      );
    });

    test('未知选项：打印用法并返回 1', () async {
      final output = <String>[];
      final code = await runCli(
        ['--nope'],
        root: temp,
        out: output.add,
        runProcess: _fakeRunner(),
      );
      expect(code, _failed);
      expect(output.join('\n'), contains('未知选项'));
    });

    test('未知模块名返回 2，并列出可剪的模块', () async {
      final output = <String>[];
      final code = await runCli(
        ['--modules=website'],
        root: temp,
        out: output.add,
        runProcess: _fakeRunner(),
      );
      expect(code, _rejected);
      expect(output.join('\n'), contains('未知模块'));
      expect(output.join('\n'), contains('article'));
    });
  });

  // ──────────────────────────────────────────────
  // 2. auth 拒绝（R5 / AC4）
  // ──────────────────────────────────────────────

  group('runCli — auth 拒绝', () {
    test('--modules=auth 返回 2，说明它是基础设施，且不碰磁盘', () async {
      _writeFixtureFile(temp, 'sentinel.txt', '原样');

      final output = <String>[];
      final code = await runCli(
        ['--modules=auth', '--yes'],
        root: temp,
        out: output.add,
        runProcess: _fakeRunner(),
      );

      expect(code, _rejected);
      final text = output.join('\n');
      expect(text, contains('基础设施'));
      expect(text, contains('AuthStorage'));
      expect(_snapshot(temp), {'sentinel.txt': '原样'});
    });

    test('--modules=article,auth 也在写盘前整体拒绝', () async {
      // 混合请求不能「删掉一半再报错」：拒绝必须发生在任何写盘之前
      _writeFixtureFile(temp, 'sentinel.txt', '原样');

      final code = await runCli(
        ['--modules=article,auth', '--yes'],
        root: temp,
        out: (_) {},
        runProcess: _fakeRunner(),
      );

      expect(code, _rejected);
      expect(_snapshot(temp), {'sentinel.txt': '原样'});
    });
  });

  // ──────────────────────────────────────────────
  // 3. 前置检查：脏工作区与幂等
  // ──────────────────────────────────────────────

  group('runCli — 前置检查', () {
    test('工作区不干净时返回 2', () async {
      _writeFixtureFile(temp, 'dirty.dart', 'void main() {}');

      final output = <String>[];
      final code = await runCli(
        ['--modules=article', '--yes'],
        root: temp,
        out: output.add,
        runProcess: _fakeRunner(gitStatus: ' M lib/main.dart'),
      );

      expect(code, _rejected);
      expect(output.join('\n'), contains('工作区不干净'));
      // 这里**不能**提示 `git checkout -- .` —— 那会把用户未提交的改动一起抹掉。
      // 干净基线的正确拿法是先提交或 stash。
      expect(output.join('\n'), contains('提交或 stash'));
      expect(output.join('\n'), isNot(contains('git checkout -- .')));
    });

    test('git 只报 .trellis/ 时不算脏（任务元数据本就未入库）', () async {
      // 这条不忽略的话，工具在任务内运行时会把自己拒掉
      final output = <String>[];
      final code = await runCli(
        ['--modules=article', '--yes'],
        root: temp,
        out: output.add,
        runProcess: _fakeRunner(gitStatus: '?? .trellis/tasks/10-14-x/prd.md'),
      );

      expect(code, isNot(_rejected));
      expect(output.join('\n'), isNot(contains('工作区不干净')));
    });

    test('模块目录已不存在：幂等跳过，返回 0', () async {
      final output = <String>[];
      final code = await runCli(
        ['--modules=article,demo', '--yes', '--force'],
        root: temp,
        out: output.add,
        runProcess: _fakeRunner(),
      );

      expect(code, _ok);
      expect(output.join('\n'), contains('已经剪过'));
    });
  });

  // ──────────────────────────────────────────────
  // 4. 全或无（AC5）
  // ──────────────────────────────────────────────

  group('runCli — 全或无', () {
    test('锚点被改坏：非零退出、点名那处、夹具零改动', () async {
      // 夹具直接取真实文件内容，只把 main_page.dart 的锚点改坏一处 ——
      // 另抄一份夹具会和仓库一起漂，测不出「工具认知与仓库不一致」。
      const mainPage = 'lib/features/home/page/main_page.dart';
      final source = File('${repo.path}/$mainPage').readAsStringSync();
      expect(
        source,
        contains('ArticleListRoute(),'),
        reason: '仓库里的锚点已经变了，先更新 tool/prune_examples.dart 的锚点表',
      );
      _writeFixtureFile(
        temp,
        mainPage,
        source.replaceFirst('ArticleListRoute(),', 'SomethingElseRoute(),'),
      );
      // 模块目录要在，否则会先走「已剪枝」的幂等分支
      Directory('${temp.path}/lib/features/article')
          .createSync(recursive: true);
      Directory('${temp.path}/lib/features/demo').createSync(recursive: true);

      final before = _snapshot(temp);
      final output = <String>[];
      final code = await runCli(
        ['--modules=article,demo', '--yes', '--force'],
        root: temp,
        out: output.add,
        runProcess: _fakeRunner(),
      );

      expect(code, _failed);
      final text = output.join('\n');
      expect(text, contains('没有对上'));
      expect(text, contains('期望命中 1 次'));
      expect(text, contains('_tabs 与「不是 const」注释'));
      expect(_snapshot(temp), before, reason: '全或无：失败时必须一个字节都不写');
    }, skip: skipNoExamples);

    test('一条锚点都没对上时也不写盘（夹具是空目录）', () async {
      final output = <String>[];
      final code = await runCli(
        ['--modules=article', '--yes', '--force'],
        root: temp,
        out: output.add,
        runProcess: _fakeRunner(),
      );

      expect(code, _ok, reason: '空目录里没有模块目录，走的是幂等分支');
      expect(output.join('\n'), contains('已经剪过'));
    });
  });

  // ──────────────────────────────────────────────
  // 5. 锚点表自检：这条抓的是「工具源码里的缩进漏进目标文件」
  // ──────────────────────────────────────────────

  test('锚点表：每个替换块的缩进一致（不一致会写出错缩进）', () {
    // replacement 是逐字写进文件的，只按命中位置整体重排一次。所以块内各行必须
    // 共享同一个缩进基准 —— 混排的话基准会退化成最短的那个，整块缩进全错。
    // 曾经真的踩过：一条长行手工去缩进后，main_page 的替换块整块多缩进了 8 格。
    for (final module in pruneModules.values) {
      for (final edit in module.edits) {
        if (edit is! ReplaceBlock) continue;

        final lines = edit.replacement
            .where((line) => line.trim().isNotEmpty)
            .toList();
        if (lines.isEmpty) continue;

        final base = lines
            .map(leadingWhitespace)
            .reduce((a, b) => a.length <= b.length ? a : b);
        for (final line in lines) {
          final where = '${module.name} / ${edit.label}';
          expect(
            leadingWhitespace(line).startsWith(base),
            isTrue,
            reason: '$where 的替换块缩进不一致：「${line.trim()}」不以 "$base" 开头',
          );
        }
      }
    }
  });

  // ──────────────────────────────────────────────
  // 6. 真实仓库的锚点层
  // ──────────────────────────────────────────────

  group('真实仓库锚点', () {
    test('article + demo 的每条清理点都恰好命中 1 次', () {
      final plan = buildPlan(repo, [articleModule, demoModule]);

      expect(
        plan.ok,
        isTrue,
        reason:
            '锚点与仓库现状不一致，逐条如下：\n${plan.failures.join('\n')}\n'
            '（改过 lib/ 或 test/ 里的相关代码后，要同步 tool/prune_examples.dart）',
      );
      // 命中次数有变动时也让这条测试显式红一次，逼作者确认新增/删除是有意的
      expect(plan.edits, hasLength(35));
      expect(plan.failures, isEmpty);
    }, skip: skipNoExamples);

    test('待删的目录与文件都在', () {
      final plan = buildPlan(repo, [articleModule, demoModule]);
      expect(
        plan.dirs,
        containsAll([
          'lib/features/article',
          'test/features/article',
          'lib/features/demo',
          'test/features/demo',
        ]),
      );
      expect(
        plan.files,
        contains('lib/core/data/database/tables/db_articles.dart'),
      );
    }, skip: skipNoExamples);

    test('plan 不写盘：真实仓库在一趟规划后一个字节都没变', () {
      final before = _snapshotRepo(repo);
      buildPlan(repo, [articleModule, demoModule]);
      expect(_snapshotRepo(repo), before);
    });
  });

  // ──────────────────────────────────────────────
  // 7. 集成：对仓库副本跑完整流程（不跑 build_runner，进程是假的）
  // ──────────────────────────────────────────────

  group('在副本上剪枝', () {
    late Directory copy;
    late List<String> output;
    late int code;

    setUp(() {
      copy = Directory('${temp.path}/repo')..createSync(recursive: true);
      // 代码侧只复制 lib/ 与 test/ —— 剪枝只碰这两棵树，跑真实 verify 留给
      // SCAFFOLD_E2E。生成物不入库，副本按「gitignore 之后」的形态来：留着它们的
      // 话，假 codegen 不会重新生成，残留扫描会（正确地）报出陈旧生成物里的已删类型。
      for (final dir in ['lib', 'test']) {
        _copyTree(
          Directory('${repo.path}/$dir'),
          Directory('${copy.path}/$dir'),
        );
      }
      for (final entity in copy.listSync(recursive: true)) {
        if (entity is! File) continue;
        if (isGeneratedPath(_relative(copy, entity.path))) entity.deleteSync();
      }
      // 文档侧也要复制：残留扫描的文档清单（AGENTS.md / docs / .trellis/spec）得有
      // 真实文件才验得到「扫描面有效」—— 副本里没有文档的话，那份清单永远是空的。
      for (final file in ['AGENTS.md', 'README.md', '.trellis/workflow.md']) {
        final source = File('${repo.path}/$file');
        if (!source.existsSync()) continue;
        File('${copy.path}/$file')
          ..parent.createSync(recursive: true)
          ..writeAsStringSync(source.readAsStringSync());
      }
      for (final dir in ['docs', '.trellis/spec']) {
        _copyTree(
          Directory('${repo.path}/$dir'),
          Directory('${copy.path}/$dir'),
        );
      }
      output = <String>[];
    });

    Future<void> prune() async {
      code = await runCli(
        ['--modules=article,demo', '--yes', '--force'],
        root: copy,
        out: output.add,
        runProcess: _fakeRunner(),
      );
    }

    test('退出码 0，且代码侧零残留（AC2）', () async {
      await prune();

      expect(code, _ok, reason: output.join('\n'));
      for (final pattern in [
        'features/article',
        'features/demo',
        'ArticleListRoute',
        'StorageDemoRoute',
        'DbArticle',
      ]) {
        expect(_grep(copy, pattern), isEmpty, reason: '副本里还留着「$pattern」');
      }
    });

    test('残留扫描抓到文档侧引用并打印（R10 / AC8）', () async {
      await prune();

      final text = output.join('\n');
      // 扫描面必须是有效的：空输出就说明这个清单永远不会命中
      expect(text, contains('文档里还有'));
      expect(text, contains('AGENTS.md'));
      expect(text, contains('.trellis/spec/'));
      expect(text, contains('不是失败'));
    });

    test('交付的收尾步骤与回滚提示都在', () async {
      await prune();

      final text = output.join('\n');
      expect(text, contains('just codegen'));
      expect(text, contains('just verify'));
      expect(text, contains('git checkout -- . && git clean -fd'));
    });

    test('主框架标签重排：两个标签、索引没错位（语义残留）', () async {
      await prune();

      final mainPage = File(
        '${copy.path}/lib/features/home/page/main_page.dart',
      ).readAsStringSync();
      // 删掉中间那个标签后，Rail 与 Bar 的索引必须从 0/1/2 收到 0/1
      expect(mainPage, contains('static const List<PageRouteInfo> _tabs'));
      expect(mainPage, contains('[HomeRoute(), ProfileRoute()]'));
      expect(mainPage, isNot(contains('labelStyle(2)')));
      expect(mainPage, contains("label: Text('我的', style: labelStyle(1))"));

      final navigationBar = mainPage.substring(
        mainPage.indexOf('NavigationBar('),
      );
      expect(navigationBar, isNot(contains('labelStyle(')));
      expect('文章'.allMatches(mainPage), isEmpty);
    });

    test('注释型残留也被清掉（grep 抓不到的那一类）', () async {
      await prune();

      final router = File('${copy.path}/lib/app/routing/router.dart')
          .readAsStringSync();
      expect(router, isNot(contains('三个类型')));
      expect(router, contains('routes'));

      final dioClient = File(
        '${copy.path}/lib/core/data/network/dio_client.dart',
      ).readAsStringSync();
      expect(dioClient, isNot(contains('/articles')));
      expect(dioClient, contains('/login'));

      final settings = File(
        '${copy.path}/lib/features/profile/page/profile_settings.dart',
      ).readAsStringSync();
      expect(settings, isNot(contains('本地存储示例')));
      // 示例入口带来的两个 import 会变成 unused_import，必须一起清
      expect(settings, isNot(contains('auto_route')));
      expect(settings, isNot(contains('app/routing/router.dart')));
    });

    test('不留双空行（dart format 会改写 → fmt-check 会红）', () async {
      await prune();

      for (final path in [
        'lib/core/data/database/app_database.dart',
        'lib/app/routing/router.dart',
        'lib/core/data/network/dio_client.dart',
        'lib/features/home/page/main_page.dart',
        'lib/features/home/page/home_page.dart',
        'lib/features/profile/page/profile_settings.dart',
        'test/core/data/database/app_database_test.dart',
        'test/routing/main_shell_test.dart',
        'test/app/pages/splash_page_test.dart',
      ]) {
        final source = File('${copy.path}/$path').readAsStringSync();
        expect(source.contains('\n\n\n'), isFalse, reason: '$path 里留下了连续空行');
      }
    });

    test('路由表与守卫仍然完整（剪枝不能删坏组合根）', () async {
      await prune();

      final router = File('${copy.path}/lib/app/routing/router.dart')
          .readAsStringSync();
      expect(router, contains('AutoRouteGuard.simple(_checkAuth)'));
      expect(router, contains('page: MainRoute.page'));
      expect(router, contains('page: LoginRoute.page'));
      expect(router, contains('page: HomeRoute.page'));
      expect(router, contains('page: ProfileRoute.page'));
      expect(
        router,
        contains("AutoRoute(path: '*', page: NotFoundRoute.page)"),
      );
    });

    test('第二次跑同一份副本：幂等，返回 0', () async {
      await prune();
      expect(code, _ok);

      final again = <String>[];
      final second = await runCli(
        ['--modules=article,demo', '--yes', '--force'],
        root: copy,
        out: again.add,
        runProcess: _fakeRunner(),
      );

      expect(second, _ok);
      expect(again.join('\n'), contains('已经剪过'));
    });

    test('--no-verify：不跑 codegen，打印下一步命令', () async {
      final calls = <List<String>>[];
      final text = <String>[];
      final skipped = await runCli(
        ['--modules=article,demo', '--yes', '--force', '--no-verify'],
        root: copy,
        out: text.add,
        runProcess: _fakeRunner(calls: calls),
      );

      expect(skipped, _ok);
      expect(calls.any((c) => c.contains('codegen')), isFalse);
      expect(text.join('\n'), contains('dart run build_runner build'));
      expect(text.join('\n'), contains('just verify'));
    });

    test('codegen 失败：返回 3，附回滚命令', () async {
      final text = <String>[];
      final failed = await runCli(
        ['--modules=article,demo', '--yes', '--force'],
        root: copy,
        out: text.add,
        runProcess: _fakeRunner(codegenExit: 1),
      );

      expect(failed, 3);
      expect(text.join('\n'), contains('just codegen 失败'));
      expect(text.join('\n'), contains('git checkout -- .'));
    });

    test('verify 失败：返回 3（剪枝成功但自证没过）', () async {
      final text = <String>[];
      final failed = await runCli(
        ['--modules=article,demo', '--yes', '--force'],
        root: copy,
        out: text.add,
        runProcess: _fakeRunner(verifyExit: 1),
      );

      expect(failed, 3);
      expect(text.join('\n'), contains('just verify 失败'));
      expect(text.join('\n'), contains('git checkout -- .'));
    });
  }, skip: skipNoExamples);

  // ──────────────────────────────────────────────
  // 8. 端到端：复制真实仓库 → 剪枝 → codegen → verify（AC1）
  // ──────────────────────────────────────────────

  group('端到端（默认跳过）', () {
    // 本地要验证时设 SCAFFOLD_E2E=1，CI 的 analyze job 会带上它。
    // 注意：剪枝**只能**在副本上做 —— 本仓库是模板本身，它的示例模块是
    // AGENTS.md 与 .trellis/spec 反复引用的教学范例。
    final enabled = Platform.environment['SCAFFOLD_E2E'] == '1';

    test(
      '副本上剪枝后 just verify 全绿，且本仓库的示例模块没被动过',
      () async {
        final e2e = Directory.systemTemp.createTempSync('prune_e2e_');
        addTearDown(() {
          if (e2e.existsSync()) e2e.deleteSync(recursive: true);
        });
        _copyTree(repo, e2e);

        // 副本里的 .dart_tool 路径是原仓库的，先按 justfile 的 deps 重新解析
        // （根工程用 flutter、独立子包用 dart —— 正是 `just deps` 的两步）
        await _pubGetAll(_flutterCommand(), e2e);

        // 工具要求工作区干净（不可逆删除的前提），所以副本得是个已提交的 git 仓库。
        // 用 --force 绕过去就验不到这道门 —— 而它是真实使用时的第一道门。
        await _gitInitAndCommit(e2e);

        final output = <String>[];
        final code = await runCli(
          ['--modules=article,demo', '--yes'],
          root: e2e,
          out: output.add,
          // 真实 codegen + 真实 verify，但**不把 SCAFFOLD_E2E 传给子进程**：
          // 否则副本里的 `just verify` → `flutter test` 会继承它，把这条用例
          // 递归地再跑一遍（副本里的副本……）。
          runProcess: _e2eRunner,
        );

        expect(code, _ok, reason: output.join('\n'));
        expect(output.join('\n'), contains('剪枝完成'));

        // 代码侧零残留
        for (final pattern in [
          'features/article',
          'features/demo',
          'ArticleListRoute',
        ]) {
          expect(_grep(e2e, pattern), isEmpty, reason: '副本里还留着 $pattern');
        }
        // 生成物也不该再提到已删的路由类
        expect(
          File('${e2e.path}/lib/app/routing/router.gr.dart').readAsStringSync(),
          isNot(contains('Article')),
        );

        // **本仓库必须没被改动** —— 这是这条测试存在的主要理由
        expect(
          Directory('${repo.path}/lib/features/article').existsSync(),
          isTrue,
          reason: '剪枝跑到了模板仓库上，而不是副本上',
        );
        expect(
          Directory('${repo.path}/lib/features/demo').existsSync(),
          isTrue,
        );
      },
      skip: enabled
          ? false
          : '设 SCAFFOLD_E2E=1 开启（会复制整个仓库并跑 just deps / codegen / verify）',
      timeout: const Timeout(Duration(minutes: 30)),
    );
  });
}

// ──────────────────────────────────────────────
// 假进程：端到端之外的用例一律不跑真实 build_runner
// ──────────────────────────────────────────────

/// 构造一个假的 [ProcessRunner]。
///
/// [gitStatus] 是 `git status --porcelain` 的输出；[codegenExit] / [verifyExit]
/// 用来演练收尾失败。被调用过的命令记进 [calls]。
ProcessRunner _fakeRunner({
  String gitStatus = '',
  int gitExit = 0,
  int codegenExit = 0,
  int verifyExit = 0,
  List<List<String>>? calls,
}) {
  return (command, workingDirectory) async {
    calls?.add(command);
    if (command.first == 'git') {
      return ProcessResult(0, gitExit, gitStatus, '');
    }
    final isCodegen = command.contains('codegen');
    return ProcessResult(
      0,
      isCodegen ? codegenExit : verifyExit,
      isCodegen ? 'codegen output' : 'verify output',
      '',
    );
  };
}

// ──────────────────────────────────────────────
// 仓库与文件辅助
// ──────────────────────────────────────────────

/// 从当前目录向上找到仓库根（测试可能在任意子目录被拉起）。
Directory _repoRoot() {
  var dir = Directory.current.absolute;
  while (true) {
    if (File('${dir.path}/pubspec.yaml').existsSync() &&
        File('${dir.path}/tool/prune_examples.dart').existsSync()) {
      return dir;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError('从 ${Directory.current.path} 向上没找到仓库根目录');
    }
    dir = parent;
  }
}

void _writeFixtureFile(Directory root, String relative, String content) {
  final file = File('${root.path}/$relative');
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(content);
}

/// 目录快照：`相对路径 → 内容`。用来断言「一个字节都没写」。
Map<String, String> _snapshot(Directory root) {
  final snapshot = <String, String>{};
  for (final entity in root.listSync(recursive: true)) {
    if (entity is! File) continue;
    snapshot[_relative(root, entity.path)] = entity.readAsStringSync();
  }
  return snapshot;
}

/// 只对 lib/ 与 test/ 做快照：规划阶段本来就不该碰别处。
Map<String, String> _snapshotRepo(Directory root) {
  final snapshot = <String, String>{};
  for (final dir in ['lib', 'test']) {
    final target = Directory('${root.path}/$dir');
    if (!target.existsSync()) continue;
    for (final entity in target.listSync(recursive: true)) {
      if (entity is! File) continue;
      snapshot[_relative(root, entity.path)] = entity.readAsStringSync();
    }
  }
  return snapshot;
}

String _relative(Directory root, String path) {
  final rootPath = root.path.replaceAll(r'\', '/');
  final normalized = path.replaceAll(r'\', '/');
  return normalized.startsWith('$rootPath/')
      ? normalized.substring(rootPath.length + 1)
      : normalized;
}

/// `lib/` 与 `test/` 下命中 [pattern] 的行（相对路径:行:内容）。
///
/// 跳过剪枝工具与它自己的测试：那两份文件里必然写着这些标识符（锚点表与断言）。
List<String> _grep(Directory root, String pattern) {
  final hits = <String>[];
  for (final dir in ['lib', 'test']) {
    final target = Directory('${root.path}/$dir');
    if (!target.existsSync()) continue;
    for (final entity in target.listSync(recursive: true)) {
      if (entity is! File) continue;
      if (isPruneToolingPath(_relative(root, entity.path))) continue;
      final lines = entity.readAsStringSync().split('\n');
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].contains(pattern)) {
          hits.add('${_relative(root, entity.path)}:${i + 1}: ${lines[i]}');
        }
      }
    }
  }
  return hits;
}

/// 复制 [source] 到 [target]，跳过产物目录（与改名脚本共用同一份清单）。
void _copyTree(Directory source, Directory target) {
  for (final entity in source.listSync(recursive: true, followLinks: false)) {
    final relative = _relative(source, entity.path);
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

/// `pub get`：先试离线，失败再联网（与 justfile 的 `deps` 两步一致）。
/// pub get：根工程用 [flutter]、独立子包用 dart —— 与 justfile 的 `deps` 两步一致。
///
/// 三者都是同一个形状（`pub get`），只差可执行文件：Flutter 工程必须用 `flutter`，
/// 独立子包（`packages/app_lints`）用 `dart`。
Future<void> _pubGetAll(String flutter, Directory root) async {
  await _pubGet(flutter, root);
  await _pubGet(_dartCommand(), Directory('${root.path}/packages/app_lints'));
}

/// 先试离线（依赖已在 pub cache 里就能过），失败再联网。
Future<void> _pubGet(String executable, Directory dir) async {
  final offline = await Process.run(
    executable,
    ['pub', 'get', '--offline'],
    workingDirectory: dir.path,
    runInShell: Platform.isWindows,
  );
  if (offline.exitCode == 0) return;

  final online = await Process.run(
    executable,
    ['pub', 'get'],
    workingDirectory: dir.path,
    runInShell: Platform.isWindows,
  );
  expect(
    online.exitCode,
    0,
    reason: 'pub get 失败于 ${dir.path}：\n${online.stdout}\n${online.stderr}',
  );
}

/// 端到端用的真实进程执行器：跑真命令，但**不把 `SCAFFOLD_E2E` 传给子进程**。
///
/// 副本里的 `just verify` 会拉起 `flutter test`；继承了这个环境变量的话，那条端到端
/// 用例会在副本里再跑一遍（副本里的副本……）。
Future<ProcessResult> _e2eRunner(
  List<String> command,
  String workingDirectory,
) {
  final environment = Map<String, String>.from(Platform.environment)
    ..remove('SCAFFOLD_E2E');
  return Process.run(
    command.first,
    command.sublist(1),
    workingDirectory: workingDirectory,
    environment: environment,
    runInShell: Platform.isWindows,
  );
}

/// 把 [root] 变成「干净基线」的 git 仓库（工具的前置检查要求）。
Future<void> _gitInitAndCommit(Directory root) async {
  Future<void> git(List<String> args) async {
    final result = await Process.run(
      'git',
      args,
      workingDirectory: root.path,
      runInShell: Platform.isWindows,
    );
    expect(
      result.exitCode,
      0,
      reason: 'git ${args.join(' ')} 失败：\n${result.stdout}\n${result.stderr}',
    );
  }

  await git(['init']);
  await git(['add', '-A']);
  await git([
    '-c',
    'user.email=e2e@example.com',
    '-c',
    'user.name=e2e',
    'commit',
    '-m',
    'e2e baseline',
  ]);
}

/// `dart` 可执行文件：优先用 `FLUTTER_ROOT`（Flutter SDK 自带 `dart`），否则退回 PATH。
String _dartCommand() {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null) {
    final path = '$root/bin/dart${Platform.isWindows ? '.bat' : ''}';
    if (File(path).existsSync()) return path;
  }
  return 'dart';
}

/// `flutter` 可执行文件：优先用 `FLUTTER_ROOT`（`flutter test` 一定会设置它），
/// 否则退回 PATH —— 与 test/tool/init_project_test.dart 同一取舍。
String _flutterCommand() {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null) {
    final path = '$root/bin/flutter${Platform.isWindows ? '.bat' : ''}';
    if (File(path).existsSync()) return path;
  }
  return 'flutter';
}
