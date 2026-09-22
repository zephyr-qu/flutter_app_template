import 'package:flutter/material.dart';
import 'package:my_app/core/providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_settings.g.dart';

/// 用户偏好的**不可变快照**：页面 `ref.watch(appSettingsProvider)` 拿到的就是它。
///
/// 为什么是「一个快照 + 一个 Notifier」而不是「三个独立的 Notifier」：
/// 三项偏好同源于一份存储、同生命周期、页面通常一起读（设置页），
/// 拆成三个只会让页面写三次 `ref.watch`。
@immutable
class AppSettings {
  const new({
    required this.themeMode,
    required this.enableDebugLogging,
    required this.defaultPageSize,
  });

  final ThemeMode themeMode;
  final bool enableDebugLogging;
  final int defaultPageSize;

  AppSettings copyWith({
    ThemeMode? themeMode,
    bool? enableDebugLogging,
    int? defaultPageSize,
  }) => AppSettings(
    themeMode: themeMode ?? this.themeMode,
    enableDebugLogging: enableDebugLogging ?? this.enableDebugLogging,
    defaultPageSize: defaultPageSize ?? this.defaultPageSize,
  );
}

/// 偏好的可订阅状态：初值读一次存储，之后由本类负责通知与落盘。
///
/// **写入顺序是「先改内存再落盘」**：UI 立刻响应，落盘失败只记日志
/// （`SharedPreferences` 的写失败不影响本次会话，与 master 的行为一致）。
@Riverpod(keepAlive: true)
class AppSettingsNotifier extends _$AppSettingsNotifier {
  @override
  AppSettings build() {
    final prefs = ref.watch(userPreferencesProvider);
    return AppSettings(
      themeMode: prefs.themeMode,
      enableDebugLogging: prefs.enableDebugLogging,
      defaultPageSize: prefs.defaultPageSize,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (state.themeMode == mode) return;
    state = state.copyWith(themeMode: mode);
    await ref.read(userPreferencesProvider).setThemeMode(mode);
  }

  Future<void> setDebugLogging({required bool enabled}) async {
    if (state.enableDebugLogging == enabled) return;
    state = state.copyWith(enableDebugLogging: enabled);
    await ref.read(userPreferencesProvider).setDebugLogging(enabled: enabled);
  }

  Future<void> setDefaultPageSize(int size) async {
    if (state.defaultPageSize == size) return;
    state = state.copyWith(defaultPageSize: size);
    await ref.read(userPreferencesProvider).setDefaultPageSize(size);
  }
}
