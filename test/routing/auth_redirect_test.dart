import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:my_app/app/providers.dart';
import 'package:my_app/core/models/token_set.dart';
import 'package:my_app/core/models/user.dart';
import 'package:my_app/core/theme/app_theme.dart';
import 'package:my_app/features/auth/data/auth_providers.dart';
import 'package:my_app/features/auth/data/auth_repository.dart';
import 'package:my_app/features/auth/page/login_page.dart';
import 'package:my_app/features/home/page/home_page.dart';

import '../support/app_test_harness.dart';

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
  /// `AuthStorage.clearAuth` → `userChanges` 广播 → `AuthReevaluateListenable`
  /// 通知 → auto_route 重新评估守卫 → 重定向到登录页。
  testWidgets('登录态失效后守卫把用户送回登录页', (tester) async {
    final app = await setUpTestApp(
      overrides: [
        authRepositoryProvider.overrideWithValue(MockAuthRepository()),
      ],
    );

    // 以「已登录」状态启动
    await app.storage.saveTokens(
      const TokenSet(accessToken: 'token-123', refreshToken: 'refresh-123'),
    );
    await app.storage.saveUser(const User(id: 1, name: '测试用户'));

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
    // 启动页有 2.2s 的品牌动画，需要显式推进时钟
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    // 已登录：进入主框架
    expect(find.byType(HomePage), findsOneWidget);
    expect(find.byType(LoginPage), findsNothing);

    // 模拟接口返回 401：拦截器清除本地凭证
    await app.storage.clearAuth();
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.byType(HomePage), findsNothing);

    // 先拆掉 widget 树，容器的 dispose 才不会撞上还在监听的 widget
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
