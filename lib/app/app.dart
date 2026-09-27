import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:my_app/app/routing/auth_reevaluate.dart';
import 'package:my_app/app/routing/router.dart';
import 'package:my_app/core/config/user_preferences.dart';
import 'package:my_app/core/data/storage/auth_storage.dart';
import 'package:my_app/core/theme/app_theme.dart';
import 'package:my_app/di/service_locator.dart';
import 'package:signals_hooks/signals_hooks.dart';

/// 应用根组件 —— **只做接线**：
class MyApp extends HookWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = getIt<AuthStorage>();
    final preferences = getIt<UserPreferences>();

    // 只创建一次：登录态由守卫在导航时实时读取，重建路由器会丢弃整个导航栈
    final router = useMemoized(() => AppRouter(auth));

    // 登录态变化（含 401 触发的登出）时让 auto_route 重新评估守卫
    final reevaluate = useMemoized(
      () => AuthReevaluateListenable(auth.isLoggedInSignal),
    );
    useEffect(() => reevaluate.dispose, [reevaluate]);

    final themeLight = useMemoized(buildLightTheme);
    final themeDark = useMemoized(buildDarkTheme);

    // 必须用 useSignalValue 订阅；改读 getter 只会在恰好重建时更新
    final ThemeMode themeMode = useSignalValue(preferences.themeMode);

    return MaterialApp.router(
      routerConfig: router.config(reevaluateListenable: reevaluate),
      debugShowCheckedModeBanner: false,
      theme: themeLight,
      darkTheme: themeDark,
      themeMode: themeMode,
    );
  }
}
