import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:my_app/app/routing/router.dart';
import 'package:my_app/core/theme/app_theme_extension.dart';
import 'package:my_app/core/ui/async_view.dart';
import 'package:my_app/core/ui/empty_widget.dart';
import 'package:my_app/core/ui/error_text.dart';
import 'package:my_app/core/ui/loading_indicator.dart';
import 'package:my_app/di/service_locator.dart';
import 'package:my_app/features/article/data/models/article.dart';
import 'package:my_app/features/article/logic/article_view_model.dart';
import 'package:my_app/l10n/app_localizations.dart';
import 'package:signals_hooks/signals_hooks.dart';

/// 文章列表页——卡片式阅读列表
@RoutePage()
class ArticleListPage extends HookWidget {
  const new({super.key, this.viewModel});

  /// 可选注入点——只有测试会传值（说明见 `login_page.dart`）
  final ArticleViewModel? viewModel;

  @override
  Widget build(BuildContext context) {
    final vm = useMemoized(() => viewModel ?? getIt<ArticleViewModel>());
    final l10n = AppLocalizations.of(context);

    useEffect(() {
      unawaited(vm.loadArticles());
      return;
    }, []);

    final AsyncState<List<Article>> async = useSignalValue(vm.articles);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navArticles), centerTitle: false),
      // 走 AsyncView 而不是 AsyncState.map：回调是具名具类型的，error 与
      // stackTrace 都会传进来（map 的运行期猜签名问题已收敛在 core 内部）
      body: AsyncView<List<Article>>(
        state: async,
        loading: () => const LoadingIndicator(),
        error: (error, stackTrace) =>
            ErrorText(error: error, onRetry: vm.loadArticles),
        data: (list) {
          // 两个分支都要能下拉刷新：显式给 AlwaysScrollableScrollPhysics，
          // 空态也要包成可滚动的。见 frontend/state-management.md「刷新时保留旧数据」。
          return RefreshIndicator(
            onRefresh: vm.loadArticles,
            child: list.isEmpty
                ? CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: EmptyWidget(
                          icon: Icons.article_outlined,
                          message: l10n.articlesEmpty,
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final article = list[index];
                      return _ArticleCard(
                        article: article,
                        index: index,
                        onTap: () => context.pushRoute(
                          ArticleDetailRoute(articleId: article.id),
                        ),
                      );
                    },
                  ),
          );
        },
      ),
    );
  }
}

class _ArticleCard extends StatelessWidget {
  const new({required this.article, required this.index, required this.onTap});
  final Article article;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final appTheme = AppThemeExtension.of(context);
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(appTheme.radiusMd),
        child: InkWell(
          borderRadius: BorderRadius.circular(appTheme.radiusMd),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Number badge ──
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
                // ── Content ──
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        article.title,
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
                        l10n.articleReadMore,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 14,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            l10n.articleRead,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
