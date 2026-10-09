import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:my_app/core/config/user_preferences.dart';
import 'package:my_app/core/data/storage/auth_storage.dart';
import 'package:my_app/core/models/user.dart';
import 'package:my_app/core/theme/app_theme_extension.dart';
import 'package:my_app/core/ui/failure_message.dart';
import 'package:my_app/di/service_locator.dart';
import 'package:my_app/features/auth/data/auth_repository.dart';
import 'package:my_app/features/profile/page/profile_header.dart';
import 'package:my_app/features/profile/page/profile_settings.dart';
import 'package:signals_hooks/signals_hooks.dart';

/// 个人中心页
///
/// 本文件只留页面骨架、登录态订阅与登出：头部卡片在 [ProfileHeader]、
/// 设置区块（含主题选择）在 [ProfileSettingsSection]。
@RoutePage()
class ProfilePage extends HookWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final appTheme = AppThemeExtension.of(context);
    final auth = getIt<AuthStorage>();
    final preferences = getIt<UserPreferences>();
    // 用 useSignalValue 订阅；读 .value 不会触发重绘
    final User? user = useSignalValue(auth.currentUser);
    final ThemeMode themeMode = useSignalValue(preferences.themeMode);

    return Scaffold(
      appBar: AppBar(title: const Text('个人'), centerTitle: false),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),

            ProfileHeader(user: user),
            const SizedBox(height: 32),

            // ── 设置区块 ──
            Text(
              '设置',
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ProfileSettingsSection(themeMode: themeMode),

            const SizedBox(height: 32),

            // ── 登出按钮 ──
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
                child: const Text('退出登录'),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
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
            content: Text(error.localizedMessage()),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );
  }
}
