import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/config/app_settings.dart';
import 'package:my_app/features/profile/page/profile_page.dart';

import '../../../support/app_test_harness.dart';

void main() {
  late TestAppContext app;

  setUp(() async {
    app = await setUpTestApp();
  });

  group('ProfilePage — 渲染', () {
    testWidgets('头部卡是静态品牌信息（无用户与登录态）', (tester) async {
      await tester.pumpWidget(
        wrapPage(const ProfilePage(), container: app.container),
      );

      expect(find.text('My App'), findsOneWidget);
      expect(find.text('欢迎使用'), findsOneWidget);
      expect(find.byIcon(Icons.spa_outlined), findsOneWidget);
      // 认证功能已删除：这两样都不该再出现
      expect(find.text('未登录'), findsNothing);
      expect(find.text('退出登录'), findsNothing);
    });
  });

  group('ProfilePage — 主题选择器', () {
    /// 取某一设置项 trailing 上显示的当前值。
    ///
    /// 「跟随系统」在多个项上都会出现，所以断言必须限定在具体那一项内部，
    /// 不能用裸的 `find.text`。
    Finder valueIn(String title, String value) => find.descendant(
      of: find.widgetWithText(ListTile, title),
      matching: find.text(value),
    );

    testWidgets('默认跟随系统', (tester) async {
      expect(
        app.container.read(appSettingsProvider).themeMode,
        ThemeMode.system,
      );

      await tester.pumpWidget(
        wrapPage(const ProfilePage(), container: app.container),
      );

      expect(find.text('外观'), findsOneWidget);
      expect(valueIn('外观', '跟随系统'), findsOneWidget);
    });

    testWidgets('选择深色后写入偏好并立即回显', (tester) async {
      await tester.pumpWidget(
        wrapPage(const ProfilePage(), container: app.container),
      );

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

      expect(app.container.read(appSettingsProvider).themeMode, ThemeMode.dark);
      expect(app.prefs.getInt('app.theme.mode'), ThemeMode.dark.index);
      // 卡片上的当前值跟着更新（本页 watch 了 appSettingsProvider）
      expect(valueIn('外观', '深色'), findsOneWidget);
      expect(valueIn('外观', '跟随系统'), findsNothing);
    });

    testWidgets('点空白关闭对话框不会改动偏好', (tester) async {
      await app.container
          .read(appSettingsProvider.notifier)
          .setThemeMode(ThemeMode.light);
      await tester.pumpWidget(
        wrapPage(const ProfilePage(), container: app.container),
      );

      await tester.tap(find.text('外观'));
      await tester.pumpAndSettle();

      // 点对话框外部关闭
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(
        app.container.read(appSettingsProvider).themeMode,
        ThemeMode.light,
      );
    });
  });
}
