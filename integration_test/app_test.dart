import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:my_app/main.dart' as app;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // 注意：bootstrap()（含 DI 注册与 leak_tracker 启动）不是可重入的，
  // 因此整个冒烟流程只在同一个 testWidgets 中启动一次应用。
  // 拆成多个 testWidgets 各自调用 app.main() 会在第二次启动时抛
  // 「Bad state: Leak tracking is already enabled.」。
  testWidgets('启动 → 登录 → 进入主框架', (tester) async {
    // 清掉上一次运行残留的登录态，保证每次都从登录页开始
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    // 固定语言：应用默认跟随系统语言，不锁定的话在英文设备上断言会失败
    // （顺带验证 app.locale 的持久化读取路径）
    await prefs.setString('app.locale', 'zh');

    app.main();
    await tester.pumpAndSettle();

    // 1. 启动后应落在登录页（splash → login）
    expect(find.text('邮箱'), findsOneWidget);
    expect(find.text('密码'), findsOneWidget);
    expect(find.text('登录'), findsWidgets);

    // 2. 未填写时登录按钮禁用
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );

    // 3. 填写合法凭证后按钮启用
    await tester.enterText(find.byType(TextField).first, 'user@example.com');
    await tester.pump();
    await tester.enterText(find.byType(TextField).last, 'password123');
    await tester.pump();

    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );

    // 4. 登录（走 mock）后必须进入 MainRoute 主框架，而不是裸的 HomePage：
    //    底部导航栏必须在，否则就是「丢外壳」的回归
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('首页'), findsWidgets);
    expect(find.text('你好, 开发者'), findsOneWidget);
  });
}
