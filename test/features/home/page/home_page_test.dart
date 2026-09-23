import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/models/user.dart';
import 'package:my_app/features/home/page/home_page.dart';

import '../../../support/app_test_harness.dart';

void main() {
  late TestAppContext app;

  setUp(() async {
    app = await setUpTestApp();
  });

  group('HomePage — 问候语', () {
    testWidgets('已登录时显示当前用户的名字', (tester) async {
      await app.storage.saveUser(const User(id: 1, name: '张三'));

      await tester.pumpWidget(
        wrapPage(const HomePage(), container: app.container),
      );

      expect(find.text('你好, 张三'), findsOneWidget);
    });

    testWidgets('未登录时用兜底称呼', (tester) async {
      await tester.pumpWidget(
        wrapPage(const HomePage(), container: app.container),
      );

      expect(find.text('你好, 用户'), findsOneWidget);
    });

    testWidgets('用户变化时问候语与头像首字跟着变（订阅 provider，而不是只读一次）', (tester) async {
      await app.storage.saveUser(const User(id: 1, name: '张三'));
      await tester.pumpWidget(
        wrapPage(const HomePage(), container: app.container),
      );
      expect(find.text('你好, 张三'), findsOneWidget);
      expect(find.text('张'), findsOneWidget);

      // 等价于别处更新了用户；本页被主框架常驻，不会自己重建
      await app.storage.saveUser(const User(id: 1, name: '李四'));
      await tester.pumpAndSettle();

      expect(find.text('你好, 李四'), findsOneWidget);
      expect(find.text('李'), findsOneWidget);
      expect(find.text('你好, 张三'), findsNothing);
    });

    testWidgets('登出后回落到兜底称呼', (tester) async {
      await app.storage.saveUser(const User(id: 1, name: '张三'));
      await tester.pumpWidget(
        wrapPage(const HomePage(), container: app.container),
      );

      await app.storage.clearAuth();
      await tester.pumpAndSettle();

      expect(find.text('你好, 用户'), findsOneWidget);
      expect(find.text('?'), findsOneWidget);
    });
  });

  group('HomePage — 结构', () {
    testWidgets('渲染快捷功能、最近动态与导航标题', (tester) async {
      await tester.pumpWidget(
        wrapPage(const HomePage(), container: app.container),
      );

      expect(find.text('首页'), findsOneWidget);
      expect(find.text('快捷功能'), findsOneWidget);
      expect(find.text('最近动态'), findsOneWidget);
      expect(find.text('暂无最近动态'), findsOneWidget);
      // 快捷入口（中间那个指向 features/sample）
      expect(find.text('示例'), findsOneWidget);
      expect(find.text('个人'), findsOneWidget);
      expect(find.text('设置'), findsOneWidget);
    });
  });
}
