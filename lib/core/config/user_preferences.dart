import 'dart:async';

import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';
import 'package:my_app/core/logging/logging.dart';
import 'package:my_app/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals_flutter/signals_flutter.dart';

/// 用户偏好：每个偏好一个信号，写入时同步落盘（[SharedPreferences] 已由 DI 预初始化）。
@Singleton()
class UserPreferences {
  new(this._prefs) {
    _loadFromStorage();
  }
  final SharedPreferences _prefs;

  final FlutterSignal<ThemeMode> themeMode = signal<ThemeMode>(
    ThemeMode.system,
  );
  final FlutterSignal<bool> enableDebugLogging = signal<bool>(true);
  final FlutterSignal<int> defaultPageSize = signal<int>(20);

  /// 应用语言；`null` 表示跟随系统
  final FlutterSignal<Locale?> locale = signal<Locale?>(null);

  ThemeMode get currentMode => themeMode.value;

  static const String _keyThemeMode = 'app.theme.mode';
  static const String _keyDebugLogging = 'app.debug.logging';
  static const String _keyDefaultPageSize = 'app.default.page.size';
  static const String _keyLocale = 'app.locale';

  void _loadFromStorage() {
    final themeIndex = _prefs.getInt(_keyThemeMode) ?? ThemeMode.system.index;
    final resolvedIndex =
        themeIndex >= 0 && themeIndex < ThemeMode.values.length
        ? themeIndex
        : ThemeMode.system.index;
    themeMode.value = ThemeMode.values[resolvedIndex];

    enableDebugLogging.value = _prefs.getBool(_keyDebugLogging) ?? true;
    defaultPageSize.value = _prefs.getInt(_keyDefaultPageSize) ?? 20;
    _loadLocale();
  }

  /// 只接受 `supportedLocales` 内的值，脏数据回退到跟随系统
  void _loadLocale() {
    final code = _prefs.getString(_keyLocale);
    if (code == null) return;

    final matches = AppLocalizations.supportedLocales.where(
      (l) => l.languageCode == code,
    );
    if (matches.isNotEmpty) {
      locale.value = matches.first;
    } else {
      Logging.warning('本地保存的语言「$code」不在支持范围内，已回退到跟随系统');
    }
  }

  void setThemeMode(ThemeMode mode) {
    themeMode.value = mode;
    // 信号是同步的、落盘不是：写入结果这里用不到，但必须显式 unawaited
    unawaited(_prefs.setInt(_keyThemeMode, mode.index));
  }

  void setDebugLogging({required bool enabled}) {
    enableDebugLogging.value = enabled;
    unawaited(_prefs.setBool(_keyDebugLogging, enabled));
  }

  void setDefaultPageSize(int size) {
    defaultPageSize.value = size;
    unawaited(_prefs.setInt(_keyDefaultPageSize, size));
  }

  /// 传 `null` 表示跟随系统
  void setLocale(Locale? value) {
    locale.value = value;
    if (value == null) {
      unawaited(_prefs.remove(_keyLocale));
    } else {
      unawaited(_prefs.setString(_keyLocale, value.languageCode));
    }
  }
}
