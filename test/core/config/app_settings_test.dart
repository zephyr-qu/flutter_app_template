import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/config/app_settings.dart';
import 'package:my_app/core/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 偏好的**可订阅快照**：初值读一次存储，之后写入是「先改内存再落盘」。
/// 纯存储层（读回与越界回落）在 user_preferences_test.dart。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late ProviderContainer container;

  Future<void> setUpContainer([Map<String, Object> values = const {}]) async {
    SharedPreferences.setMockInitialValues(values);
    prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [prefsProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    container.listen(appSettingsProvider, (_, _) {});
  }

  group('AppSettingsNotifier — 初值', () {
    test('没有持久化数据时用默认值', () async {
      await setUpContainer();

      final settings = container.read(appSettingsProvider);
      expect(settings.themeMode, ThemeMode.system);
      expect(settings.enableDebugLogging, isTrue);
      expect(settings.defaultPageSize, 20);
    });

    test('有持久化数据时读回', () async {
      await setUpContainer({
        'app.theme.mode': ThemeMode.dark.index,
        'app.debug.logging': false,
        'app.default.page.size': 50,
      });

      final settings = container.read(appSettingsProvider);
      expect(settings.themeMode, ThemeMode.dark);
      expect(settings.enableDebugLogging, isFalse);
      expect(settings.defaultPageSize, 50);
    });
  });

  group('AppSettingsNotifier — 写入', () {
    test('setThemeMode：先改内存再落盘', () async {
      await setUpContainer();

      await container
          .read(appSettingsProvider.notifier)
          .setThemeMode(ThemeMode.light);

      expect(container.read(appSettingsProvider).themeMode, ThemeMode.light);
      expect(prefs.getInt('app.theme.mode'), ThemeMode.light.index);
    });

    test('setDebugLogging / setDefaultPageSize 同样落盘', () async {
      await setUpContainer();
      final notifier = container.read(appSettingsProvider.notifier);

      await notifier.setDebugLogging(enabled: false);
      await notifier.setDefaultPageSize(100);

      final settings = container.read(appSettingsProvider);
      expect(settings.enableDebugLogging, isFalse);
      expect(settings.defaultPageSize, 100);
      expect(prefs.getBool('app.debug.logging'), isFalse);
      expect(prefs.getInt('app.default.page.size'), 100);
    });

    test('三项偏好互不影响（同一个快照，copyWith 只改一列）', () async {
      await setUpContainer();
      final notifier = container.read(appSettingsProvider.notifier);

      await notifier.setDefaultPageSize(100);

      final settings = container.read(appSettingsProvider);
      expect(settings.themeMode, ThemeMode.system);
      expect(settings.enableDebugLogging, isTrue);
    });

    test('设为相同值时提前返回：不产生新状态', () async {
      await setUpContainer({'app.theme.mode': ThemeMode.dark.index});

      final seen = <AppSettings>[];
      container.listen(appSettingsProvider, (_, next) => seen.add(next));

      await container
          .read(appSettingsProvider.notifier)
          .setThemeMode(ThemeMode.dark);

      expect(seen, isEmpty);
    });
  });

  group('AppSettings.copyWith', () {
    test('只覆盖指定字段', () {
      const settings = AppSettings(
        themeMode: ThemeMode.system,
        enableDebugLogging: true,
        defaultPageSize: 20,
      );

      final changed = settings.copyWith(defaultPageSize: 50);

      expect(changed.defaultPageSize, 50);
      expect(changed.themeMode, ThemeMode.system);
      expect(changed.enableDebugLogging, isTrue);
    });
  });
}
