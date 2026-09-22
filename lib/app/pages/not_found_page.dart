import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:my_app/app/routing/router.dart';

/// 404 页面
@RoutePage()
class NotFoundPage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off_rounded,
                size: 80,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 24),
              Text(
                '404',
                style: theme.textTheme.displayLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '页面未找到',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 32),
              FilledButton.tonalIcon(
                // 页面在 app 层，可以直接用路由类（不再依赖 '/' 这类字符串 path）
                // 注意 replaceRoute 是挂在 BuildContext 上的扩展，不是
                // StackRouter 的成员，所以不能写成 context.router.replaceRoute
                onPressed: () => context.replaceRoute(const MainRoute()),
                icon: const Icon(Icons.home_rounded),
                label: const Text('返回首页'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
