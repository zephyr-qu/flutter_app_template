import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:my_app/core/config/user_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockPrefs extends Mock implements SharedPreferences;

/// 这一层只负责**落盘与读回**：变更通知与内存快照在
/// `core/config/app_settings.dart`（provider 侧），所以这里全是同步断言。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue('');
    registerFallbackValue(0);
  });

  late SharedPreferences prefs;

  Future<UserPreferences> create([
    Map<String, Object> values = const {},
  ]) async {
    SharedPreferences.setMockInitialValues(values);
    prefs = await SharedPreferences.getInstance();
    return UserPreferences(prefs);
  }

  group('UserPreferences — 默认值', () {
    test('没有持久化数据时使用默认值', () async {
      final preferences = await create();

      expect(preferences.themeMode, ThemeMode.system);
      expect(preferences.enableDebugLogging, isTrue);
      expect(preferences.defaultPageSize, 20);
    });
  });

  group('UserPreferences — 加载已持久化的值', () {
    test('读取主题模式 / 调试日志 / 分页大小', () async {
      final loaded = await create({
        'app.theme.mode': ThemeMode.dark.index,
        'app.debug.logging': false,
        'app.default.page.size': 50,
      });

      expect(loaded.themeMode, ThemeMode.dark);
      expect(loaded.enableDebugLogging, isFalse);
      expect(loaded.defaultPageSize, 50);
    });

    test('主题索引越界时回退到 system（防止本地脏数据崩溃）', () async {
      final loaded = await create({
        'app.theme.mode': ThemeMode.values.length + 10,
      });

      expect(loaded.themeMode, ThemeMode.system);
    });

    test('主题索引为负数时同样回退到 system', () async {
      final loaded = await create({'app.theme.mode': -1});

      expect(loaded.themeMode, ThemeMode.system);
    });
  });

  group('UserPreferences — 写入', () {
    test('setThemeMode 落盘（本类不再持有内存状态）', () async {
      final preferences = await create();

      await preferences.setThemeMode(ThemeMode.light);

      expect(prefs.getInt('app.theme.mode'), ThemeMode.light.index);
    });

    test('setDebugLogging 落盘', () async {
      final preferences = await create();

      await preferences.setDebugLogging(enabled: false);

      expect(prefs.getBool('app.debug.logging'), isFalse);
    });

    test('setDefaultPageSize 落盘', () async {
      final preferences = await create();

      await preferences.setDefaultPageSize(100);

      expect(prefs.getInt('app.default.page.size'), 100);
    });

    test('新实例能读回刚写入的值', () async {
      final preferences = await create();
      await preferences.setDefaultPageSize(100);

      expect(UserPreferences(prefs).defaultPageSize, 100);
    });

    test('setX 返回 false 时抛 PreferenceWriteException', () async {
      final mock = _MockPrefs();
      when(() => mock.setInt(any(), any())).thenAnswer((_) async => false);
      final preferences = UserPreferences(mock);

      await expectLater(
        preferences.setThemeMode(ThemeMode.light),
        throwsA(isA<PreferenceWriteException>()),
      );
    });
  });
}
