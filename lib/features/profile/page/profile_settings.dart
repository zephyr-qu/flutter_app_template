import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:my_app/app/routing/router.dart';
import 'package:my_app/core/config/user_preferences.dart';
import 'package:my_app/core/theme/app_theme_extension.dart';
import 'package:my_app/di/service_locator.dart';

/// 个人中心的「设置」区块：外观选择 + 三个模板占位入口 + 本地存储示例入口。
///
/// 与页面拆开是为了让设置项接线能被单独读：本文件不含页面骨架（头部、登出）。
/// 主题模式由页面订阅 [UserPreferences.themeMode] 后经 `themeMode` 传进来回显，
/// 写入则在这里做（`setThemeMode`）。
class ProfileSettingsSection extends StatelessWidget {
  const new({required this.themeMode, super.key});

  /// 当前主题模式，用于回显「外观」项右侧的当前值
  final ThemeMode themeMode;

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      children: [
        SettingItem(
          icon: Icons.palette_outlined,
          title: '外观',
          value: _themeLabel(themeMode),
          onTap: () => _pickThemeMode(context),
        ),
        const SettingDivider(),
        // ── 以下三项是**模板占位**：只列出常见的设置入口，还没有
        //    对应的功能页面。接入自己的功能时替换 onTap；用不到就
        //    整项删掉（连同紧跟其后的 SettingDivider）。 ──
        SettingItem(
          icon: Icons.notifications_outlined,
          title: '通知',
          // TODO(template): 接入通知设置页
          onTap: () {},
        ),
        const SettingDivider(),
        SettingItem(
          icon: Icons.lock_outlined,
          title: '隐私',
          // TODO(template): 接入隐私设置页
          onTap: () {},
        ),
        const SettingDivider(),
        SettingItem(
          icon: Icons.help_outline,
          title: '帮助与支持',
          // TODO(template): 接入帮助与支持页
          onTap: () {},
        ),
        const SettingDivider(),
        // 示例入口：演示 core 的 FileStorage 与 Drift 缓存。
        // 用不到这两个设施时，连同 features/demo/ 一起删掉即可。
        SettingItem(
          icon: Icons.folder_outlined,
          title: '本地存储示例',
          onTap: () => context.pushRoute(StorageDemoRoute()),
        ),
      ],
    );
  }

  /// 主题名直接写中文（单语言，见 frontend/localization.md）
  String _themeLabel(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.system => '跟随系统',
      ThemeMode.light => '浅色',
      ThemeMode.dark => '深色',
    };
  }

  /// 弹出主题选择，结果写入 UserPreferences（null = 取消）。
  ///
  /// 这里能直接用 `ThemeMode?`：`system` 本身就是枚举值，不必像语言选择器
  /// 那样另立枚举把 null 让给「跟随系统」。
  Future<void> _pickThemeMode(BuildContext context) async {
    final preferences = getIt<UserPreferences>();
    final current = preferences.themeMode.value;

    final choice = await showDialog<ThemeMode>(
      context: context,
      builder: (dialogContext) {
        Widget option(String label, ThemeMode value) {
          return ListTile(
            title: Text(label),
            trailing: current == value
                ? Icon(
                    Icons.check_rounded,
                    color: Theme.of(dialogContext).colorScheme.primary,
                  )
                : null,
            onTap: () => Navigator.of(dialogContext).pop(value),
          );
        }

        return SimpleDialog(
          title: const Text('选择主题'),
          children: [
            option('跟随系统', ThemeMode.system),
            option('浅色', ThemeMode.light),
            option('深色', ThemeMode.dark),
          ],
        );
      },
    );

    // 用户点空白处关掉了对话框，不做任何修改
    if (choice == null) return;

    preferences.setThemeMode(choice);
  }
}

/// 设置区块的外壳：圆角面板 + 裁剪，让子项的 ink 效果不溢出圆角。
class SettingsCard extends StatelessWidget {
  const new({required this.children, super.key});

  /// 卡片内的设置项，通常由 [SettingItem] 与 [SettingDivider] 交替组成
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final appTheme = AppThemeExtension.of(context);

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(appTheme.radiusMd),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(appTheme.radiusMd),
        child: Column(children: children),
      ),
    );
  }
}

/// 单个设置项：图标 + 标题 +（可选）当前值 + 右侧箭头。
class SettingItem extends StatelessWidget {
  const new({
    required this.icon,
    required this.title,
    required this.onTap,
    this.value,
    super.key,
  });

  final IconData icon;
  final String title;

  /// 可选的当前值（外观选择器在 trailing 上显示它）
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        leading: Icon(
          icon,
          color: colorScheme.onSurface.withValues(alpha: 0.6),
          size: 22,
        ),
        title: Text(
          title,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurface,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (value != null) ...[
              Text(
                value!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(width: 4),
            ],
            Icon(
              Icons.chevron_right,
              color: colorScheme.onSurface.withValues(alpha: 0.2),
              size: 20,
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

/// 设置项之间的分隔线，两端留出图标宽度的缩进。
class SettingDivider extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 56),
      child: Divider(
        height: 1,
        thickness: 1,
        color: colorScheme.outlineVariant.withValues(alpha: 0.3),
      ),
    );
  }
}
