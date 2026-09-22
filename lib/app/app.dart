import 'package:app_core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_app/app/providers.dart';
import 'package:my_app/core/config/app_settings.dart';

/// 应用根组件 —— **只做接线**：
/// 路由与重评估触发器来自 `app/providers.dart`，主题来自 `app_core`，
/// 主题模式来自 `appSettingsProvider`（改设置立刻生效）。
///
/// 外层必须已经包好 `ProviderScope`（含 `prefsProvider` 的 override）——
/// 那是 `bootstrap()` 的责任，见 lib/bootstrap.dart。
class MyApp extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final reevaluate = ref.watch(authReevaluateProvider);
    final themeMode = ref.watch(appSettingsProvider).themeMode;

    return MaterialApp.router(
      routerConfig: router.config(reevaluateListenable: reevaluate),
      debugShowCheckedModeBanner: false,
      theme: _lightTheme,
      darkTheme: _darkTheme,
      themeMode: themeMode,
    );
  }
}

/// 主题只构建一次：`buildLightTheme()` 每次调用都会重建整份 `ThemeData`，
/// 而在 build 里重建会让所有 `Theme.of(context)` 的消费者整树重建。
/// 换主题靠 `themeMode`（亮 / 暗 / 跟随系统），不是靠换 `ThemeData`。
final ThemeData _lightTheme = buildLightTheme();
final ThemeData _darkTheme = buildDarkTheme();
