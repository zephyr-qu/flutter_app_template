import 'package:app_core/theme/app_theme_extension.dart';
import 'package:flutter/material.dart';

/// 统一空状态组件
class EmptyWidget extends StatelessWidget {
  const new({
    required this.message,
    super.key,
    this.icon,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final appTheme = AppThemeExtension.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ── Empty icon container ──
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(appTheme.radiusLg),
              ),
              child: Icon(
                icon ?? Icons.inbox_rounded,
                size: 40,
                color: colorScheme.onSurface.withValues(alpha: 0.2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              message,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              FilledButton.tonal(
                onPressed: onAction,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(appTheme.radiusSm),
                  ),
                ),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
