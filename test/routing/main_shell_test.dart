import 'dart:async';

import 'package:app_core/base/result.dart';
import 'package:app_core/models/token_set.dart';
import 'package:app_core/models/user.dart';
import 'package:app_core/theme/app_theme.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:my_app/app/providers.dart';
import 'package:my_app/app/routing/router.dart';
import 'package:my_app/features/auth/data/auth_providers.dart';
import 'package:my_app/features/auth/data/auth_repository.dart';
import 'package:my_app/features/home/page/home_page.dart';
import 'package:my_app/features/profile/page/profile_page.dart';
import 'package:my_app/features/sample/data/models/sample_item.dart';
import 'package:my_app/features/sample/data/sample_providers.dart';
import 'package:my_app/features/sample/data/sample_repository.dart';
import 'package:my_app/features/sample/page/sample_list_page.dart';

import '../support/app_test_harness.dart';

class MockAuthRepository extends Mock implements AuthRepository;

class MockSampleRepository extends Mock implements SampleRepository;

/// 主框架（底部导航 / 侧边导航）与路由栈的联动。
///
/// 这里挂的是**真实的 AppRouter**：标签高亮必须由路由栈推导，
/// 只有把真实路由接起来才验得到。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestAppContext app;

  setUp(() {
    // 真实 MyApp/AppRouter 内部的 delegate 由此处无法释放，见 auth_redirect_test
    LeakTesting.settings = LeakTesting.settings.withIgnored(
      createdByTestHelpers: true,
      allNotDisposed: true,
    );
  });

  /// 以「已登录」状态启动，落到主框架
  Future<void> pumpShell(WidgetTester tester) async {
    final sampleRepo = MockSampleRepository();
    when(sampleRepo.getItems)
        .thenAnswer((_) async => const Result.success(<SampleItem>[]));

    app = await setUpTestApp(
      overrides: [
        authRepositoryProvider.overrideWithValue(MockAuthRepository()),
        sampleRepositoryProvider.overrideWithValue(sampleRepo),
      ],
    );

    await app.storage.saveTokens(
      const TokenSet(accessToken: 'token', refreshToken: 'refresh'),
    );
    await app.storage.saveUser(const User(id: 1, name: '张三'));

    final container = app.container;
    final routerConfig = container
        .read(routerProvider)
        .config(reevaluateListenable: container.read(authReevaluateProvider));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: buildLightTheme(),
          routerConfig: routerConfig,
        ),
      ),
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

    await tester.tap(tabLabel('示例'));
    await tester.pumpAndSettle();
    expect(find.byType(SampleListPage), findsOneWidget);
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
    // 示例页此刻还没被加载过（lazyLoad）
    expect(find.byType(SampleListPage), findsNothing);

    // 模拟「由别处发起」的标签切换：首页的快捷入口、深链、返回栈都会走这条路。
    // 旧实现把索引存在 State 里，此时高亮会错位停在首页。
    final context = tester.element(find.byType(HomePage));
    unawaited(AutoTabsRouter.of(context).navigate(const SampleListRoute()));
    await tester.pumpAndSettle();

    expect(find.byType(SampleListPage), findsOneWidget);
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
    unawaited(AutoTabsRouter.of(context).navigate(const SampleListRoute()));
    await tester.pumpAndSettle();

    expect(
      tester.widget<NavigationRail>(find.byType(NavigationRail)).selectedIndex,
      1,
    );
  });
}
