import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:my_app/app/pages/splash_page.dart';
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
import 'package:my_app/features/auth/data/auth_repository.dart';
import 'package:my_app/features/auth/logic/auth_view_model.dart';
import 'package:my_app/features/auth/page/login_page.dart';
import 'package:my_app/features/home/page/home_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockAuthRepository extends Mock implements AuthRepository;

class MockArticleRepository extends Mock implements ArticleRepository;

/// 启动页：入场动画本身，以及 2.2s 后按登录态选择落点这条分支。
///
/// ⚠️ 现状提醒：splash **没有被接进启动链路**。根路由里 `/` 被 `MainRoute`
/// 占着，冷启动的初始 location 又是 `/`；而 `AutoRoute(initial: true)` 只对
/// **没写 `path`** 的路由生效（见 auto_route 的 `RouteCollection.fromList`），
/// 所以实际启动是 `/` → MainRoute →（未登录）守卫重定向到登录页，
/// SplashPage 根本不会被渲染。
///
/// 因此这里在装配时把初始 location 指到 `/splash`，用来守住页面自身的行为
/// （渲染 / 动画 / 分流 / mounted 守卫）。产品侧要真正显示启动页，也得走同一条路：
/// 让初始 location 落在 `/splash`（见 `pumpSplash` 的注释）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppRouter router;
  AuthReevaluateListenable? reevaluate;

  setUp(() {
    // 本测试构建真实的 AppRouter：RouterDelegate 没有 dispose()，auto_route
    // 内部的 delegate / 守卫观察者无法在测试里释放。只放宽「未释放」，
    // notGCed 检测保持开启。同 routing/ 下的两个测试。
    LeakTesting.settings = LeakTesting.settings.withIgnored(
      createdByTestHelpers: true,
      allNotDisposed: true,
    );
  });

  tearDown(() async {
    reevaluate?.dispose();
    await GetIt.I.reset();
  });

  /// 装配容器并以 [loggedIn] 的登录态启动 splash 页面。
  Future<void> pumpSplash(WidgetTester tester, {required bool loggedIn}) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final storage = AuthStorage(prefs, const FlutterSecureStorage());
    await storage.ready;
    if (loggedIn) {
      await storage.saveTokens(const TokenSet(accessToken: 'token'));
      await storage.saveUser(const User(id: 1, name: '张三'));
    }

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

    reevaluate = AuthReevaluateListenable(storage.isLoggedInSignal);
    // 把初始 location 指到 `/splash`。auto_route 的 provider 是 lazy 且只建
    // 一次（`??=`），所以必须在 config() 之前实例化它。
    router = AppRouter(storage)
      ..routeInfoProvider(
        initialRouteInformation: RouteInformation(uri: Uri.parse('/splash')),
      );

    await tester.pumpWidget(
      MaterialApp.router(
        theme: buildLightTheme(),
        routerConfig: router.config(reevaluateListenable: reevaluate),
      ),
    );
    // 只 pump 一帧：再推进时钟就跨过 2.2s，页面已经跳走了
    await tester.pump();
  }

  /// 把 2.2s 的跳转计时器跑完。
  ///
  /// 不测跳转的用例也要调用：留着一个 pending timer，测试结束时 binding 会
  /// 直接判失败（`A Timer is still pending even after the widget tree was disposed`）。
  Future<void> drainRedirectTimer(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  }

  /// 取 splash 自己那层入场动画。
  ///
  /// 限定在 SplashPage 内部还不够：`CircularProgressIndicator` 内部也用
  /// `ScaleTransition` / `FadeTransition`（尾部间隙与淡出）。取先序遍历的
  /// 第一个，也就是包在最外层的那一个。
  T animationOf<T extends Widget>(WidgetTester tester) => tester
      .widgetList<T>(
        find.descendant(of: find.byType(SplashPage), matching: find.byType(T)),
      )
      .first;

  double fadeOpacity(WidgetTester tester) =>
      animationOf<FadeTransition>(tester).opacity.value;

  double scaleValue(WidgetTester tester) =>
      animationOf<ScaleTransition>(tester).scale.value;

  Offset slideOffset(WidgetTester tester) =>
      animationOf<SlideTransition>(tester).position.value;

  testWidgets('渲染品牌区与加载指示器', (tester) async {
    await pumpSplash(tester, loggedIn: false);

    expect(find.byType(SplashPage), findsOneWidget);
    expect(find.text('My App'), findsOneWidget);
    // tagline 走 AppLocalizations，缺 delegate 的话这里会直接抛
    expect(find.text('简洁 · 优雅 · 实用'), findsOneWidget);
    expect(find.byIcon(Icons.spa_outlined), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // 还没到 2.2s，应当停在启动页
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(LoginPage), findsNothing);
    expect(find.byType(HomePage), findsNothing);

    await drainRedirectTimer(tester);
  });

  testWidgets('入场动画从初始态推进到终态', (tester) async {
    await pumpSplash(tester, loggedIn: false);

    // 第一帧：还没淡入、logo 略小、内容偏下
    expect(fadeOpacity(tester), moreOrLessEquals(0, epsilon: 0.01));
    expect(scaleValue(tester), moreOrLessEquals(0.85, epsilon: 0.01));
    expect(slideOffset(tester).dy, greaterThan(0));

    // 动画中途（1800ms 的一半）：三个动画都动起来了
    await tester.pump(const Duration(milliseconds: 900));
    expect(fadeOpacity(tester), greaterThan(0.5));
    expect(scaleValue(tester), greaterThan(0.85));
    expect(slideOffset(tester).dy, lessThan(24));

    // 动画结束：停在终态
    await tester.pump(const Duration(milliseconds: 900));
    expect(fadeOpacity(tester), moreOrLessEquals(1, epsilon: 0.01));
    expect(scaleValue(tester), moreOrLessEquals(1, epsilon: 0.01));
    expect(slideOffset(tester).dy, moreOrLessEquals(0, epsilon: 0.01));

    await drainRedirectTimer(tester);
  });

  testWidgets('未登录时 2.2s 后落到登录页', (tester) async {
    await pumpSplash(tester, loggedIn: false);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.byType(SplashPage), findsNothing);
  });

  testWidgets('已登录时 2.2s 后落到主框架（而不是裸的首页）', (tester) async {
    await pumpSplash(tester, loggedIn: true);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.byType(HomePage), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(LoginPage), findsNothing);
  });

  testWidgets('2.2s 内被销毁时不再跳转', (tester) async {
    await pumpSplash(tester, loggedIn: false);
    expect(find.byType(SplashPage), findsOneWidget);

    // 计时器到期前把整棵树换掉：`if (!mounted) return` 必须拦住这次
    // replaceRoute——少了守卫就会在已 deactivate 的 context 上抛错。
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));

    expect(tester.takeException(), isNull);
  });
}
