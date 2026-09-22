import 'package:app_core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:my_app/core/config/user_preferences.dart';
import 'package:my_app/core/data/storage/auth_storage.dart';
import 'package:my_app/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 页面测试的公共装配。
///
/// 用**真实的** `AuthStorage` / `UserPreferences`——它们各自有单元测试，
/// 页面测试再 mock 一遍既重复、又容易掩盖接线错误。只把网络与仓库换成 mock。
typedef TestAppContext = ({
  SharedPreferences prefs,
  AuthStorage storage,
  UserPreferences preferences,
});

Future<TestAppContext> setUpTestApp() async {
  SharedPreferences.setMockInitialValues({});
  FlutterSecureStorage.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  final storage = AuthStorage(prefs, const FlutterSecureStorage());
  await storage.ready;
  final preferences = UserPreferences(prefs);

  await GetIt.I.reset();
  GetIt.I.registerSingleton<AuthStorage>(storage);
  GetIt.I.registerSingleton<UserPreferences>(preferences);

  return (prefs: prefs, storage: storage, preferences: preferences);
}

Future<void> tearDownTestApp() => GetIt.I.reset();

/// 页面测试专用外壳。
///
/// 两件必须做的事：
/// - 挂上 l10n delegate（页面通过 `AppLocalizations.of(context)` 取文案，缺了会空断言）
/// - 用 `buildLightTheme()`（页面通过 `AppThemeExtension.of(context)!` 取圆角等 token）
Widget wrapPage(Widget page, {Locale locale = const Locale('zh')}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: buildLightTheme(),
    home: page,
  );
}
