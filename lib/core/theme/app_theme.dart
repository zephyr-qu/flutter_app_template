import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:my_app/core/theme/app_color_scheme.dart';
import 'package:my_app/core/theme/app_theme_extension.dart';

/// 主题组装 —— 对外只暴露 [buildLightTheme] / [buildDarkTheme]。
///
/// 三个主题文件的分工、字体与 token 约定见 frontend/component-guidelines.md「Theme Layer」。

/// 构建应用浅色主题。
ThemeData buildLightTheme() => _buildTheme(Brightness.light);

/// 构建应用深色主题。
ThemeData buildDarkTheme() => _buildTheme(Brightness.dark);

ThemeData _buildTheme(Brightness brightness) {
  final base = switch (brightness) {
    Brightness.light => FlexThemeData.light(
      colors: brandColors,
      surfaceMode: FlexSurfaceMode.highSurfaceLowScaffold,
      blendLevel: 25,
      appBarStyle: FlexAppBarStyle.background,
      visualDensity: FlexColorScheme.comfortablePlatformDensity,
      useMaterial3ErrorColors: true,
      tabBarStyle: FlexTabBarStyle.forBackground,
      textTheme: _textTheme,
      primaryTextTheme: _textTheme,
    ),
    Brightness.dark => FlexThemeData.dark(
      colors: brandColors,
      surfaceMode: FlexSurfaceMode.highSurfaceLowScaffold,
      blendLevel: 25,
      appBarStyle: FlexAppBarStyle.background,
      visualDensity: FlexColorScheme.comfortablePlatformDensity,
      useMaterial3ErrorColors: true,
      tabBarStyle: FlexTabBarStyle.forBackground,
      textTheme: _textTheme,
      primaryTextTheme: _textTheme,
    ),
  };

  return base.copyWith(
    // 语义色覆盖统一走这里，页面层只读 colorScheme
    colorScheme: applyBrandOverrides(base.colorScheme),
    extensions: const [AppThemeExtension.base],
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    cardTheme: base.cardTheme.copyWith(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppThemeExtension.base.radiusMd),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppThemeExtension.base.radiusSm),
      ),
    ),
    snackBarTheme: base.snackBarTheme.copyWith(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppThemeExtension.base.radiusSm),
      ),
    ),
  );
}

/// 排版比例（字号 / 字重 / 字距）；基类取 `ThemeData.light().textTheme` 再 merge，
/// **不指定字体家族**，走平台默认。
final TextTheme _textTheme = ThemeData.light().textTheme.merge(
  const TextTheme(
    displayLarge: TextStyle(
      fontSize: 34,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.5,
    ),
    displayMedium: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.25,
    ),
    headlineLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
    headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
    headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
    titleLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
  ),
);
