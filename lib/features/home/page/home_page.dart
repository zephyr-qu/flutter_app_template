import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:my_app/app/routing/router.dart';
import 'package:my_app/core/data/storage/auth_storage.dart';
import 'package:my_app/core/models/user.dart';
import 'package:my_app/core/theme/app_theme_extension.dart';
import 'package:my_app/di/service_locator.dart';
import 'package:signals_hooks/signals_hooks.dart';

/// 首页仪表盘——温暖极简的个人总览
@RoutePage()
class HomePage extends HookWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final appTheme = AppThemeExtension.of(context);
    final auth = getIt<AuthStorage>();
    // 订阅信号：直接读 .value 只在恰好重建时才更新（本页被主框架常驻，
    // 用户变化时不会自己重建）
    final User? user = useSignalValue(auth.currentUser);

    return Scaffold(
      appBar: AppBar(title: const Text('首页'), centerTitle: false),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Welcome card ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colorScheme.primary,
                    colorScheme.primary.withValues(alpha: 0.85),
                  ],
                ),
                borderRadius: BorderRadius.circular(appTheme.radiusMd),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.primary.withValues(alpha: 0.25),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: colorScheme.onPrimary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(
                            appTheme.radiusSm,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            _userInitial(user),
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: colorScheme.onPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '你好, ${user?.name ?? '用户'}',
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: colorScheme.onPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '今天也是美好的一天',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onPrimary.withValues(
                                  alpha: 0.75,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // ── Quick actions ──
            Text(
              '快捷功能',
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _QuickActionCard(
                    icon: Icons.article_outlined,
                    label: '文章',
                    color: colorScheme.tertiary,
                    gradientColors: [
                      colorScheme.tertiaryContainer,
                      colorScheme.tertiaryContainer.withValues(alpha: 0.6),
                    ],
                    iconColor: colorScheme.onTertiaryContainer,
                    onTap: () => context.pushRoute(ArticleListRoute()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickActionCard(
                    icon: Icons.person_outlined,
                    label: '个人',
                    color: colorScheme.secondary,
                    gradientColors: [
                      colorScheme.secondaryContainer,
                      colorScheme.secondaryContainer.withValues(alpha: 0.6),
                    ],
                    iconColor: colorScheme.onSecondaryContainer,
                    onTap: () => context.pushRoute(const ProfileRoute()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickActionCard(
                    icon: Icons.settings_outlined,
                    label: '设置',
                    color: colorScheme.primary,
                    gradientColors: [
                      colorScheme.primaryContainer,
                      colorScheme.primaryContainer.withValues(alpha: 0.6),
                    ],
                    iconColor: colorScheme.onPrimaryContainer,
                    // 设置区就在个人页，快捷入口直接跳过去，不留空手势
                    onTap: () => context.pushRoute(const ProfileRoute()),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // ── Recent activity placeholder ──
            Text(
              '最近动态',
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(appTheme.radiusMd),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.timeline_outlined,
                    size: 40,
                    color: colorScheme.onSurface.withValues(alpha: 0.15),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '暂无最近动态',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.3),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  String _userInitial(User? user) {
    final name = user?.name;
    if (name == null || name.isEmpty) return '?';
    return name[0];
  }
}

class _QuickActionCard extends StatelessWidget {
  const new({
    required this.icon,
    required this.label,
    required this.color,
    required this.gradientColors,
    required this.iconColor,
    this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final List<Color> gradientColors;
  final Color iconColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final appTheme = AppThemeExtension.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(appTheme.radiusMd),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradientColors,
            ),
            borderRadius: BorderRadius.circular(appTheme.radiusMd),
          ),
          child: Column(
            children: [
              Icon(icon, size: 28, color: iconColor),
              const SizedBox(height: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: iconColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
