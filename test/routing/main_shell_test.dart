import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:my_app/app/routing/auth_reevaluate.dart';
import 'package:my_app/app/routing/router.dart';
import 'package:my_app/core/base/result.dart';
import 'package:my_app/core/config/user_preferences.dart';
import 'package:my_app/core/data/storage/auth_storage.dart';
import 'package:my_app/core/models/token_set.dart';
import 'package:my_app/core/models/user.dart';
import 'package:my_app/core/theme/app_theme.dart';
import 'package:my_app/features/article/data/article_repository.dart';
import 'package:my_app/features/article/data/models/article.dart';
import 'package:my_app/features/article/logic/article_view_model.dart';
import 'package:my_app/features/article/page/article_list_page.dart';
import 'package:my_app/features/auth/data/auth_repository.dart';
import 'package:my_app/features/auth/logic/auth_view_model.dart';
import 'package:my_app/features/home/page/home_page.dart';
import 'package:my_app/features/profile/page/profile_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockAuthRepository extends Mock implements AuthRepository;

class MockArticleRepository extends Mock implements ArticleRepository;

/// 主框架（底部导航 / 侧边导航）与路由栈的联动。
///
/// 这里挂的是**真实的 AppRouter**：标签高亮必须由路由栈推导，
/// 只有把真实路由接起来才验得到。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AuthStorage storage;
  late AppRouter router;
  late AuthReevaluateListenable reevaluate;
  late RouterConfig<UrlState> routerConfig;

  setUp(() {
    // 真实 MyApp/AppRouter 内部的 delegate 由此处无法释放，见 auth_redirect_test
    LeakTesting.settings = LeakTesting.settings.withIgnored(
      createdByTestHelpers: true,
      allNotDisposed: true,
    );
  });

  tearDown(() async {
    reevaluate.dispose();
    await GetIt.I.reset();
  });

  /// 以「已登录」状态启动，落到主框架
  Future<void> pumpShell(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    storage = AuthStorage(prefs, const FlutterSecureStorage());
    await storage.ready;
    await storage.saveTokens(
      const TokenSet(accessToken: 'token', refreshToken: 'refresh'),
    );
    await storage.saveUser(const User(id: 1, name: '张三'));

    final authRepo = MockAuthRepository();
    when(authRepo.logout).thenAnswer((_) async => const Result.success(null));
    final articleRepo = MockArticleRepository();
    when(articleRepo.getArticles)
        .thenAnswer((_) async => const Result.success(<Article>[]));

    await GetIt.I.reset();
    GetIt.I.registerSingleton<AuthStorage>(storage);
    GetIt.I.registerSingleton<UserPreferences>(UserPreferences(prefs));
    GetIt.I.registerFactory<AuthViewModel>(() => AuthViewModel(authRepo));
    GetIt.I.registerFactory<ArticleViewModel>(
      () => ArticleViewModel(articleRepo),
    );

    router = AppRouter(storage);
    reevaluate = AuthReevaluateListenable(storage.isLoggedInSignal);
    routerConfig = router.config(reevaluateListenable: reevaluate);

    await tester.pumpWidget(
      MaterialApp.router(theme: buildLightTheme(), routerConfig: routerConfig),
    );
    await tester.pumpAndSettle();
    // 启动页 2.2s 品牌动画
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  }

  /// 底部导航里某个标签的文字（避开页面里同名的文案）
  Finder tabLabel(String label) => find.descendant(
    of: find.byType(NavigationBar),
    matching: find.text(label),
  );

  int selectedTabIndex(WidgetTester tester) =>
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex;

  testWidgets('已登录时进入主框架并停在首页标签', (tester) async {
    await pumpShell(tester);

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(HomePage), findsOneWidget);
    expect(selectedTabIndex(tester), 0);
  });

  testWidgets('点击底部导航切换标签并更新高亮', (tester) async {
    await pumpShell(tester);

    await tester.tap(tabLabel('文章'));
    await tester.pumpAndSettle();
    expect(find.byType(ArticleListPage), findsOneWidget);
    expect(selectedTabIndex(tester), 1);

    await tester.tap(tabLabel('我的'));
    await tester.pumpAndSettle();
    expect(find.byType(ProfilePage), findsOneWidget);
    expect(selectedTabIndex(tester), 2);

    await tester.tap(tabLabel('首页'));
    await tester.pumpAndSettle();
    expect(selectedTabIndex(tester), 0);
  });

  testWidgets('标签被别处切换时高亮跟随——而不是停在本地索引', (tester) async {
    await pumpShell(tester);
    expect(selectedTabIndex(tester), 0);
    // 文章页此刻还没被加载过（lazyLoad）
    expect(find.byType(ArticleListPage), findsNothing);

    // 模拟「由别处发起」的标签切换：首页的快捷入口、深链、返回栈都会走这条路。
    // 旧实现把索引存在 State 里，此时高亮会错位停在首页。
    final context = tester.element(find.byType(HomePage));
    unawaited(AutoTabsRouter.of(context).navigate(ArticleListRoute()));
    await tester.pumpAndSettle();

    expect(find.byType(ArticleListPage), findsOneWidget);
    expect(selectedTabIndex(tester), 1);
  });

  testWidgets('宽屏走侧边导航栏，高亮同样跟随路由栈', (tester) async {
    // 默认测试视口是 800x600，`> 800` 不成立 —— 这里显式放大以覆盖 rail 分支
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpShell(tester);

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    final context = tester.element(find.byType(HomePage));
    unawaited(AutoTabsRouter.of(context).navigate(ArticleListRoute()));
    await tester.pumpAndSettle();

    expect(
      tester.widget<NavigationRail>(find.byType(NavigationRail)).selectedIndex,
      1,
    );
  });
}
