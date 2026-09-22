import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:my_app/app/app.dart';
import 'package:my_app/features/auth/data/auth_repository.dart';
import 'package:my_app/features/auth/logic/auth_view_model.dart';
import 'package:my_app/features/auth/page/login_page.dart';

import '../support/app_test_harness.dart';

class MockAuthRepository extends Mock implements AuthRepository;

/// 根组件是**组合根**：DI 取值、路由创建、登录态监听、主题装配、主题模式订阅
/// 全在这几十行里。断言本身不多，价值在「装配错了就红」——少注册一个
/// `getIt`、路由指向已删的页面、主题信号没被订阅，都会在这里暴露。
///
/// 集成测试也跑这条链路，但 `flutter test --coverage` 不含 `integration_test/`，
/// 所以这里必须也有一条，否则 `lib/app/app.dart` 会一直是覆盖率盲区。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // MyApp 内部的 router delegate 由框架持有，测试无法释放
    // （同 test/routing/auth_redirect_test.dart）
    LeakTesting.settings = LeakTesting.settings.withIgnored(
      createdByTestHelpers: true,
      allNotDisposed: true,
    );
  });

  tearDown(tearDownTestApp);

  /// 用真实容器 + 真实路由启动根组件，返回装配上下文供断言使用
  Future<TestAppContext> pumpMyApp(WidgetTester tester) async {
    final context = await setUpTestApp();
    // 路由建 LoginPage 时走「可选注入点」的兜底分支：按类型从容器取 ViewModel
    GetIt.I.registerFactory<AuthViewModel>(
      () => AuthViewModel(MockAuthRepository()),
    );

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    return context;
  }

  testWidgets('未登录时根组件落在登录页（守卫按真实登录态重定向）', (tester) async {
    final context = await pumpMyApp(tester);

    expect(find.byType(LoginPage), findsOneWidget);
    expect(context.storage.isLoggedIn, isFalse);
  });

  testWidgets('themeMode 跟随 UserPreferences 的信号变化', (tester) async {
    final context = await pumpMyApp(tester);

    MaterialApp app() => tester.widget<MaterialApp>(find.byType(MaterialApp));

    expect(app().themeMode, ThemeMode.system);

    context.preferences.setThemeMode(ThemeMode.dark);
    await tester.pump();

    // 必须靠 useSignalValue 订阅：改读 getter 只会在恰好重建时更新
    expect(app().themeMode, ThemeMode.dark);
  });

  testWidgets('亮 / 暗主题都接在 MaterialApp 上', (tester) async {
    await pumpMyApp(tester);

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));

    expect(app.debugShowCheckedModeBanner, isFalse);
    expect(app.theme?.brightness, Brightness.light);
    expect(app.darkTheme?.brightness, Brightness.dark);
  });
}
