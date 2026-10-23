import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// 设计 token：**只放 `ColorScheme` 表达不了的东西**（圆角 + 间距标尺），不含任何 `Color` 字段。
///
/// 圆角是实例字段（亮暗主题共用 [base]）；间距是静态常量（[s4] … [s32]），
/// 因为它们不需要按主题变、还要能直接用在 `const` 构造里。
///
/// 边界校验命令与理由见 ui/component-guidelines.md「主题层」。
@immutable
class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  const new({this.radiusSm = 8, this.radiusMd = 16, this.radiusLg = 24});

  /// 小圆角：标签、按钮、输入框
  final double radiusSm;

  /// 中圆角：卡片、面板
  final double radiusMd;

  /// 大圆角：图标容器、整块区域
  final double radiusLg;

  /// ── 间距标尺 ──────────────────────────────────────────────────────────
  /// 按 dp 值命名（`s20` 就是 20dp），省掉「sm 到底多大」的猜谜。
  /// 页面边距、区块间距、行内间隙一律取这里，不写裸数字。
  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s32 = 32;

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
