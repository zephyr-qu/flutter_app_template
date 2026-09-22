import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/models/user.dart';
import 'package:my_app/features/home/page/home_page.dart';

import '../../../support/app_test_harness.dart';

void main() {
  late TestAppContext app;

  setUp(() async {
    app = await setUpTestApp();
  });

  tearDown(tearDownTestApp);

  group('HomePage — 问候语', () {
    testWidgets('已登录时显示当前用户的名字', (tester) async {
      await app.storage.saveUser(const User(id: 1, name: '张三'));

      await tester.pumpWidget(wrapPage(const HomePage()));

      expect(find.text('你好, 张三'), findsOneWidget);
    });

    testWidgets('未登录时用兜底称呼', (tester) async {
      await tester.pumpWidget(wrapPage(const HomePage()));

      expect(find.text('你好, 用户'), findsOneWidget);
    });

    testWidgets('英文下问候语与兜底称呼都变英文', (tester) async {
      await tester.pumpWidget(
        wrapPage(const HomePage(), locale: const Locale('en')),
      );

      expect(find.text('Hello, there'), findsOneWidget);
    });

    testWidgets('用户变化时问候语与头像首字跟着变（订阅信号，而不是只读一次）', (tester) async {
      await app.storage.saveUser(const User(id: 1, name: '张三'));
      await tester.pumpWidget(wrapPage(const HomePage()));
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
      await tester.pumpWidget(wrapPage(const HomePage()));

      await app.storage.clearAuth();
      await tester.pumpAndSettle();

      expect(find.text('你好, 用户'), findsOneWidget);
      expect(find.text('?'), findsOneWidget);
    });
  });

  group('HomePage — 结构', () {
    testWidgets('渲染快捷功能、最近动态与导航标题', (tester) async {
      await tester.pumpWidget(wrapPage(const HomePage()));

      expect(find.text('首页'), findsOneWidget);
      expect(find.text('快捷功能'), findsOneWidget);
      expect(find.text('最近动态'), findsOneWidget);
      expect(find.text('暂无最近动态'), findsOneWidget);
      // 快捷入口
      expect(find.text('文章'), findsOneWidget);
      expect(find.text('个人'), findsOneWidget);
      expect(find.text('设置'), findsOneWidget);
    });

    testWidgets('英文下这些区块也变英文', (tester) async {
      await tester.pumpWidget(
        wrapPage(const HomePage(), locale: const Locale('en')),
      );

      expect(find.text('Quick actions'), findsOneWidget);
      expect(find.text('Recent activity'), findsOneWidget);
      expect(find.text('No recent activity'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });
  });
}
