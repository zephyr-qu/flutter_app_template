import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_app/core/theme/app_theme_extension.dart';
import 'package:my_app/core/ui/async_view.dart';
import 'package:my_app/core/ui/empty_widget.dart';
import 'package:my_app/core/ui/error_text.dart';
import 'package:my_app/core/ui/list_group.dart';
import 'package:my_app/core/ui/loading_indicator.dart';
import 'package:my_app/core/ui/page_body.dart';
import 'package:my_app/core/ui/page_head.dart';
import 'package:my_app/features/sample/data/models/sample_item.dart';
import 'package:my_app/features/sample/logic/sample_list_notifier.dart';

/// 示例列表页 —— **新增 feature 时照抄这一页**。
///
/// 三条页面形态在这里定死：
/// 1. `ConsumerWidget` + `ref.watch(provider)` 拿状态（不再有 hooks / getIt）
/// 2. 三态渲染一律走 `AsyncView`（不要 `AsyncValue.when`，理由见
///    ui/state-management.md「渲染状态」）
/// 3. 刷新 / 重试交给 `ref.refresh` / `ref.invalidate`，页面不持有加载逻辑
///
/// 测试时用 `ProviderScope(overrides:)` 换假仓库，页面不需要注入点构造参数。
@RoutePage()
class SampleListPage extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(sampleListProvider);

    // 页面骨架：PageHead 固定在顶部，内容区进 Expanded（见
    // ui/component-guidelines.md「页面骨架」）
    return Scaffold(
      body: PageBody(
        child: Column(
          children: [
            const PageHead(title: '示例'),
            Expanded(
              child: AsyncView<List<SampleItem>>(
                state: items,
                loading: () => const LoadingIndicator(),
                error: (error, stackTrace) => ErrorText(
                  error: error,
                  onRetry: () => ref.invalidate(sampleListProvider),
                ),
                data: (list) {
                  // 两个分支都要能下拉刷新：显式给 AlwaysScrollableScrollPhysics，
                  // 空态也要包成可滚动的。见 ui/state-management.md「页面侧的两个配套要求」。
                  return RefreshIndicator(
                    onRefresh: () => ref.refresh(sampleListProvider.future),
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: list.isEmpty
                          ? const [
                              SliverFillRemaining(
                                hasScrollBody: false,
                                child: EmptyWidget(
                                  icon: Icons.widgets_outlined,
                                  message: '暂无示例数据',
                                ),
                              ),
                            ]
                          : [
                              SliverPadding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                                // 大列表走 sliver 版：只构建可视项，不做首帧全量建树
                                sliver: SliverListGroup(
                                  itemCount: list.length,
                                  itemBuilder: (context, index) => _SampleCard(
                                    item: list[index],
                                    index: index,
                                  ),
                                ),
                              ),
                            ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SampleCard extends StatelessWidget {
  const new({required this.item, required this.index});
  final SampleItem item;
  final int index;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final appTheme = AppThemeExtension.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(appTheme.radiusMd),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(appTheme.radiusSm),
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.onPrimaryContainer,
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
                    item.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.body,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
