import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:my_app/app/routing/auth_reevaluate.dart';
import 'package:my_app/app/routing/router.dart';
import 'package:my_app/core/config/user_preferences.dart';
import 'package:my_app/core/data/storage/auth_storage.dart';
import 'package:my_app/core/models/token_set.dart';
import 'package:my_app/core/models/user.dart';
import 'package:my_app/core/theme/app_theme.dart';
import 'package:my_app/features/auth/data/auth_repository.dart';
import 'package:my_app/features/auth/logic/auth_view_model.dart';
import 'package:my_app/features/auth/page/login_page.dart';
import 'package:my_app/features/home/page/home_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockAuthRepository extends Mock implements AuthRepository;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // 本测试要构建真正的 AppRouter：MaterialApp 不拥有传给它的 RouterDelegate，
    // 而 RouterDelegate 也没有 dispose()，因此 auto_route 内部的
    // AutoRouterDelegate / ActiveGuardObserver / NavigationHistoryImpl 在测试里
    // 无法释放。这里只放宽「未释放」这一类，notGCed 检测保持开启。
    LeakTesting.settings = LeakTesting.settings.withIgnored(
      createdByTestHelpers: true,
      allNotDisposed: true,
    );
  });

  /// 覆盖「401 之后用户被送回登录页」这条链路：
  /// AuthStorage 清除凭证 → isLoggedIn 信号翻转 → reevaluateListenable 通知
  /// → auto_route 重新评估守卫 → AuthGuard 重定向到登录页。
  testWidgets('登录态失效后守卫把用户送回登录页', (tester) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final storage = AuthStorage(prefs, const FlutterSecureStorage());
    await storage.ready;
    // 以「已登录」状态启动
    await storage.saveTokens(
      const TokenSet(accessToken: 'token-123', refreshToken: 'refresh-123'),
    );
    await storage.saveUser(const User(id: 1, name: '测试用户'));

    await GetIt.I.reset();
    GetIt.I.registerSingleton<AuthStorage>(storage);
    GetIt.I.registerSingleton<UserPreferences>(UserPreferences(prefs));
    // LoginPage 通过 getIt 取 ViewModel
    GetIt.I.registerFactory<AuthViewModel>(
      () => AuthViewModel(MockAuthRepository()),
    );

    final router = AppRouter(storage);
    final reevaluate = AuthReevaluateListenable(storage.isLoggedInSignal);
    final routerConfig = router.config(reevaluateListenable: reevaluate);

    await tester.pumpWidget(
      MaterialApp.router(
        theme: buildLightTheme(),
        // 页面通过 AppLocalizations 取文案
        routerConfig: routerConfig,
      ),
    );
    await tester.pumpAndSettle();
    // 启动页有 2.2s 的品牌动画，需要显式推进时钟
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    // 已登录：进入主框架
    expect(find.byType(HomePage), findsOneWidget);
    expect(find.byType(LoginPage), findsNothing);

    // 模拟接口返回 401：拦截器清除本地凭证
    await storage.clearAuth();
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.byType(HomePage), findsNothing);

    // 先拆掉 widget 树，再释放测试自己创建的对象
    await tester.pumpWidget(const SizedBox.shrink());
    reevaluate.dispose();
    await GetIt.I.reset();
  });
}
