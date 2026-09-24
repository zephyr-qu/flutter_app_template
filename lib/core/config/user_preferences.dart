import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 用户偏好的**持久化**（每个偏好一个键）。
///
/// 不含状态管理依赖：同步读取（`SharedPreferences` 已由 `bootstrap()` 预载），
/// 变更通知与内存快照由 `core/config/app_settings.dart` 的 `AppSettingsNotifier`
/// 负责 —— 存储层可脱开 Riverpod 单测，页面要的是可订阅快照而不是每次读盘。
/// 读取时对越界值做回落（改过默认值 / 手工改过 prefs 时不该崩）。
class UserPreferences {
  new(this._prefs);
  final SharedPreferences _prefs;

  static const String _keyThemeMode = 'app.theme.mode';
  static const String _keyDebugLogging = 'app.debug.logging';
  static const String _keyDefaultPageSize = 'app.default.page.size';

  /// 主题模式；存的 index 越界时回落到 [ThemeMode.system]
  ThemeMode get themeMode {
    final index = _prefs.getInt(_keyThemeMode) ?? ThemeMode.system.index;
    if (index < 0 || index >= ThemeMode.values.length) return ThemeMode.system;
    return ThemeMode.values[index];
  }

  /// 是否输出调试日志（只影响**下一次创建 Dio** 时的拦截器装配，见 network/dio_client.dart）
  bool get enableDebugLogging => _prefs.getBool(_keyDebugLogging) ?? true;

  /// 列表分页大小
  int get defaultPageSize => _prefs.getInt(_keyDefaultPageSize) ?? 20;

  Future<void> setThemeMode(ThemeMode mode) =>
      _prefs.setInt(_keyThemeMode, mode.index);

  Future<void> setDebugLogging({required bool enabled}) =>
      _prefs.setBool(_keyDebugLogging, enabled);

  Future<void> setDefaultPageSize(int size) =>
      _prefs.setInt(_keyDefaultPageSize, size);
}
