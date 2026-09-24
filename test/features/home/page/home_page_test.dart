import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/home/page/home_page.dart';

import '../../../support/app_test_harness.dart';

void main() {
  late TestAppContext app;

  setUp(() async {
    app = await setUpTestApp();
  });

  group('HomePage — 欢迎卡片', () {
    testWidgets('问候语与头像位是静态内容（本分支没有用户）', (tester) async {
      await tester.pumpWidget(
        wrapPage(const HomePage(), container: app.container),
      );

      expect(find.text('你好, 欢迎回来'), findsOneWidget);
      expect(find.text('今天也是美好的一天'), findsOneWidget);
      expect(find.byIcon(Icons.spa_outlined), findsOneWidget);
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
