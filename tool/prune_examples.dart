// ──────────────────────────────────────────────
// 脚手架示例模块剪枝
// ──────────────────────────────────────────────
//
// 把示例模块（article / demo）连同它的全部引用一次删干净，然后自己重跑 codegen
// 与门禁自证。形态照抄 `tool/init_project.dart`：先规划、后写盘，任一锚点没匹配到
// 就非零退出且**一个字节都不写**。
//
// 剪枝是给**派生项目**用的：本仓库是模板本身，它的 `lib/features/{article,demo}`
// 是 AGENTS.md 与 .trellis/spec 反复引用的教学范例，删掉就没了。所以端到端验收
// 在临时副本上做（见 test/tool/prune_examples_test.dart 的 SCAFFOLD_E2E 分支）。
//
// 为什么 `auth` 拒绝剪枝：它不是示例而是基础设施 —— `AuthStorage` 被路由守卫消费、
// 拦截器栈在网络层、`app.dart` 用 `AuthReevaluateListenable` 接线。删它等于重做
// 认证/守卫骨架，属于架构改造，自动化做不安全。

import 'dart:io';

/// 成功（含「已剪枝」的幂等跳过与主动取消）。
const int _ok = 0;

/// 锚点没匹配上，或有代码侧残留。两者都意味着「工具认知与仓库不一致」。
const int _failed = 1;

/// 输入被拒：`auth`、脏工作区、未知模块名。
const int _rejected = 2;

/// 剪枝做完了，但收尾的 codegen / verify 没过。
const int _verifyFailed = 3;

/// 生成物判定，口径必须与 `packages/app_lints/lib/src/paths.dart` 的
/// `isGeneratedPath()` **逐条对齐**（以及根 `.gitignore` 的生成物段落）。
///
/// 这里是一份刻意的副本而不是 import：`packages/app_lints` 是独立子包，root 工程
/// 不依赖它。代价是**三处改动要同步** —— 少一种形态，`--no-verify` 路径就会把陈旧
/// 生成物当成代码残留报出来。
bool isGeneratedPath(String path) =>
    path.endsWith('.g.dart') ||
    path.endsWith('.freezed.dart') ||
    path.endsWith('.gr.dart') ||
    path.endsWith('.config.dart') ||
    path.endsWith('.gen.dart') ||
    path.contains('/gen/') ||
    path.contains('app_localizations');

// ──────────────────────────────────────────────
// 输入
// ──────────────────────────────────────────────

/// 命令行选项。取值选项一律写成 `--key=value`。
class CliOptions {
  const new({
    this.help = false,
    this.assumeYes = false,
    this.skipVerify = false,
    this.force = false,
    this.modules,
  });

  /// `--help` / `-h`
  final bool help;

  /// `--yes` / `-y`：跳过确认。
  final bool assumeYes;

  /// `--no-verify`：不跑 codegen 与门禁，只打印下一步命令。
  final bool skipVerify;

  /// `--force`：越过「工作区不干净」的前置检查（供测试与非 git 环境）。
  final bool force;

  /// `--modules=article,demo` 的原始值；null = 走交互模式。
  final String? modules;

  /// 是否给了任一取值选项 —— 给了就整体走非交互。
  bool get hasValues => modules != null;
}

/// 解析命令行；未知选项、或 `--key` 没带 `=值` 时抛 [FormatException]。
CliOptions parseArgs(List<String> args) {
  var help = false;
  var assumeYes = false;
  var skipVerify = false;
  var force = false;
  String? modules;

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
      case '--no-verify':
        skipVerify = true;
      case '--force':
        force = true;
      default:
        final separator = arg.indexOf('=');
        final key = separator < 0 ? arg : arg.substring(0, separator);
        final raw = separator < 0 ? null : arg.substring(separator + 1);
        switch (key) {
          case '--modules':
            modules = requireValue(key, raw);
          default:
            throw FormatException('未知选项：$arg');
        }
    }
  }

  return CliOptions(
    help: help,
    assumeYes: assumeYes,
    skipVerify: skipVerify,
    force: force,
    modules: modules,
  );
}

// ──────────────────────────────────────────────
// 引用清理点：按锚点文本定位，不按行号
// ──────────────────────────────────────────────

/// 一条引用清理点。
sealed class PruneEdit {
  const new({required this.path, required this.label});

  /// 仓库相对路径。
  final String path;

  /// 诊断信息里的人类可读描述。
  final String label;
}

/// 整块删除：[lines] 按 trim 后逐行匹配，必须在该文件里**恰好命中一次**。
///
/// 唯一性由整块内容保证 —— 所以 `  );` 这种到处都有的行没问题，只要整块是唯一的。
/// 匹配不到（0 次）说明仓库已经和工具不一致；命中多次说明锚点不够具体。两种都中止。
final class DeleteBlock extends PruneEdit {
  const new({required super.path, required super.label, required this.lines});

  final List<String> lines;
}

/// 整块替换：匹配规则同 [DeleteBlock]，命中后换成 [replacement]。
final class ReplaceBlock extends PruneEdit {
  const new({
    required super.path,
    required super.label,
    required this.old,
    required this.replacement,
  });

  final List<String> old;
  final List<String> replacement;
}

/// 把多行原文切成锚点行：丢掉 `'''` 首尾换行产生的空行，其余按 trim 比较。
///
/// 要在块里留一个真正的空行，就在中间留一个空行 —— 它会被保留。
List<String> _block(String raw) {
  final lines = raw.split('\n');
  if (lines.isNotEmpty && lines.first.trim().isEmpty) lines.removeAt(0);
  if (lines.isNotEmpty && lines.last.trim().isEmpty) {
    lines.removeAt(lines.length - 1);
  }
  return lines;
}

// ──────────────────────────────────────────────
// 模块定义
// ──────────────────────────────────────────────

/// 一个可剪枝的示例模块。
final class PruneModule {
  const new({
    required this.name,
    required this.dirs,
    required this.files,
    required this.edits,
    required this.fingerprints,
  });

  /// 命令行里的名字（`--modules=article,demo`）。
  final String name;

  /// 直接删除的目录。
  final List<String> dirs;

  /// 直接删除的单文件。
  final List<String> files;

  /// 引用清理点。
  final List<PruneEdit> edits;

  /// 残留扫描用的标识符。
  ///
  /// 必须具体到不会误伤：裸 `Article` 不能当指纹 —— 网络测试里
  /// `RequestOptions(path: '/articles')` 只是一条示例 URL，与 feature 无关。
  final List<String> fingerprints;
}

/// `article` 示例模块。
final PruneModule articleModule = PruneModule(
  name: 'article',
  dirs: const ['lib/features/article', 'test/features/article'],
  files: const ['lib/core/data/database/tables/db_articles.dart'],
  edits: [
    // ── Drift 缓存表：表定义删了，schema 声明要一起改 ──
    ReplaceBlock(
      path: 'lib/core/data/database/app_database.dart',
      label: 'db_articles.dart 的 part 声明',
      old: _block('''
        part 'app_database.g.dart';

        // 表必须 part 进来（drift 要求表与数据库同 library；改 import 会让 DAO 生成失败）
        part 'tables/db_articles.dart';
      '''),
      replacement: _block('''
        part 'app_database.g.dart';
      '''),
    ),
    // 删掉整个参数而不是写成 `tables: []` —— 空列表会被
    // avoid_redundant_argument_values 判为冗余实参（--fatal-infos 下红）。
    ReplaceBlock(
      path: 'lib/core/data/database/app_database.dart',
      label: '@DriftDatabase 的表列表',
      old: _block('''
        @DriftDatabase(tables: [DbArticles])
      '''),
      replacement: _block('''
        @DriftDatabase()
      '''),
    ),
    // ── 路由表 ──
    DeleteBlock(
      path: 'lib/app/routing/router.dart',
      label: 'article 的三行 import',
      lines: _block('''
        import 'package:my_app/features/article/logic/article_view_model.dart';
        import 'package:my_app/features/article/page/article_detail_page.dart';
        import 'package:my_app/features/article/page/article_list_page.dart';
      '''),
    ),
    ReplaceBlock(
      path: 'lib/app/routing/router.dart',
      label: 'import 上方那条「三个类型」注释',
      old: _block('''
        // `logic/` 的三个类型是生成物 `router.gr.dart` 里路由 Args 的字段类型：
      '''),
      replacement: _block('''
        // `logic/` 的类型是生成物 `router.gr.dart` 里路由 Args 的字段类型：
      '''),
    ),
    DeleteBlock(
      path: 'lib/app/routing/router.dart',
      label: 'MainRoute 子路由里的 articles',
      lines: _block('''
        AutoRoute(path: 'articles', page: ArticleListRoute.page),
      '''),
    ),
    ReplaceBlock(
      path: 'lib/app/routing/router.dart',
      label: '文章详情路由',
      old: _block('''
        ),

        // 文章详情（不经过底部导航）—— 需登录
        AutoRoute(
          path: '/articles/:id',
          page: ArticleDetailRoute.page,
          guards: [AutoRouteGuard.simple(_checkAuth)],
        ),
      '''),
      replacement: _block('''
        ),
      '''),
    ),
    // ── Mock 规则：两条 /articles 规则整体删掉 ──
    DeleteBlock(
      path: 'lib/core/data/network/dio_client.dart',
      label: '两条 /articles Mock 规则',
      lines: _block(r"""
        MockRegistry.register(
          MockRule.regex(
            pattern: r'/articles$',
            method: 'GET',
            handler: (_) => MockResponse.text(
              '''
[
  {"id": 1, "title": "Flutter 3.44 新特性解析", "body": "Flutter 3.44 新特性详情..."},
  {"id": 2, "title": "Dart 3.12 模式匹配实战", "body": "Dart 3.12 模式匹配详解..."}
]''',
              headers: {'content-type': 'application/json'},
            ),
          ),
        );
        MockRegistry.register(
          MockRule.regex(
            pattern: r'/articles/\d+$',
            method: 'GET',
            handler: (_) => MockResponse.text(
'{"id":1,"title":"Flutter 3.44 新特性解析","body":"Flutter 3.44 新特性详情..."}',
              headers: {'content-type': 'application/json'},
            ),
          ),
        );
"""),
    ),
    ReplaceBlock(
      path: 'lib/core/data/network/dio_client.dart',
      label: '「具体端点」注释里举的 /articles',
      old: _block('''
        /// 通用 Dio 装配不该知道 `/articles` / `/login` 这类业务路径。
      '''),
      replacement: _block('''
        /// 通用 Dio 装配不该知道 `/login` / `/refresh` 这类业务路径。
      '''),
    ),
    // ── 主框架标签：删中间那项后 labelStyle 索引必须重排 ──
    ReplaceBlock(
      path: 'lib/features/home/page/main_page.dart',
      label: '_tabs 与「不是 const」注释',
      old: _block('''
        /// 三个标签对应的路由，顺序即索引
        ///
        /// 不是 `const`：`ArticleListRoute` 带路由参数（页面有可选注入点，见
        /// ui/state-management.md），构造函数不是 const 的。
        static final List<PageRouteInfo> _tabs = [
          const HomeRoute(),
          ArticleListRoute(),
          const ProfileRoute(),
        ];
      '''),
      replacement: _block('''
        /// 两个标签对应的路由，顺序即索引
        static const List<PageRouteInfo> _tabs = [HomeRoute(), ProfileRoute()];
      '''),
    ),
    DeleteBlock(
      path: 'lib/features/home/page/main_page.dart',
      label: 'NavigationRail 的文章 destination',
      lines: _block("""
        NavigationRailDestination(
          icon: Icon(
            Icons.article_outlined,
            color: colorScheme.onSurface.withValues(alpha: 0.6),
          ),
          selectedIcon: Icon(
            Icons.article,
            color: colorScheme.primary,
          ),
          label: Text('文章', style: labelStyle(1)),
        ),
      """),
    ),
    ReplaceBlock(
      path: 'lib/features/home/page/main_page.dart',
      label: 'NavigationRail 的「我的」标签索引',
      old: _block("""
        label: Text('我的', style: labelStyle(2)),
      """),
      replacement: _block("""
        label: Text('我的', style: labelStyle(1)),
      """),
    ),
    DeleteBlock(
      path: 'lib/features/home/page/main_page.dart',
      label: 'NavigationBar 的文章 destination',
      lines: _block("""
        NavigationDestination(
          icon: Icon(
            Icons.article_outlined,
            color: colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          selectedIcon: Icon(
            Icons.article,
            color: colorScheme.primary,
          ),
          label: '文章',
        ),
      """),
    ),
    // ── 首页快捷入口：卡片连同它后面那个间距一起删，否则留一道空白 ──
    DeleteBlock(
      path: 'lib/features/home/page/home_page.dart',
      label: '「文章」快捷入口卡片',
      lines: _block("""
        Expanded(
          child: _QuickActionCard(
            icon: Icons.article_outlined,
            label: '文章',
            color: colorScheme.tertiary,
            gradientColors: [
              colorScheme.tertiaryContainer,
              colorScheme.tertiaryContainer.withValues(alpha: 0.6),
            ],
            iconColor: colorScheme.onTertiaryContainer,
            onTap: () => context.pushRoute(ArticleListRoute()),
          ),
        ),
        const SizedBox(width: 12),
      """),
    ),
    // ── 主框架测试 ──
    DeleteBlock(
      path: 'test/routing/main_shell_test.dart',
      label: 'article 的四行 import',
      lines: _block('''
        import 'package:my_app/features/article/data/article_repository.dart';
        import 'package:my_app/features/article/data/models/article.dart';
        import 'package:my_app/features/article/logic/article_view_model.dart';
        import 'package:my_app/features/article/page/article_list_page.dart';
      '''),
    ),
    ReplaceBlock(
      path: 'test/routing/main_shell_test.dart',
      label: 'MockArticleRepository 桩类',
      old: _block('''
        class MockAuthRepository extends Mock implements AuthRepository;

        class MockArticleRepository extends Mock implements ArticleRepository;
      '''),
      replacement: _block('''
        class MockAuthRepository extends Mock implements AuthRepository;
      '''),
    ),
    ReplaceBlock(
      path: 'test/routing/main_shell_test.dart',
      label: 'articleRepo 的装配',
      old: _block('''
final authRepo = MockAuthRepository();
when(authRepo.logout).thenAnswer((_) async => const Result.success(null));
final articleRepo = MockArticleRepository();
when(articleRepo.getArticles)
    .thenAnswer((_) async => const Result.success(<Article>[]));

await GetIt.I.reset();
      '''),
      replacement: _block('''
final authRepo = MockAuthRepository();
when(authRepo.logout).thenAnswer((_) async => const Result.success(null));

await GetIt.I.reset();
      '''),
    ),
    DeleteBlock(
      path: 'test/routing/main_shell_test.dart',
      label: 'ArticleViewModel 的 DI 注册',
      lines: _block('''
        GetIt.I.registerFactory<ArticleViewModel>(
          () => ArticleViewModel(articleRepo),
        );
      '''),
    ),
    ReplaceBlock(
      path: 'test/routing/main_shell_test.dart',
      label: '「点击底部导航切换标签」用例里的文章标签',
      old: _block("""
        await tester.tap(tabLabel('文章'));
        await tester.pumpAndSettle();
        expect(find.byType(ArticleListPage), findsOneWidget);
        expect(selectedTabIndex(tester), 1);

        await tester.tap(tabLabel('我的'));
        await tester.pumpAndSettle();
        expect(find.byType(ProfilePage), findsOneWidget);
        expect(selectedTabIndex(tester), 2);
      """),
      // 剪掉文章标签后「我的」成了索引 1，这条用例改成从「我的」切回「首页」
      replacement: _block("""
        await tester.tap(tabLabel('我的'));
        await tester.pumpAndSettle();
        expect(find.byType(ProfilePage), findsOneWidget);
        expect(selectedTabIndex(tester), 1);
      """),
    ),
    ReplaceBlock(
      path: 'test/routing/main_shell_test.dart',
      label: '「高亮跟随路由栈」用例：换成个人页（验的东西不变）',
      old: _block('''
        // 文章页此刻还没被加载过（lazyLoad）
        expect(find.byType(ArticleListPage), findsNothing);
        
        // 模拟「由别处发起」的标签切换：首页的快捷入口、深链、返回栈都会走这条路。
        // 旧实现把索引存在 State 里，此时高亮会错位停在首页。
        final context = tester.element(find.byType(HomePage));
        unawaited(AutoTabsRouter.of(context).navigate(ArticleListRoute()));
        await tester.pumpAndSettle();
        
        expect(find.byType(ArticleListPage), findsOneWidget);
        expect(selectedTabIndex(tester), 1);
      '''),
      replacement: _block('''
        // 个人页此刻还没被加载过（lazyLoad）
        expect(find.byType(ProfilePage), findsNothing);
        
        // 模拟「由别处发起」的标签切换：首页的快捷入口、深链、返回栈都会走这条路。
        // 旧实现把索引存在 State 里，此时高亮会错位停在首页。
        final context = tester.element(find.byType(HomePage));
        unawaited(AutoTabsRouter.of(context).navigate(const ProfileRoute()));
        await tester.pumpAndSettle();
        
        expect(find.byType(ProfilePage), findsOneWidget);
        expect(selectedTabIndex(tester), 1);
      '''),
    ),
    ReplaceBlock(
      path: 'test/routing/main_shell_test.dart',
      label: '「宽屏侧边导航栏」用例的导航目标',
      old: _block('''
final context = tester.element(find.byType(HomePage));
unawaited(AutoTabsRouter.of(context).navigate(ArticleListRoute()));
await tester.pumpAndSettle();

expect(
  tester.widget<NavigationRail>(find.byType(NavigationRail)).selectedIndex,
  1,
);
      '''),
      replacement: _block('''
final context = tester.element(find.byType(HomePage));
unawaited(AutoTabsRouter.of(context).navigate(const ProfileRoute()));
await tester.pumpAndSettle();

expect(
  tester.widget<NavigationRail>(find.byType(NavigationRail)).selectedIndex,
  1,
);
      '''),
    ),
    // ── 其余两处测试装配 ──
    DeleteBlock(
      path: 'test/app/pages/splash_page_test.dart',
      label: 'article 的三行 import',
      lines: _block('''
        import 'package:my_app/features/article/data/article_repository.dart';
        import 'package:my_app/features/article/data/models/article.dart';
        import 'package:my_app/features/article/logic/article_view_model.dart';
      '''),
    ),
    ReplaceBlock(
      path: 'test/app/pages/splash_page_test.dart',
      label: 'MockArticleRepository 桩类',
      old: _block('''
        class MockAuthRepository extends Mock implements AuthRepository;

        class MockArticleRepository extends Mock implements ArticleRepository;
      '''),
      replacement: _block('''
        class MockAuthRepository extends Mock implements AuthRepository;
      '''),
    ),
    ReplaceBlock(
      path: 'test/app/pages/splash_page_test.dart',
      label: 'articleRepo 的装配',
      old: _block('''
final authRepo = MockAuthRepository();
when(authRepo.logout).thenAnswer((_) async => const Result.success(null));
final articleRepo = MockArticleRepository();
when(articleRepo.getArticles)
    .thenAnswer((_) async => const Result.success(<Article>[]));

await GetIt.I.reset();
      '''),
      replacement: _block('''
final authRepo = MockAuthRepository();
when(authRepo.logout).thenAnswer((_) async => const Result.success(null));

await GetIt.I.reset();
      '''),
    ),
    DeleteBlock(
      path: 'test/app/pages/splash_page_test.dart',
      label: 'ArticleViewModel 的 DI 注册',
      lines: _block('''
        GetIt.I.registerFactory<ArticleViewModel>(
          () => ArticleViewModel(articleRepo),
        );
      '''),
    ),
    // ── Drift 表的两个专门用例：表没了就没有被测对象 ──
    DeleteBlock(
      path: 'test/core/data/database/app_database_test.dart',
      label: 'drift/drift.dart import（只被表用例用到）',
      lines: _block('''
        import 'package:drift/drift.dart';
      '''),
    ),
    ReplaceBlock(
      path: 'test/core/data/database/app_database_test.dart',
      label: '「建表后可以写入并读回行」用例',
      old: _block('''
        test('schemaVersion 与表结构一致', () {
          expect(createInMemoryDb().schemaVersion, 1);
        });

        test('建表后可以写入并读回行', () async {
          final db = createInMemoryDb();

          await db
              .into(db.dbArticles)
              .insert(
                const DbArticlesCompanion(
                  id: Value(1),
                  title: Value('标题'),
                  body: Value('正文'),
                ),
              );

          final rows = await db.select(db.dbArticles).get();

          expect(rows, hasLength(1));
          expect(rows.single, isA<DbArticle>());
          expect(rows.single.id, 1);
          expect(rows.single.title, '标题');
          expect(rows.single.body, '正文');
        });
      '''),
      replacement: _block('''
        test('schemaVersion 与表结构一致', () {
          expect(createInMemoryDb().schemaVersion, 1);
        });
      '''),
    ),
    ReplaceBlock(
      path: 'test/core/data/database/app_database_test.dart',
      label: '「id 是主键」用例',
      old: _block('''
        test('id 是主键：同 id 再写一次会冲突而不是插出两行', () async {
          final db = createInMemoryDb();
          const row = DbArticlesCompanion(
            id: Value(7),
            title: Value('A'),
            body: Value('a'),
          );

          await db.into(db.dbArticles).insert(row);

          await expectLater(
            db.into(db.dbArticles).insert(row),
            throwsA(isA<SqliteException>()),
          );
          expect(await db.select(db.dbArticles).get(), hasLength(1));
        });

        test('默认构造器走 path_provider 提供的目录并建库文件', () async {
      '''),
      replacement: _block('''
        test('默认构造器走 path_provider 提供的目录并建库文件', () async {
      '''),
    ),
    // ── 首页结构测试里对「文章」快捷入口的断言 ──
    DeleteBlock(
      path: 'test/features/home/page/home_page_test.dart',
      label: '「文章」快捷入口断言',
      lines: _block("""
        expect(find.text('文章'), findsOneWidget);
      """),
    ),
    // ── 注释里的散文引用：grep 与门禁都抓不到，只能显式列 ──
    ReplaceBlock(
      path: 'test/support/fake_path_provider.dart',
      label: '注释里举的 test/features/demo 路径',
      old: _block('''
/// 被 `test/core/data/{storage,database}/` 与 `test/features/demo/` 下的测试共用。
      '''),
      replacement: _block('''
        /// 被 `test/core/data/{storage,database}/` 下的测试共用。
      '''),
    ),
    ReplaceBlock(
      path: 'test/core/base/signal_builder_widget_test.dart',
      label: '注释里举的 ArticleViewModel',
      old: _block('''
// Use a list signal to match the common pattern (e.g., ArticleViewModel)
      '''),
      replacement: _block('''
// Use a list signal to match the common pattern (e.g., a list ViewModel)
      '''),
    ),
  ],
  fingerprints: const [
    'ArticleListRoute',
    'ArticleDetailRoute',
    'ArticleListPage',
    'ArticleDetailPage',
    'ArticleViewModel',
    'ArticleService',
    'ArticleRepository',
    'ArticleDao',
    'ArticleModule',
    'DbArticles',
    // 路径形态也要有：AGENTS.md:117 与 README 是拿 `lib/features/article/` 指路的，
    // 只用类名当指纹的话，这些「按路径引用示例」的位置永远不会出现在清单里。
    'features/article',
  ],
);

/// `demo` 示例模块。
final PruneModule demoModule = PruneModule(
  name: 'demo',
  dirs: const ['lib/features/demo', 'test/features/demo'],
  files: const [],
  edits: [
    DeleteBlock(
      path: 'lib/app/routing/router.dart',
      label: 'demo 的两行 import',
      lines: _block('''
import 'package:my_app/features/demo/logic/storage_demo_view_model.dart';
        import 'package:my_app/features/demo/page/storage_demo_page.dart';
      '''),
    ),
    ReplaceBlock(
      path: 'lib/app/routing/router.dart',
      label: '本地存储示例路由',
      old: _block('''
        // 本地存储示例（入口在「个人 → 设置」）—— 需登录
        AutoRoute(
          path: '/storage-demo',
          page: StorageDemoRoute.page,
          guards: [AutoRouteGuard.simple(_checkAuth)],
        ),

        // 404
      '''),
      replacement: _block('''
        // 404
      '''),
    ),
    // 连同它上面那条 SettingDivider 一起删，否则最后一条分隔线悬空
    DeleteBlock(
      path: 'lib/features/profile/page/profile_settings.dart',
      label: '「本地存储示例」设置项',
      lines: _block("""
        const SettingDivider(),
        // 示例入口：演示 core 的 FileStorage 与 Drift 缓存。
        // 用不到这两个设施时，连同 features/demo/ 一起删掉即可。
        SettingItem(
          icon: Icons.folder_outlined,
          title: '本地存储示例',
          onTap: () => context.pushRoute(StorageDemoRoute()),
        ),
      """),
    ),
    // 示例入口删掉后，它为 `context.pushRoute(StorageDemoRoute())` 带来的两个
    // import 就没人用了（analyze 的 unused_import）。残留扫描看不到它们 ——
    // import 文本里没有指纹标识符，只能显式列。
    ReplaceBlock(
      path: 'lib/features/profile/page/profile_settings.dart',
      label: '「本地存储示例」入口用到的两个 import',
      old: _block('''
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:my_app/app/routing/router.dart';
      '''),
      replacement: _block('''
import 'package:flutter/material.dart';
      '''),
    ),
    ReplaceBlock(
      path: 'lib/features/profile/page/profile_settings.dart',
      label: '文件头注释里多出来的那个入口',
      old: _block('''
        /// 个人中心的「设置」区块：外观选择 + 三个模板占位入口 + 本地存储示例入口。
      '''),
      replacement: _block('''
        /// 个人中心的「设置」区块：外观选择 + 三个模板占位入口。
      '''),
    ),
  ],
  fingerprints: const [
    'StorageDemoRoute',
    'StorageDemoViewModel',
    'StorageDemoPage',
    'features/demo',
  ],
);

/// 可剪枝模块表。`auth` 故意不在其中 —— 见文件头。
final Map<String, PruneModule> pruneModules = {
  articleModule.name: articleModule,
  demoModule.name: demoModule,
};

/// `auth` 被显式点名时的拒绝文案。
const String authRejection = '''
❌ `auth` 不参与剪枝：它是基础设施，不是示例。

  AuthStorage 被路由守卫（lib/app/routing/router.dart）实时读取；
  auth_interceptor / token_refresher / token_store 在网络层；
  lib/app/app.dart 用 AuthReevaluateListenable 接线。

  删掉它等于重做认证与守卫骨架 —— 那是架构改造，不是剪枝。要改成无登录的
  应用，请按 docs/template-pruning.md 的「auth 手工改造」一节动手。''';

// ──────────────────────────────────────────────
// 规划：先算清楚，一个字节都不写
// ──────────────────────────────────────────────

/// 一条已解析出具体行区间的编辑，[start] / [end] 都是 0-based 且含两端。
final class ResolvedEdit {
  const new({
    required this.path,
    required this.label,
    required this.start,
    required this.end,
    required this.replacement,
  });

  final String path;
  final String label;
  final int start;
  final int end;
  final List<String> replacement;
}

/// 剪枝计划。`failures` 非空就整件事中止。
final class PrunePlan {
  const new({
    required this.dirs,
    required this.files,
    required this.edits,
    required this.failures,
    required this.alreadyPruned,
  });

  /// 待删除的目录（存在于磁盘）。
  final List<String> dirs;

  /// 待删除的单文件（存在于磁盘）。
  final List<String> files;

  /// 待应用的编辑。
  final List<ResolvedEdit> edits;

  /// 锚点没对上的项；非空 = 中止。
  final List<String> failures;

  /// 目录已不存在、识别为「已剪枝」的模块名。
  final List<String> alreadyPruned;

  bool get ok => failures.isEmpty;

  /// 会被改写的文件数（去重）。
  int get touchedFileCount => edits.map((e) => e.path).toSet().length;
}

/// 在 [fileLines] 里找 [block]（逐行 trim 比较），返回全部命中的起始行号。
List<int> findBlockStarts(List<String> fileLines, List<String> block) {
  final starts = <int>[];
  if (block.isEmpty || block.length > fileLines.length) return starts;
  for (var i = 0; i <= fileLines.length - block.length; i++) {
    var matched = true;
    for (var j = 0; j < block.length; j++) {
      if (fileLines[i + j].trim() != block[j].trim()) {
        matched = false;
        break;
      }
    }
    if (matched) starts.add(i);
  }
  return starts;
}

/// 一个字符串开头那段空白（缩进）。
String leadingWhitespace(String line) {
  final match = RegExp(r'^\s*').firstMatch(line);
  return match?.group(0) ?? '';
}

/// 把替换块按命中位置的缩进重排。
///
/// 锚点是逐行 trim 比较的，所以锚点表可以随手缩进；但 [ReplaceBlock.replacement]
/// 是**逐字写进文件**的 —— 不重排的话，工具源码里的那层缩进会一起落到目标文件里。
/// 做法：取替换块自身非空行的最小缩进作基准，剥掉它，再套上命中行的缩进。
List<String> reindentReplacement(List<String> replacement, String matchedLine) {
  final indent = leadingWhitespace(matchedLine);
  final nonEmpty = replacement.where((line) => line.trim().isNotEmpty);
  if (nonEmpty.isEmpty) return replacement;

  final base = nonEmpty
      .map(leadingWhitespace)
      .reduce((a, b) => a.length <= b.length ? a : b);
  return [
    for (final line in replacement)
      if (line.trim().isEmpty)
        ''
      else
        '$indent${_stripIndent(line, base.length)}',
  ];
}

/// 剥掉 [line] 开头的 [count] 个空白字符（不足就全剥）。
String _stripIndent(String line, int count) {
  final length = leadingWhitespace(line).length;
  return line.substring(length < count ? length : count);
}

/// 读取文件的文本行。行尾统一按 `\n` 切（比较时又逐行 trim，所以 CRLF 也能对）。
List<String> readLines(File file) =>
    file.readAsStringSync().split(RegExp(r'\r\n|\n'));

/// 规划一次剪枝。[modules] 是要剪的模块，[root] 是仓库根。
PrunePlan buildPlan(Directory root, List<PruneModule> modules) {
  final failures = <String>[];
  final alreadyPruned = <String>[];
  final dirs = <String>[];
  final files = <String>[];
  final edits = <ResolvedEdit>[];

  for (final module in modules) {
    final existingDirs = module.dirs
        .where((d) => Directory('${root.path}/$d').existsSync())
        .toList();
    if (existingDirs.isEmpty && module.dirs.isNotEmpty) {
      alreadyPruned.add(module.name);
    }
    dirs.addAll(existingDirs);

    for (final path in module.files) {
      if (File('${root.path}/$path').existsSync()) {
        files.add(path);
      } else {
        failures.add('$path — 文件不存在（${module.name}）');
      }
    }

    for (final edit in module.edits) {
      final file = File('${root.path}/${edit.path}');
      if (!file.existsSync()) {
        failures.add('${edit.path} — 文件不存在（清理点：${edit.label}）');
        continue;
      }
      final lines = readLines(file);
      final (block, replacement) = switch (edit) {
        DeleteBlock(:final lines) => (lines, const <String>[]),
        ReplaceBlock(:final old, :final replacement) => (old, replacement),
      };
      final starts = findBlockStarts(lines, block);
      if (starts.length != 1) {
        failures.add(
          '${edit.path} — 「${edit.label}」期望命中 1 次，实际 ${starts.length} 次',
        );
        continue;
      }
      edits.add(
        ResolvedEdit(
          path: edit.path,
          label: edit.label,
          start: starts.single,
          end: starts.single + block.length - 1,
          replacement: reindentReplacement(replacement, lines[starts.single]),
        ),
      );
    }
  }

  // 同一文件里区间重叠 = 锚点表自己写错了，也必须中止而不是硬删
  final byPath = <String, List<ResolvedEdit>>{};
  for (final edit in edits) {
    byPath.putIfAbsent(edit.path, () => []).add(edit);
  }
  for (final entry in byPath.entries) {
    final sorted = [...entry.value]..sort((a, b) => a.start - b.start);
    for (var i = 1; i < sorted.length; i++) {
      if (sorted[i].start <= sorted[i - 1].end) {
        final previous = sorted[i - 1].label;
        final current = sorted[i].label;
        failures.add('${entry.key} — 锚点区间重叠：「$previous」与「$current」');
      }
    }
  }

  return PrunePlan(
    dirs: dirs,
    files: files,
    edits: edits,
    failures: failures,
    alreadyPruned: alreadyPruned,
  );
}

/// 写盘结果。
final class ApplyResult {
  const new({
    required this.deletedDirs,
    required this.deletedFiles,
    required this.updatedFiles,
  });

  final List<String> deletedDirs;
  final List<String> deletedFiles;
  final List<String> updatedFiles;
}

/// 应用计划：删目录 / 删文件 / 按行区间改写。
///
/// 同一文件的多个区间**从后往前**改，这样前面的行号不会被后面的改动挪走。
ApplyResult applyPlan(Directory root, PrunePlan plan) {
  final deletedDirs = <String>[];
  for (final path in plan.dirs) {
    Directory('${root.path}/$path').deleteSync(recursive: true);
    deletedDirs.add(path);
  }

  final deletedFiles = <String>[];
  for (final path in plan.files) {
    File('${root.path}/$path').deleteSync();
    deletedFiles.add(path);
  }

  final byPath = <String, List<ResolvedEdit>>{};
  for (final edit in plan.edits) {
    byPath.putIfAbsent(edit.path, () => []).add(edit);
  }

  final updatedFiles = <String>[];
  for (final entry in byPath.entries) {
    final file = File('${root.path}/${entry.key}');
    final source = file.readAsStringSync();
    final newline = source.contains('\r\n') ? '\r\n' : '\n';
    final lines = source.split(RegExp(r'\r\n|\n'));

    final sorted = [...entry.value]..sort((a, b) => b.start - a.start);
    for (final edit in sorted) {
      lines.replaceRange(edit.start, edit.end + 1, edit.replacement);
    }

    file.writeAsStringSync(lines.join(newline));
    updatedFiles.add(entry.key);
  }

  deletedDirs.sort();
  deletedFiles.sort();
  updatedFiles.sort();
  return ApplyResult(
    deletedDirs: deletedDirs,
    deletedFiles: deletedFiles,
    updatedFiles: updatedFiles,
  );
}

// ──────────────────────────────────────────────
// 残留扫描
// ──────────────────────────────────────────────

/// 一处残留。
final class ResidueHit {
  const new({
    required this.path,
    required this.line,
    required this.text,
    required this.term,
  });

  final String path;
  final int line;
  final String text;
  final String term;

  @override
  String toString() => '$path:$line: $text';
}

// 生成物判定在上面（`isGeneratedPath`），与 app_lints 的口径逐条对齐。

/// 剪枝工具自己与它的测试。
const List<String> pruneToolingPaths = [
  'tool/prune_examples.dart',
  'test/tool/prune_examples_test.dart',
];

/// [relativePath] 是否属于「剪枝工具自身」。
///
/// 这两份文件**必然**包含被剪模块的标识符 —— 锚点表里写的就是它们，测试里还要
/// 拿它们当预期值。残留扫描必须跳过，否则每次运行都会「成功地」报出自己。
bool isPruneToolingPath(String relativePath) =>
    pruneToolingPaths.contains(relativePath);

/// 扫 `lib/` 与 `test/` 下的 .dart 文件。
///
/// [includeGenerated] 为 false 时跳过生成物 —— 没跑 codegen 的话，
/// `router.gr.dart` 里必然还留着已删的路由类，扫它只会误报。
List<ResidueHit> scanCodeResidue(
  Directory root,
  List<PruneModule> modules, {
  required bool includeGenerated,
}) {
  final hits = <ResidueHit>[];
  for (final dir in ['lib', 'test']) {
    final target = Directory('${root.path}/$dir');
    if (!target.existsSync()) continue;
    for (final entity in target.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final relative = _relative(root, entity.path);
      if (isPruneToolingPath(relative)) continue;
      if (!includeGenerated && isGeneratedPath(relative)) continue;
      _collectHits(root, entity, modules, hits);
    }
  }
  return hits;
}

/// 扫文档侧：`AGENTS.md` / `README.md` / `docs/` / `.trellis/spec/`。
///
/// 刻意不扫 `.trellis/tasks/` 与 `.trellis/workspace/` —— 任务与日志里提到示例
/// 模块是正常的，扫它们只会把清单淹掉。
List<ResidueHit> scanDocResidue(Directory root, List<PruneModule> modules) {
  final hits = <ResidueHit>[];
  final files = <File>[
    for (final name in ['AGENTS.md', 'README.md']) File('${root.path}/$name'),
    for (final dir in ['docs', '.trellis/spec'])
      ..._markdownUnder(Directory('${root.path}/$dir')),
    File('${root.path}/.trellis/workflow.md'),
  ];

  for (final file in files) {
    if (!file.existsSync()) continue;
    _collectHits(root, file, modules, hits);
  }
  return hits;
}

List<File> _markdownUnder(Directory dir) {
  if (!dir.existsSync()) return const [];
  return [
    for (final entity in dir.listSync(recursive: true))
      if (entity is File && entity.path.endsWith('.md')) entity,
  ];
}

void _collectHits(
  Directory root,
  File file,
  List<PruneModule> modules,
  List<ResidueHit> hits,
) {
  final terms = {for (final module in modules) ...module.fingerprints};
  if (terms.isEmpty) return;

  final lines = readLines(file);
  for (var i = 0; i < lines.length; i++) {
    for (final term in terms) {
      if (lines[i].contains(term)) {
        hits.add(
          ResidueHit(
            path: _relative(root, file.path),
            line: i + 1,
            text: lines[i].trim(),
            term: term,
          ),
        );
        break;
      }
    }
  }
}

String _relative(Directory root, String path) {
  final rootPath = root.path.replaceAll(r'\', '/');
  final normalized = path.replaceAll(r'\', '/');
  if (normalized.startsWith('$rootPath/')) {
    return normalized.substring(rootPath.length + 1);
  }
  return normalized;
}

// ──────────────────────────────────────────────
// 外部命令
// ──────────────────────────────────────────────

/// 跑一条外部命令（[command] 含可执行文件本身）。
typedef ProcessRunner = Future<ProcessResult> Function(
  List<String> command,
  String workingDirectory,
);

Future<ProcessResult> _defaultRunProcess(
  List<String> command,
  String workingDirectory,
) {
  return Process.run(
    command.first,
    command.sublist(1),
    workingDirectory: workingDirectory,
  );
}

/// 工作区里未提交的改动；干净则返回 null。
///
/// **忽略 `.trellis/`**：任务元数据本就未入库，而剪枝正是在任务内运行的 ——
/// 不忽略的话工具会把自己拒掉。
Future<String?> dirtyWorktree(ProcessRunner run, Directory root) async {
  final ProcessResult result;
  try {
    result = await run(['git', 'status', '--porcelain'], root.path);
  } on ProcessException catch (error) {
    return 'git 跑不起来：${error.message}';
  }
  if (result.exitCode != 0) {
    return 'git status 退出码 ${result.exitCode}';
  }

  final lines = (result.stdout as String)
      .split('\n')
      .map((line) => line.trimRight())
      .where((line) => line.trim().isNotEmpty)
      .where((line) => !line.contains('.trellis/'))
      .toList();
  return lines.isEmpty ? null : lines.join('\n');
}

// ──────────────────────────────────────────────
// 输出
// ──────────────────────────────────────────────

void _print(String message) => stdout.writeln(message);

String _prompt(String label, String fallback) {
  stdout.write('$label [$fallback]: ');
  final input = stdin.readLineSync()?.trim() ?? '';
  return input.isEmpty ? fallback : input;
}

/// 只留尾部若干行：构建输出动辄几百行，全打出来反而看不到重点。
String _tail(String output, {int lines = 30}) {
  final all = output.trimRight().split('\n');
  if (all.length <= lines) return all.join('\n');
  return '…（只显示末尾 $lines 行）\n${all.sublist(all.length - lines).join('\n')}';
}

const String _rollback =
    '  回滚：git checkout -- . && git clean -fd（要求剪枝前工作区是干净的）';

const String _usage = '''
用法：dart run tool/prune_examples.dart [选项]

把示例模块（article / demo）连同它的全部引用一次删干净，然后重跑 codegen 与门禁。
**auth 不参与剪枝** —— 它是基础设施不是示例，见 docs/template-pruning.md。

不带选项时进入交互模式。带 --modules= 或 --yes 则完全不提问。

选项：
  --modules=<模块列表>   要剪的模块，逗号分隔：article,demo
  --yes, -y              跳过确认
  --no-verify            不跑 codegen 与 just verify，只打印下一步命令
  --force                越过「工作区不干净」的检查（供测试与非 git 环境）
  --help, -h             显示本帮助

例：
  dart run tool/prune_examples.dart --yes --modules=article,demo''';

const String _postPruneNotes = '''
  注意：FileStorage 与 AppDatabase 是 core 能力，本工具**有意保留**它们
  （删掉示例后它们没有应用内消费者，只剩 DI 注册与各自的单元测试）。确定不要
  就手删 —— `grep -rn "FileStorage" lib/` 能列出全部引用。''';

// ──────────────────────────────────────────────
// 入口
// ──────────────────────────────────────────────

/// 跑一遍剪枝流程，返回进程退出码（0 = 成功）。
///
/// 与 `tool/init_project.dart` 一样返回退出码而不是直接 `exit()`：回归测试可以
/// 直接调用它，断言退出码与文案。[prompt] / [out] / [runProcess] 都是为了把 IO
/// 注入出来，夹具测试因此不必真跑 build_runner。
Future<int> runCli(
  List<String> args, {
  required Directory root,
  String Function(String label, String fallback) prompt = _prompt,
  void Function(String message) out = _print,
  ProcessRunner? runProcess,
}) async {
  final run = runProcess ?? _defaultRunProcess;
  void say(String message) => out(message);

  final CliOptions options;
  try {
    options = parseArgs(args);
  } on FormatException catch (error) {
    say('❌ ${error.message}');
    say('');
    say(_usage);
    return _failed;
  }

  if (options.help) {
    say(_usage);
    return _ok;
  }

  // ── 1. 选定模块（写盘之前的一切检查都在这之后、apply 之前）──
  final rawModules =
      options.modules ?? prompt('要剪枝的模块（逗号分隔 article,demo；留空=取消）', '');
  final requested = rawModules
      .split(',')
      .map((name) => name.trim())
      .where((name) => name.isNotEmpty)
      .toList();

  if (requested.isEmpty) {
    say('已取消，未改动任何文件。');
    return _ok;
  }

  if (requested.contains('auth')) {
    say(authRejection);
    return _rejected;
  }

  final unknown = requested.where((name) => !pruneModules.containsKey(name));
  if (unknown.isNotEmpty) {
    say('❌ 未知模块：${unknown.join('、')}');
    say('  可剪的模块：${pruneModules.keys.join('、')}');
    say('  （auth 不参与剪枝，理由见 --help）');
    return _rejected;
  }

  final modules = requested.map((name) => pruneModules[name]!).toList();

  // ── 2. 前置检查：工作区必须干净，因为下一步是不可逆删除 ──
  if (!options.force) {
    final dirty = await dirtyWorktree(run, root);
    if (dirty != null) {
      say('❌ 工作区不干净，已中止（本工具做的是不可逆删除，需要一个干净基线）：');
      say(dirty);
      say('');
      say('  先提交或 stash 你的改动；确实要越过请加 --force。');
      return _rejected;
    }
  }

  // ── 3. 规划：锚点必须条条对上，否则一个字节都不写 ──
  final plan = buildPlan(root, modules);

  if (plan.alreadyPruned.length == modules.length) {
    say('这些模块已经剪过了，无需处理：${plan.alreadyPruned.join('、')}');
    return _ok;
  }

  if (!plan.ok) {
    say('❌ 以下清理点没有对上，已中止（没有写入任何文件）：');
    for (final failure in plan.failures) {
      say('  • $failure');
    }
    say('');
    say('  多半是这几处已经被手工改过。对照 .trellis/spec 或 design.md 里的锚点清单，');
    say('  把工具里对应的锚点改成现状（tool/prune_examples.dart）。');
    return _failed;
  }

  if (plan.alreadyPruned.isNotEmpty) {
    say('已跳过（目录不存在，视为剪过）：${plan.alreadyPruned.join('、')}');
  }

  // ── 4. 确认 ──
  say('将执行：');
  for (final dir in plan.dirs) {
    say('  • 删除目录 $dir/');
  }
  for (final file in plan.files) {
    say('  • 删除文件 $file');
  }
  say('  • 修改 ${plan.touchedFileCount} 个文件、共 ${plan.edits.length} 处引用');
  say('');
  say(_rollback);
  say('');

  if (options.assumeYes) {
    // 非交互：不确认
  } else {
    final confirm = prompt('继续？(y/N)', 'n');
    if (confirm.toLowerCase() != 'y') {
      say('已取消，未改动任何文件。');
      return _ok;
    }
  }

  // ── 5. 写盘 ──
  final applied = applyPlan(root, plan);
  say('');
  final dirCount = applied.deletedDirs.length;
  final fileCount = applied.deletedFiles.length;
  say('  ✓ 删除 $dirCount 个目录、$fileCount 个文件');
  for (final path in applied.deletedDirs) {
    say('    – $path/');
  }
  for (final path in applied.deletedFiles) {
    say('    – $path');
  }
  say('  ✓ 改写 ${applied.updatedFiles.length} 个文件');
  for (final path in applied.updatedFiles) {
    say('    ~ $path');
  }

  // ── 6. 收尾：先重跑 codegen，再扫残留、再跑门禁 ──
  if (options.skipVerify) {
    say('');
    say('（--no-verify：跳过 codegen 与门禁）');
  } else {
    say('');
    say('跑 just codegen（删掉 @RoutePage / @injectable / Drift 表后必须重生成）…');
    final codegen = await run(['just', 'codegen'], root.path);
    if (codegen.exitCode != 0) {
      say('❌ just codegen 失败（退出码 ${codegen.exitCode}）：');
      say(_tail('${codegen.stdout}\n${codegen.stderr}'));
      say('');
      say(_rollback);
      return _verifyFailed;
    }
    say('  ✓ just codegen 通过');
  }

  // ── 7. 残留扫描 ──
  // 跑过 codegen 才把生成物一起扫：没跑的话 router.gr.dart 里必然留着已删的路由类。
  final codeHits = scanCodeResidue(
    root,
    modules,
    includeGenerated: !options.skipVerify,
  );
  final docHits = scanDocResidue(root, modules);

  if (codeHits.isNotEmpty) {
    say('');
    say('❌ 代码里还有 ${codeHits.length} 处残留（说明锚点清单漏了位置）：');
    for (final hit in codeHits.take(40)) {
      say('  • $hit');
    }
    say('');
    say('  这些必须清干净，否则下一次 codegen 或 analyze 会失败。');
    say(_rollback);
    return _failed;
  }
  say('');
  say('  ✓ lib/ 与 test/ 里没有残留');

  if (docHits.isNotEmpty) {
    say('');
    say('提示：文档里还有 ${docHits.length} 处引用示例模块 —— **不是失败**，');
    say('但请人工决定改写还是删段（自动改会产出空话）：');
    for (final hit in docHits.take(40)) {
      say('  • $hit');
    }
  }

  // ── 8. 门禁 ──
  if (options.skipVerify) {
    say('');
    say('Next steps:');
    say('  1. dart run build_runner build');
    say('  2. just verify');
    say(_postPruneNotes);
    return _ok;
  }

  say('');
  say('跑 just verify（约 1-2 分钟）…');
  final verify = await run(['just', 'verify'], root.path);
  if (verify.exitCode != 0) {
    say('❌ just verify 失败（退出码 ${verify.exitCode}）：');
    say(_tail('${verify.stdout}\n${verify.stderr}'));
    say('');
    say(_rollback);
    return _verifyFailed;
  }

  say('');
  say('✅ 剪枝完成：${modules.map((m) => m.name).join('、')}');
  say(_postPruneNotes);
  return _ok;
}

Future<void> main(List<String> args) async {
  exit(await runCli(args, root: Directory.current));
}
