import 'package:flutter/material.dart';
import 'package:my_app/core/theme/app_theme_extension.dart';

/// 区块标题：一行标题 + 可选说明 + 可选右侧动作（如「全部 >」）。
///
/// 页面骨架里每条分组列表、每个成块内容前都用它，别再手写
/// `Text(...).copyWith(fontWeight: w600)` + `SizedBox` 的组合。
/// 形状见 ui/component-guidelines.md「页面骨架」。
class SectionHead extends StatelessWidget {
  const new({
    required this.title,
    super.key,
    this.caption,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(
      0,
      AppThemeExtension.s20,
      0,
      AppThemeExtension.s12,
    ),
  });

  /// 区块标题（`titleMedium`，单行，超出省略）。
  final String title;

  /// 可选说明，排在标题右侧（`bodySmall`，单行，超出省略）。
  final String? caption;

  /// 右侧动作，通常是文字按钮或图标按钮。
  final Widget? trailing;

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: padding,
      child: Row(
        children: [
          Flexible(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (caption != null) ...[
            const SizedBox(width: AppThemeExtension.s8),
            Expanded(
              child: Text(
                caption!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ] else
            const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}
