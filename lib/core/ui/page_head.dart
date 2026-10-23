import 'package:flutter/material.dart';
import 'package:my_app/core/theme/app_theme_extension.dart';

/// 页面头：标题 + 可选副标题 / 前置控件 / 右侧动作。**替代 `AppBar` 做页面头**。
///
/// 页面骨架把它固定在 `Scaffold.body` 的 `Column` 顶部（不要塞进滚动区，
/// 否则状态栏内边距会跟着滚走）。形状见 ui/component-guidelines.md「页面骨架」。
///
/// 没有 `AppBar` 就没有状态栏内边距，所以内部套 `SafeArea(bottom: false)`。
///
/// 返回键、头像这类前置控件由页面经 [leading] 传入 —— `core/` 不认识路由，
/// 也不该替页面决定「能不能 pop」。
class PageHead extends StatelessWidget {
  const new({
    required this.title,
    super.key,
    this.subtitle,
    this.leading,
    this.actions = const <Widget>[],
    this.padding = const EdgeInsets.fromLTRB(
      AppThemeExtension.s20,
      AppThemeExtension.s4,
      AppThemeExtension.s20,
      AppThemeExtension.s8,
    ),
  });

  /// 页面标题（`titleLarge`，单行，超出省略）。
  final String title;

  /// 可选副标题（`bodySmall`，单行，超出省略）。
  final String? subtitle;

  /// 可选前置控件：返回键、头像等。
  final Widget? leading;

  /// 右侧动作（图标按钮等）。
  final List<Widget> actions;

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: padding,
        child: Row(
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: AppThemeExtension.s8),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            ...actions,
          ],
        ),
      ),
    );
  }
}
