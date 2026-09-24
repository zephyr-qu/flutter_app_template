import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';
import 'package:my_app/app/app.dart';
import 'package:my_app/core/config/app_settings.dart';
import 'package:my_app/features/home/page/home_page.dart';

import '../support/app_test_harness.dart';

/// 根组件是**组合根**：路由创建、主题装配、主题模式订阅
/// 全在这几十行里。断言本身不多，价值在「装配错了就红」——少接一个 provider、
/// 路由指向已删的页面、主题模式没被 watch，都会在这里暴露。
///
/// 集成测试也跑这条链路，但 `integration_test/` 不在 `flutter test` 的范围内，
/// 所以这里必须也有一条，否则组合根要等模拟器上的冒烟测试才会被验证。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // MyApp 内部的 router delegate 由框架持有，测试无法释放
    // （同 test/routing/main_shell_test.dart）
    LeakTesting.settings = LeakTesting.settings.withIgnored(
      createdByTestHelpers: true,
      allNotDisposed: true,
    );
  });

  /// 用真实容器 + 真实路由启动根组件，返回装配上下文供断言使用
  Future<TestAppContext> pumpMyApp(WidgetTester tester) async {
    final app = await setUpTestApp();

    await tester.pumpWidget(
      UncontrolledProviderScope(container: app.container, child: const MyApp()),
    );
    await tester.pumpAndSettle();
    // 冷启动落在启动页：跳转在 2.2s 后执行（动画约 1.8s），之后才进主框架（同 routing/ 下的测试）
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    return app;
  }

  testWidgets('冷启动经启动页落到主框架（无登录守卫）', (tester) async {
    final app = await pumpMyApp(tester);

    expect(find.byType(HomePage), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(app.container.read(appSettingsProvider).themeMode, ThemeMode.system);
  });

  testWidgets('themeMode 跟随 AppSettingsNotifier 的状态变化', (tester) async {
    final app = await pumpMyApp(tester);

    MaterialApp materialApp() =>
        tester.widget<MaterialApp>(find.byType(MaterialApp));

    expect(materialApp().themeMode, ThemeMode.system);

    await app.container
        .read(appSettingsProvider.notifier)
        .setThemeMode(ThemeMode.dark);
    await tester.pump();

    // 必须靠 ref.watch 订阅：只读一次 getter 只会在恰好重建时更新
    expect(materialApp().themeMode, ThemeMode.dark);
  });

  testWidgets('亮 / 暗主题都接在 MaterialApp 上', (tester) async {
    await pumpMyApp(tester);

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));

    expect(app.debugShowCheckedModeBanner, isFalse);
    expect(app.theme?.brightness, Brightness.light);
    expect(app.darkTheme?.brightness, Brightness.dark);
  });
}
