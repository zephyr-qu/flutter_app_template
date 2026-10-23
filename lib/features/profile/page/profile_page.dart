import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_app/app/routing/router.dart';
import 'package:my_app/core/config/app_settings.dart';
import 'package:my_app/core/theme/app_theme_extension.dart';
import 'package:my_app/core/ui/list_group.dart';
import 'package:my_app/core/ui/page_body.dart';
import 'package:my_app/core/ui/page_head.dart';
import 'package:my_app/core/ui/section_head.dart';

/// 个人中心页
@RoutePage()
class ProfilePage extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final appTheme = AppThemeExtension.of(context);
    final themeMode = ref.watch(appSettingsProvider).themeMode;

    return Scaffold(
      body: PageBody(
        child: Column(
          children: [
            const PageHead(title: '个人'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            colorScheme.primaryContainer,
                            colorScheme.primaryContainer.withValues(alpha: 0.5),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(appTheme.radiusMd),
                      ),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 44,
                            backgroundColor: colorScheme.primary,
                            child: Icon(
                              Icons.spa_outlined,
                              size: 40,
                              color: colorScheme.onPrimary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'My App',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '欢迎使用',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SectionHead(title: '设置'),

                    ListGroup(
                      children: [
                        ListGroupRow(
                          icon: Icons.palette_outlined,
                          title: '外观',
                          value: _themeLabel(context, themeMode),
                          onTap: () => _pickThemeMode(context, ref),
                        ),
                        // ── 以下三项是**模板占位**：只列出常见的设置入口，还没有
                        //    对应的功能页面。接入自己的功能时替换 onTap；用不到就
                        //    整项删掉。 ──
                        ListGroupRow(
                          icon: Icons.notifications_outlined,
                          title: '通知',
                          // TODO(template): 接入通知设置页
                          onTap: () {},
                        ),
                        ListGroupRow(
                          icon: Icons.lock_outlined,
                          title: '隐私',
                          // TODO(template): 接入隐私设置页
                          onTap: () {},
                        ),
                        ListGroupRow(
                          icon: Icons.help_outline,
                          title: '帮助与支持',
                          // TODO(template): 接入帮助与支持页
                          onTap: () {},
                        ),
                        // 示例入口：features/sample 是新增 feature 的金标准，
                        // 新项目不需要它时连同整个目录一起删掉即可。
                        ListGroupRow(
                          icon: Icons.widgets_outlined,
                          title: '功能示例',
                          // 切到「示例」标签，而不是 push 一个没有底部导航的新页面
                          onTap: () =>
                              AutoTabsRouter.of(context)
                                  .navigate(const SampleListRoute()),
                        ),
                      ],
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 主题名直接写中文（见 ui/localization.md「文案写在哪」）
  String _themeLabel(BuildContext context, ThemeMode mode) {
    return switch (mode) {
      ThemeMode.system => '跟随系统',
      ThemeMode.light => '浅色',
      ThemeMode.dark => '深色',
    };
  }

  /// 弹出主题选择，结果写入 `AppSettingsNotifier`（null = 取消）。
  ///
  /// 这里能直接用 `ThemeMode?`：`system` 本身就是枚举值，
  /// null 只表示「取消选择」，不必另立一个「跟随系统」哨兵值。
  Future<void> _pickThemeMode(BuildContext context, WidgetRef ref) async {
    final current = ref.read(appSettingsProvider).themeMode;

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
    if (!context.mounted) return;

    await ref.read(appSettingsProvider.notifier).setThemeMode(choice);
  }
}
