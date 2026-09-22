import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/config/user_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late UserPreferences preferences;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    preferences = UserPreferences(prefs);
  });

  group('UserPreferences — 默认值', () {
    test('没有持久化数据时使用默认值', () {
      expect(preferences.currentMode, ThemeMode.system);
      expect(preferences.enableDebugLogging.value, isTrue);
      expect(preferences.defaultPageSize.value, 20);
    });
  });

  group('UserPreferences — 加载已持久化的值', () {
    test('读取主题模式 / 调试日志 / 分页大小', () async {
      SharedPreferences.setMockInitialValues({
        'app.theme.mode': ThemeMode.dark.index,
        'app.debug.logging': false,
        'app.default.page.size': 50,
      });
      prefs = await SharedPreferences.getInstance();

      final loaded = UserPreferences(prefs);

      expect(loaded.currentMode, ThemeMode.dark);
      expect(loaded.enableDebugLogging.value, isFalse);
      expect(loaded.defaultPageSize.value, 50);
    });

    test('主题索引越界时回退到 system（防止本地脏数据崩溃）', () async {
      SharedPreferences.setMockInitialValues({
        'app.theme.mode': ThemeMode.values.length + 10,
      });
      prefs = await SharedPreferences.getInstance();

      final loaded = UserPreferences(prefs);

      expect(loaded.currentMode, ThemeMode.system);
    });

    test('主题索引为负数时同样回退到 system', () async {
      SharedPreferences.setMockInitialValues({'app.theme.mode': -1});
      prefs = await SharedPreferences.getInstance();

      final loaded = UserPreferences(prefs);

      expect(loaded.currentMode, ThemeMode.system);
    });
  });

  group('UserPreferences — 写入', () {
    test('setThemeMode 同时更新信号与持久化', () {
      preferences.setThemeMode(ThemeMode.light);

      expect(preferences.themeMode.value, ThemeMode.light);
      expect(prefs.getInt('app.theme.mode'), ThemeMode.light.index);
    });

    test('setDebugLogging 同时更新信号与持久化', () {
      preferences.setDebugLogging(enabled: false);

      expect(preferences.enableDebugLogging.value, isFalse);
      expect(prefs.getBool('app.debug.logging'), isFalse);
    });

    test('setDefaultPageSize 同时更新信号与持久化', () {
      preferences.setDefaultPageSize(100);

      expect(preferences.defaultPageSize.value, 100);
      expect(prefs.getInt('app.default.page.size'), 100);
    });
  });
}
