import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';

/// 品牌色板 —— **换品牌配色只改这里**（六个值，其余派生色由主题生成器算全）。
///
/// `flex_color_scheme` 只允许出现在 `lib/core/theme/` 内，见 frontend/component-guidelines.md「Theme Layer」。
const brandColors = FlexSchemeColor(
  primary: Color(0xFF0D7377),
  primaryContainer: Color(0xFFB8E6DC),
  secondary: Color(0xFFCF7A5A),
  secondaryContainer: Color(0xFFF8DED5),
  tertiary: Color(0xFF8B6A3E),
  tertiaryContainer: Color(0xFFF0DDBE),
);

/// 覆盖需要**偏离 Material 默认**的语义角色（目前是比 M3 更淡的次级文字）。
///
/// 偏离要在语义角色下做，不要另造同义 token —— 见 frontend/component-guidelines.md。
ColorScheme applyBrandOverrides(ColorScheme base) =>
    base.copyWith(onSurfaceVariant: base.onSurface.withValues(alpha: 0.6));
