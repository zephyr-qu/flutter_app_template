import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:my_app/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // 注意：bootstrap()（含 prefsProvider 的注入与 leak_tracker 启动）不是可重入的，
  // 因此整个冒烟流程只在同一个 testWidgets 中启动一次应用。
  // 拆成多个 testWidgets 各自调用 app.main() 会在第二次启动时抛
  // 「Bad state: Leak tracking is already enabled.」。
  testWidgets('启动 → 进入主框架 → 切标签', (tester) async {
    // await：bootstrap() 要先加载 .env 与 SharedPreferences 才 runApp，
    // 不等它会让后面的断言跑在启动完成之前
    await app.main();
    await tester.pumpAndSettle();
    // 冷启动先过启动页：显式推进 2.2s 品牌动画的计时器，别只靠上一步的 settle 兜
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    // 1. 启动后经启动页落到主框架（本分支没有登录页）
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('首页'), findsWidgets);
    expect(find.text('你好, 欢迎回来'), findsOneWidget);

    // 2. 底部导航能切标签，且高亮跟随路由栈
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('示例'),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );
  });
}
