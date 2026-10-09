import 'package:flutter/material.dart';
import 'package:my_app/core/models/user.dart';
import 'package:my_app/core/theme/app_theme_extension.dart';

/// 个人中心的头部卡片：渐变底 + 头像 + 用户名 + 欢迎语。
///
/// 只负责渲染：登录态由 `ProfilePage` 订阅后经 `user` 传进来，本组件不碰容器。
class ProfileHeader extends StatelessWidget {
  const new({required this.user, super.key});

  /// 当前登录用户；未登录时为 null（显示「未登录」且不显示欢迎语）
  final User? user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final appTheme = AppThemeExtension.of(context);

    return Container(
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
              _initial,
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
    );
  }

  /// 头像文字：用户名首字符；未登录或用户名为空时用 `?`
  String get _initial {
    final name = user?.name ?? '';
    return name.isEmpty ? '?' : name[0];
  }
}
