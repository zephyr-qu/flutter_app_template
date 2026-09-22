import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// 设计 token：**只放 `ColorScheme` 表达不了的东西**（目前是圆角），不含任何 `Color` 字段。
///
/// 边界校验命令与理由见 frontend/component-guidelines.md「Theme Layer」。
@immutable
class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  const new({this.radiusSm = 8, this.radiusMd = 16, this.radiusLg = 24});

  /// 小圆角：标签、按钮、输入框
  final double radiusSm;

  /// 中圆角：卡片、面板
  final double radiusMd;

  /// 大圆角：图标容器、整块区域
  final double radiusLg;

  /// 唯一实例，亮暗主题共用。
  static const base = AppThemeExtension();

  static AppThemeExtension of(BuildContext context) =>
      Theme.of(context).extension<AppThemeExtension>()!;

  @override
  AppThemeExtension copyWith({
    double? radiusSm,
    double? radiusMd,
    double? radiusLg,
  }) {
    return AppThemeExtension(
      radiusSm: radiusSm ?? this.radiusSm,
      radiusMd: radiusMd ?? this.radiusMd,
      radiusLg: radiusLg ?? this.radiusLg,
    );
  }

  @override
  AppThemeExtension lerp(AppThemeExtension? other, double t) {
    if (other == null) return this;
    return AppThemeExtension(
      radiusSm: lerpDouble(radiusSm, other.radiusSm, t)!,
      radiusMd: lerpDouble(radiusMd, other.radiusMd, t)!,
      radiusLg: lerpDouble(radiusLg, other.radiusLg, t)!,
    );
  }
}
