import 'package:app_core/models/user.dart';
import 'package:app_core/theme/app_theme_extension.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:my_app/app/routing/router.dart';
import 'package:my_app/core/config/user_preferences.dart';
import 'package:my_app/core/data/storage/auth_storage.dart';
import 'package:my_app/core/ui/failure_message.dart';
import 'package:my_app/di/service_locator.dart';
import 'package:my_app/features/auth/data/auth_repository.dart';
import 'package:my_app/l10n/app_localizations.dart';
import 'package:signals_hooks/signals_hooks.dart';

/// 个人中心页
@RoutePage()
class ProfilePage extends HookWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final appTheme = AppThemeExtension.of(context);
    final l10n = AppLocalizations.of(context);
    final auth = getIt<AuthStorage>();
    final preferences = getIt<UserPreferences>();
    // 用 useSignalValue 订阅；读 .value 不会触发重绘
    final User? user = useSignalValue(auth.currentUser);
    final Locale? locale = useSignalValue(preferences.locale);
    final ThemeMode themeMode = useSignalValue(preferences.themeMode);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileTitle), centerTitle: false),
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
                    user?.name ?? l10n.notLoggedIn,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (user != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      l10n.welcomeUse,
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
              l10n.settings,
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),

            _SettingsCard(
              children: [
                _SettingItem(
                  icon: Icons.language_outlined,
                  title: l10n.settingsLanguage,
                  value: _languageLabel(context, locale),
                  onTap: () => _pickLanguage(context),
                ),
                _Divider(colorScheme: colorScheme),
                _SettingItem(
                  icon: Icons.palette_outlined,
                  title: l10n.settingsAppearance,
                  value: _themeLabel(context, themeMode),
                  onTap: () => _pickThemeMode(context),
                ),
                _Divider(colorScheme: colorScheme),
                // ── 以下三项是**模板占位**：只列出常见的设置入口，还没有
                //    对应的功能页面。接入自己的功能时替换 onTap；用不到就
                //    整项删掉（连同紧跟其后的 _Divider）。 ──
                _SettingItem(
                  icon: Icons.notifications_outlined,
                  title: l10n.settingsNotifications,
                  // TODO(template): 接入通知设置页
                  onTap: () {},
                ),
                _Divider(colorScheme: colorScheme),
                _SettingItem(
                  icon: Icons.lock_outlined,
                  title: l10n.settingsPrivacy,
                  // TODO(template): 接入隐私设置页
                  onTap: () {},
                ),
                _Divider(colorScheme: colorScheme),
                _SettingItem(
                  icon: Icons.help_outline,
                  title: l10n.settingsHelp,
                  // TODO(template): 接入帮助与支持页
                  onTap: () {},
                ),
                _Divider(colorScheme: colorScheme),
                // 示例入口：演示 core 的 FileStorage 与 Drift 缓存。
                // 用不到这两个设施时，连同 features/demo/ 一起删掉即可。
                _SettingItem(
                  icon: Icons.folder_outlined,
                  title: l10n.storageDemoTitle,
                  onTap: () => context.pushRoute(const StorageDemoRoute()),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // ── Logout button ──
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _logout(context),
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
                child: Text(l10n.logout),
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

  Future<void> _logout(BuildContext context) async {
    // 引用 auth 的 data 层（跨 feature 只共享数据能力，见 FSD 边界规则）
    final repository = getIt<AuthRepository>();
    final result = await repository.logout();
    if (!context.mounted) return;

    // 成功后不在这里导航：登录态信号翻转后由守卫送回登录页（再跳一次会有两个 LoginRoute）
    result.when(
      success: (_) {},
      failure: (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.localizedMessage(AppLocalizations.of(context))),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );
  }

  /// 语言名用它自己的语言书写（见 frontend/localization.md）
  String _languageLabel(BuildContext context, Locale? locale) {
    return switch (locale?.languageCode) {
      'zh' => '中文',
      'en' => 'English',
      _ => AppLocalizations.of(context).languageSystem,
    };
  }

  /// 弹出语言选择，结果写入 UserPreferences（null = 跟随系统）
  Future<void> _pickLanguage(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final preferences = getIt<UserPreferences>();
    final current = preferences.locale.value;

    final choice = await showDialog<_LanguageChoice>(
      context: context,
      builder: (dialogContext) {
        Widget option(
          String label,
          _LanguageChoice value, {
          required bool selected,
        }) {
          return ListTile(
            title: Text(label),
            trailing: selected
                ? Icon(
                    Icons.check_rounded,
                    color: Theme.of(dialogContext).colorScheme.primary,
                  )
                : null,
            onTap: () => Navigator.of(dialogContext).pop(value),
          );
        }

        return SimpleDialog(
          title: Text(l10n.languageTitle),
          children: [
            option(
              l10n.languageSystem,
              _LanguageChoice.system,
              selected: current == null,
            ),
            option(
              '中文',
              _LanguageChoice.chinese,
              selected: current?.languageCode == 'zh',
            ),
            option(
              'English',
              _LanguageChoice.english,
              selected: current?.languageCode == 'en',
            ),
          ],
        );
      },
    );

    // 用户点空白处关掉了对话框，不做任何修改
    if (choice == null) return;

    preferences.setLocale(switch (choice) {
      _LanguageChoice.system => null,
      _LanguageChoice.chinese => const Locale('zh'),
      _LanguageChoice.english => const Locale('en'),
    });
  }

  /// 与 [_languageLabel] 相反，主题名用当前界面语言书写（见 frontend/localization.md）
  String _themeLabel(BuildContext context, ThemeMode mode) {
    final l10n = AppLocalizations.of(context);
    return switch (mode) {
      ThemeMode.system => l10n.themeSystem,
      ThemeMode.light => l10n.themeLight,
      ThemeMode.dark => l10n.themeDark,
    };
  }

  /// 弹出主题选择，结果写入 UserPreferences（null = 取消）。
  ///
  /// 这里能直接用 `ThemeMode?`：`system` 本身就是枚举值，不必像语言选择器
  /// 那样另立枚举把 null 让给「跟随系统」（见 [_LanguageChoice]）。
  Future<void> _pickThemeMode(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
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
          title: Text(l10n.themeTitle),
          children: [
            option(l10n.themeSystem, ThemeMode.system),
            option(l10n.themeLight, ThemeMode.light),
            option(l10n.themeDark, ThemeMode.dark),
          ],
        );
      },
    );

    // 用户点空白处关掉了对话框，不做任何修改
    if (choice == null) return;

    preferences.setThemeMode(choice);
  }
}

/// 语言选择项。不用 `null` 表示「跟随系统」——`showDialog` 的 `null` 是「取消」
/// （见 frontend/localization.md）。
enum _LanguageChoice { system, chinese, english }

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
