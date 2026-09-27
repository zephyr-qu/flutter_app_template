import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:my_app/app/routing/router.dart';
import 'package:my_app/core/theme/app_theme_extension.dart';
import 'package:my_app/core/ui/failure_message.dart';
import 'package:my_app/di/service_locator.dart';
import 'package:my_app/features/auth/logic/auth_view_model.dart';
import 'package:signals_hooks/signals_hooks.dart';

/// 登录页——温暖极简的登录体验
@RoutePage()
class LoginPage extends HookWidget {
  const new({super.key, this.viewModel});

  /// 可选注入点——只有测试会传值。
  ///
  /// 生产环境由路由构建 `const LoginPage()`，走下面的 `getIt` 兜底；这样
  /// 页面测试可以直接注入假 ViewModel，不必先装配全局容器，而路由依然
  /// 不必感知 DI（代价与取舍见 ADR-0001）。
  final AuthViewModel? viewModel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final appTheme = AppThemeExtension.of(context);

    final vm = useMemoized(() => viewModel ?? getIt<AuthViewModel>());
    final AsyncState<dynamic> userState = useSignalValue(vm.user);
    final bool canSubmit = useSignalValue(vm.canSubmit);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorScheme.surface,
              colorScheme.surfaceContainerLow,
              colorScheme.surface,
            ],
            stops: const [0.0, 0.4, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ── Brand mark ──
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(appTheme.radiusLg),
                    ),
                    child: Icon(
                      Icons.spa_outlined,
                      size: 36,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 24),

                  Text(
                    '欢迎回来',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '登录以继续使用',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // ── Email field ──
                  TextField(
                    onChanged: vm.updateEmail,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: '邮箱',
                      hintText: 'your@email.com',
                      prefixIcon: Icon(
                        Icons.email_outlined,
                        color: colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                      filled: true,
                      fillColor: colorScheme.surfaceContainerLow,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(appTheme.radiusSm),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Password field ──
                  TextField(
                    onChanged: vm.updatePassword,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: '密码',
                      hintText: '至少 6 位',
                      prefixIcon: Icon(
                        Icons.lock_outlined,
                        color: colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                      filled: true,
                      fillColor: colorScheme.surfaceContainerLow,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(appTheme.radiusSm),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ── Login button ──
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: userState.isLoading
                        ? Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: colorScheme.primary,
                              ),
                            ),
                          )
                        : FilledButton(
                            onPressed: canSubmit
                                ? () {
                                    unawaited(
                                      Future.microtask(() async {
                                        final result = await vm.login();
                                        if (!context.mounted) return;
                                        result.when(
                                          // 进 MainRoute（带底部导航的外壳），
                                          // 而不是它的子路由 HomeRoute
                                          success: (_) => context.replaceRoute(
                                            const MainRoute(),
                                          ),
                                          failure: (error) => _showError(
                                            context,
                                            error.localizedMessage(),
                                          ),
                                        );
                                      }),
                                    );
                                  }
                                : null,
                            style: FilledButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  appTheme.radiusSm,
                                ),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              '登录',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
