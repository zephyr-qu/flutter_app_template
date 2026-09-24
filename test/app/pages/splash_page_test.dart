import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';
import 'package:my_app/app/pages/splash_page.dart';
import 'package:my_app/app/providers.dart';
import 'package:my_app/core/theme/app_theme.dart';
import 'package:my_app/features/home/page/home_page.dart';

import '../../support/app_test_harness.dart';

/// 启动页：入场动画本身，以及 2.2s 后进主框架这条跳转。
///
/// 冷启动确实落在这一页：`app/providers.dart` 的 `routerProvider` 把初始 location
/// 指到 `/splash`。（`AutoRoute(initial: true)` 对写了 `path` 的路由不生效 —— 见
/// auto_route 的 `RouteCollection.fromList`，所以只能从 provider 那一侧接。）
/// 本文件因此**不自己指定初始 location**：测的是产品真正走的装配。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // 本测试构建真实的 AppRouter：RouterDelegate 没有 dispose()，auto_route
    // 内部的 delegate 无法在测试里释放。只放宽「未释放」，notGCed 检测保持开启。
    LeakTesting.settings = LeakTesting.settings.withIgnored(
      createdByTestHelpers: true,
      allNotDisposed: true,
    );
  });

  /// 装配容器与真实路由，从启动页开始。
  Future<void> pumpSplash(WidgetTester tester) async {
    final container = (await setUpTestApp()).container;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: buildLightTheme(),
          routerConfig: container.read(routerProvider).config(),
        ),
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
    await pumpSplash(tester);

    expect(find.byType(SplashPage), findsOneWidget);
    expect(find.text('My App'), findsOneWidget);
    // tagline 是直接写死的中文字面量（本项目没有 l10n）
    expect(find.text('简洁 · 优雅 · 实用'), findsOneWidget);
    expect(find.byIcon(Icons.spa_outlined), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // 还没到 2.2s，应当停在启动页
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(HomePage), findsNothing);

    await drainRedirectTimer(tester);
  });

  testWidgets('入场动画从初始态推进到终态', (tester) async {
    await pumpSplash(tester);

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

  testWidgets('2.2s 后落到主框架（带底部导航）', (tester) async {
    await pumpSplash(tester);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.byType(HomePage), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(SplashPage), findsNothing);
  });

  testWidgets('2.2s 内被销毁时不再跳转', (tester) async {
    await pumpSplash(tester);
    expect(find.byType(SplashPage), findsOneWidget);

    // 计时器到期前把整棵树换掉：`if (!mounted) return` 必须拦住这次
    // replaceRoute——少了守卫就会在已 deactivate 的 context 上抛错。
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));

    expect(tester.takeException(), isNull);
  });
}
