import 'dart:async';

import 'package:app_core/theme/app_theme_extension.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_app/app/routing/router.dart';
import 'package:my_app/core/providers.dart';

/// 启动页——带渐入动画的品牌页。
///
/// 不接收 `isAuthenticated` 这类构造参数（初始路由拿不到参数），登录态实时读。
@RoutePage()
class SplashPage extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideUp;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    );

    _fadeIn = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.6, curve: Curves.easeOutCubic),
    );

    _slideUp = Tween<Offset>(begin: const Offset(0, 24), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.2, 0.7, curve: Curves.easeOutCubic),
          ),
        );

    _scale = Tween<double>(begin: 0.85, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.7, curve: Curves.easeOutBack),
      ),
    );

    _controller.forward();
    // 动画与跳转各走各的：这里不 await 跳转，动画不能被它阻塞
    unawaited(_redirect());
  }

  Future<void> _redirect() async {
    await Future<void>.delayed(const Duration(milliseconds: 2200));
    if (!mounted) return;

    // 页面在 app 层，可以直接用路由类（不再依赖 '/' / '/login' 这类字符串 path）
    // 注意 replaceRoute 是挂在 BuildContext 上的扩展，不是 StackRouter 的成员。
    // 守卫用的也是同一处同步判断（见 app/providers.dart 的 routerProvider）。
    final isLoggedIn = ref.read(authStorageProvider).isLoggedIn;
    await context.replaceRoute(
      isLoggedIn ? const MainRoute() : const LoginRoute(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final appTheme = AppThemeExtension.of(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorScheme.surface,
              colorScheme.surfaceContainerLow,
              colorScheme.surfaceContainer,
            ],
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fadeIn,
            child: SlideTransition(
              position: _slideUp,
              child: ScaleTransition(
                scale: _scale,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // ── Logo mark ──
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(appTheme.radiusLg),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.primary.withValues(alpha: 0.2),
                            blurRadius: 30,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.spa_outlined,
                        size: 44,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── App name ──
                    Text(
                      'My App',
                      style: theme.textTheme.displayMedium?.copyWith(
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // ── Tagline ──
                    Text(
                      '简洁 · 优雅 · 实用',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.5),
                        letterSpacing: 4,
                      ),
                    ),
                    const SizedBox(height: 48),

                    // ── Loading indicator ──
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colorScheme.primary.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
