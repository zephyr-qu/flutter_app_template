import 'package:flutter/material.dart';
import 'package:my_app/core/theme/app_theme_extension.dart';

/// 分组卡片容器：`surfaceContainerLow` 底 + 圆角 + 子项间自动分隔线。
///
/// 子项按传入顺序渲染，相邻两项之间插一条分隔线，首尾不插。
/// **`children` 版适合小列表（≤ 50 项）**——它是 `Column`，会一次性建出全部
/// 子项；超过 50 项用 [SliverListGroup]，别再复制出一个 `Column`。
class ListGroup extends StatelessWidget {
  const new({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final appTheme = AppThemeExtension.of(context);

    final rows = <Widget>[];
    for (var index = 0; index < children.length; index++) {
      if (index > 0) rows.add(const _GroupDivider());
      rows.add(children[index]);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(appTheme.radiusMd),
      child: ColoredBox(
        color: colorScheme.surfaceContainerLow,
        child: Column(children: rows),
      ),
    );
  }
}

/// 分组内的一行：图标 + 标题 + 可选当前值 + 右侧 chevron。
///
/// chevron 只在给了 [onTap] 时出现——没有点击行为却画箭头，是在骗用户。
class ListGroupRow extends StatelessWidget {
  const new({
    required this.title,
    super.key,
    this.icon,
    this.value,
    this.onTap,
    this.trailing,
  });

  final String title;

  /// 左侧图标；不传则不留图标位。
  final IconData? icon;

  /// 当前值（如「跟随系统」），显示在 chevron 左边。
  final String? value;

  /// 整行点击；不传则该行不可点、也不画 chevron。
  final VoidCallback? onTap;

  /// 自定义右侧内容，给了就完全不画默认的「值 + chevron」。
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppThemeExtension.s20,
          vertical: AppThemeExtension.s4,
        ),
        leading: icon == null
            ? null
            : Icon(
                icon,
                size: 22,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
        title: Text(
          title,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurface,
          ),
        ),
        trailing: trailing ?? _defaultTrailing(context),
        onTap: onTap,
      ),
    );
  }

  Widget? _defaultTrailing(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final canTap = onTap != null;

    if (value == null && !canTap) return null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (value != null)
          Text(
            value!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        if (canTap) ...[
          if (value != null) const SizedBox(width: AppThemeExtension.s4),
          Icon(
            Icons.chevron_right,
            size: 20,
            color: colorScheme.onSurface.withValues(alpha: 0.2),
          ),
        ],
      ],
    );
  }
}

/// 分组列表的 sliver 版：内部 `SliverList.separated`，**只构建可视项**。
///
/// 接在 `CustomScrollView` 的 `slivers` 里用（大列表的唯一正确形态）。
/// 外层的水平内边距交给 `SliverPadding`，本组件不管。
class SliverListGroup extends StatelessWidget {
  const new({required this.itemCount, required this.itemBuilder, super.key});

  final int itemCount;

  /// 每一行的构建器（通常返回一个 `ListGroupRow` 或自定义行）。
  final NullableIndexedWidgetBuilder itemBuilder;

  @override
  Widget build(BuildContext context) {
    return SliverList.separated(
      itemCount: itemCount,
      itemBuilder: itemBuilder,
      separatorBuilder: (context, index) => const _GroupDivider(),
    );
  }
}

/// 分组内的分隔线：左侧内缩到图标之后，与 `ListGroupRow` 的图标对齐。
class _GroupDivider extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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
