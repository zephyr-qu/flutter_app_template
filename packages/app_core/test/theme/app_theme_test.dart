import 'package:app_core/theme/app_color_scheme.dart';
import 'package:app_core/theme/app_theme.dart';
import 'package:app_core/theme/app_theme_extension.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('品牌色板', () {
    test('品牌色确实作用到了主题上（不是被默认色盖掉）', () {
      final brand = buildLightTheme().colorScheme.primary;

      expect(brand, isNot(ThemeData.light().colorScheme.primary));
      // 深色主题用的是同一套品牌色，色板换掉时两处一起变
      expect(
        buildDarkTheme().colorScheme.primary,
        isNot(ThemeData.dark().colorScheme.primary),
      );
    });

    test('applyBrandOverrides 只动语义角色，不另造 token', () {
      final base = ThemeData.light().colorScheme;

      final overridden = applyBrandOverrides(base);

      expect(
        overridden.onSurfaceVariant,
        base.onSurface.withValues(alpha: 0.6),
      );
      expect(overridden.primary, base.primary);
      expect(overridden.surface, base.surface);
    });
  });

  group('主题组装', () {
    test('亮 / 暗主题各自亮度正确', () {
      expect(buildLightTheme().brightness, Brightness.light);
      expect(buildDarkTheme().brightness, Brightness.dark);
    });

    test('设计 token 挂在 extensions 上（页面靠它取圆角）', () {
      for (final theme in [buildLightTheme(), buildDarkTheme()]) {
        expect(theme.extension<AppThemeExtension>(), AppThemeExtension.base);
      }
    });

    test('卡片 / chip / snackBar 的圆角都取自 token', () {
      final theme = buildLightTheme();
      const base = AppThemeExtension.base;

      final card = theme.cardTheme.shape! as RoundedRectangleBorder;
      expect(theme.cardTheme.elevation, 0);
      expect(card.borderRadius, BorderRadius.circular(base.radiusMd));

      final chip = theme.chipTheme.shape! as RoundedRectangleBorder;
      expect(chip.borderRadius, BorderRadius.circular(base.radiusSm));

      final snackBar = theme.snackBarTheme.shape! as RoundedRectangleBorder;
      expect(theme.snackBarTheme.behavior, SnackBarBehavior.floating);
      expect(snackBar.borderRadius, BorderRadius.circular(base.radiusSm));
    });

    test('页面转场按平台给，不用默认构造', () {
      final builders = buildLightTheme().pageTransitionsTheme.builders;

      expect(
        builders[TargetPlatform.android],
        isA<FadeUpwardsPageTransitionsBuilder>(),
      );
      expect(
        builders[TargetPlatform.iOS],
        isA<CupertinoPageTransitionsBuilder>(),
      );
    });
  });

  group('排版比例', () {
    test('字号 / 字重 / 字距按设计值', () {
      final text = buildLightTheme().textTheme;

      expect(text.displayLarge?.fontSize, 34);
      expect(text.displayLarge?.fontWeight, FontWeight.w600);
      expect(text.displayLarge?.letterSpacing, -0.5);
      expect(text.headlineSmall?.fontSize, 18);
      expect(text.headlineSmall?.fontWeight, FontWeight.w500);
      expect(text.titleLarge?.fontSize, 16);
    });

    test('不指定字体家族 —— 走平台默认，避免测试与设备上行为不同', () {
      final text = buildLightTheme().textTheme;
      final platformDefault = ThemeData.light().textTheme;

      // merge 只覆盖字号/字重/字距，字体家族保持平台默认值不变
      // （不能断言 isNull：平台默认本身就带一个字体家族）
      expect(
        text.displayLarge?.fontFamily,
        platformDefault.displayLarge?.fontFamily,
      );
      expect(
        text.bodyMedium?.fontFamily,
        platformDefault.bodyMedium?.fontFamily,
      );
    });
  });

  group('AppThemeExtension', () {
    test('默认圆角是 8 / 16 / 24', () {
      expect(AppThemeExtension.base.radiusSm, 8);
      expect(AppThemeExtension.base.radiusMd, 16);
      expect(AppThemeExtension.base.radiusLg, 24);
    });

    test('copyWith 只改传入的字段', () {
      final copied = AppThemeExtension.base.copyWith(radiusMd: 4);

      expect(copied.radiusMd, 4);
      expect(copied.radiusSm, AppThemeExtension.base.radiusSm);
      expect(copied.radiusLg, AppThemeExtension.base.radiusLg);
    });

    test('lerp 在中间点取中间值', () {
      const other = AppThemeExtension(radiusSm: 20, radiusMd: 40, radiusLg: 60);

      final mid = AppThemeExtension.base.lerp(other, 0.5);

      expect(mid.radiusSm, 14);
      expect(mid.radiusMd, 28);
      expect(mid.radiusLg, 42);
    });

    test('lerp 的 other 为 null 时返回自身', () {
      expect(
        AppThemeExtension.base.lerp(null, 0.5),
        same(AppThemeExtension.base),
      );
    });

    testWidgets('of(context) 从主题里取到 token', (tester) async {
      late AppThemeExtension fromContext;

      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: Builder(
            builder: (context) {
              fromContext = AppThemeExtension.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(fromContext, AppThemeExtension.base);
    });
  });
}
