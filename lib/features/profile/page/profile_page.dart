import 'package:app_core/models/user.dart';
import 'package:app_core/theme/app_theme_extension.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_app/app/routing/router.dart';
import 'package:my_app/core/auth/session.dart';
import 'package:my_app/core/config/app_settings.dart';
import 'package:my_app/core/ui/failure_message.dart';
import 'package:my_app/features/auth/data/auth_providers.dart';

/// 个人中心页
@RoutePage()
class ProfilePage extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final appTheme = AppThemeExtension.of(context);
    // 必须 ref.watch：读一次快照不会触发重绘
    final user = ref.watch(sessionProvider);
    final themeMode = ref.watch(appSettingsProvider).themeMode;

    return Scaffold(
      appBar: AppBar(title: const Text('个人'), centerTitle: false),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),

            // ── Profile header card ──
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
                    child: Text(
                      _userInitial(user),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: colorScheme.onPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user?.name ?? '未登录',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (user != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '欢迎使用',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 32),

            // ── Settings section ──
            Text(
              '设置',
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),

            _SettingsCard(
              children: [
                _SettingItem(
                  icon: Icons.palette_outlined,
                  title: '外观',
                  value: _themeLabel(context, themeMode),
                  onTap: () => _pickThemeMode(context, ref),
                ),
                _Divider(colorScheme: colorScheme),
                // ── 以下三项是**模板占位**：只列出常见的设置入口，还没有
                //    对应的功能页面。接入自己的功能时替换 onTap；用不到就
                //    整项删掉（连同紧跟其后的 _Divider）。 ──
                _SettingItem(
                  icon: Icons.notifications_outlined,
                  title: '通知',
                  // TODO(template): 接入通知设置页
                  onTap: () {},
                ),
                _Divider(colorScheme: colorScheme),
                _SettingItem(
                  icon: Icons.lock_outlined,
                  title: '隐私',
                  // TODO(template): 接入隐私设置页
                  onTap: () {},
                ),
                _Divider(colorScheme: colorScheme),
                _SettingItem(
                  icon: Icons.help_outline,
                  title: '帮助与支持',
                  // TODO(template): 接入帮助与支持页
                  onTap: () {},
                ),
                _Divider(colorScheme: colorScheme),
                // 示例入口：features/sample 是新增 feature 的金标准，
                // 新项目不需要它时连同整个目录一起删掉即可。
                _SettingItem(
                  icon: Icons.widgets_outlined,
                  title: '功能示例',
                  onTap: () => context.pushRoute(const SampleListRoute()),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // ── Logout button ──
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _logout(context, ref),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  side: BorderSide(
                    color: colorScheme.error.withValues(alpha: 0.4),
                  ),
                  foregroundColor: colorScheme.error,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(appTheme.radiusSm),
                  ),
                ),
                child: const Text('退出登录'),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  String _userInitial(User? user) {
    if (user == null) return '?';
    return user.name.isNotEmpty ? user.name[0] : '?';
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    // 引用 auth 的 data 层（跨 feature 只共享数据能力，见 FSD 边界规则）
    final result = await ref.read(authRepositoryProvider).logout();
    if (!context.mounted) return;

    // 成功后不在这里导航：登录态翻转后由守卫送回登录页（再跳一次会有两个 LoginRoute）
    result.when(
      success: (_) {},
      failure: (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.localizedMessage()),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );
  }

  /// 主题名用当前界面语言书写（见 frontend/localization.md）
  String _themeLabel(BuildContext context, ThemeMode mode) {
    return switch (mode) {
      ThemeMode.system => '跟随系统',
      ThemeMode.light => '浅色',
      ThemeMode.dark => '深色',
    };
  }

  /// 弹出主题选择，结果写入 `AppSettingsNotifier`（null = 取消）。
  ///
  /// 这里能直接用 `ThemeMode?`：`system` 本身就是枚举值，不必像语言选择器
  /// 那样另立枚举把 null 让给「跟随系统」。
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

class _SettingsCard extends StatelessWidget {
  const new({required this.children});
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

class _SettingItem extends StatelessWidget {
  const new({
    required this.icon,
    required this.title,
    required this.onTap,
    this.value,
  });
  final IconData icon;
  final String title;

  /// 可选的当前值（语言/外观选择器在 trailing 上显示它）
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

class _Divider extends StatelessWidget {
  const new({required this.colorScheme});
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
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
