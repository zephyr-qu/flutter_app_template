import 'package:app_core/base/result.dart';
import 'package:app_core/models/user.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:my_app/features/auth/data/auth_repository.dart';
import 'package:my_app/features/profile/page/profile_page.dart';

import '../../../support/app_test_harness.dart';

class MockAuthRepository extends Mock implements AuthRepository;

void main() {
  late MockAuthRepository repo;
  late TestAppContext app;

  setUp(() async {
    app = await setUpTestApp();
    repo = MockAuthRepository();
    when(() => repo.logout())
        .thenAnswer((_) async => const Result.success(null));
    // 页面从 auth 的 data 层取仓库（跨 feature 只共享 data 层）
    GetIt.I.registerFactory<AuthRepository>(() => repo);
  });

  tearDown(tearDownTestApp);

  group('ProfilePage — 渲染', () {
    testWidgets('未登录时显示「未登录」', (tester) async {
      await tester.pumpWidget(wrapPage(const ProfilePage()));

      expect(find.text('未登录'), findsOneWidget);
      expect(find.text('欢迎使用'), findsNothing);
    });

    testWidgets('已登录时显示用户名与欢迎语', (tester) async {
      await app.storage.saveUser(const User(id: 1, name: '张三'));

      await tester.pumpWidget(wrapPage(const ProfilePage()));

      expect(find.text('张三'), findsOneWidget);
      expect(find.text('欢迎使用'), findsOneWidget);
      expect(find.text('未登录'), findsNothing);
    });
  });

  group('ProfilePage — 主题选择器', () {
    /// 取某一设置项 trailing 上显示的当前值。
    ///
    /// 「跟随系统」在语言项与外观项上都会出现，所以断言必须限定在具体那一项
    /// 内部，不能用裸的 `find.text`。
    Finder valueIn(String title, String value) => find.descendant(
      of: find.widgetWithText(ListTile, title),
      matching: find.text(value),
    );

    testWidgets('默认跟随系统', (tester) async {
      expect(app.preferences.themeMode.value, ThemeMode.system);

      await tester.pumpWidget(wrapPage(const ProfilePage()));

      expect(find.text('外观'), findsOneWidget);
      expect(valueIn('外观', '跟随系统'), findsOneWidget);
    });

    testWidgets('选择深色后写入偏好并立即回显', (tester) async {
      await tester.pumpWidget(wrapPage(const ProfilePage()));

      await tester.tap(find.text('外观'));
      await tester.pumpAndSettle();

      expect(find.text('选择主题'), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byType(SimpleDialog),
          matching: find.text('深色'),
        ),
      );
      await tester.pumpAndSettle();

      expect(app.preferences.themeMode.value, ThemeMode.dark);
      expect(app.prefs.getInt('app.theme.mode'), ThemeMode.dark.index);
      // 卡片上的当前值跟着更新（本页订阅了 themeMode 信号）
      expect(valueIn('外观', '深色'), findsOneWidget);
      expect(valueIn('外观', '跟随系统'), findsNothing);
    });

    testWidgets('点空白关闭对话框不会改动偏好', (tester) async {
      app.preferences.setThemeMode(ThemeMode.light);
      await tester.pumpWidget(wrapPage(const ProfilePage()));

      await tester.tap(find.text('外观'));
      await tester.pumpAndSettle();

      // 点对话框外部关闭
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(app.preferences.themeMode.value, ThemeMode.light);
    });
  });

  group('ProfilePage — 登出', () {
    testWidgets('点击退出登录会调用仓库', (tester) async {
      await app.storage.saveUser(const User(id: 1, name: '张三'));
      await tester.pumpWidget(wrapPage(const ProfilePage()));

      // 按钮在页面底部，默认测试视口里需要先滚到可见位置
      await tester.ensureVisible(find.text('退出登录'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('退出登录'));
      await tester.pumpAndSettle();

      verify(() => repo.logout()).called(1);
    });
  });
}
