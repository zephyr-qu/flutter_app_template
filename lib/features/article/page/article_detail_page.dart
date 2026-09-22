import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:my_app/core/ui/async_view.dart';
import 'package:my_app/core/ui/error_text.dart';
import 'package:my_app/core/ui/loading_indicator.dart';
import 'package:my_app/di/service_locator.dart';
import 'package:my_app/features/article/data/models/article.dart';
import 'package:my_app/features/article/logic/article_view_model.dart';
import 'package:my_app/l10n/app_localizations.dart';
import 'package:signals_hooks/signals_hooks.dart';

/// 文章详情页——沉浸式阅读体验
@RoutePage()
class ArticleDetailPage extends HookWidget {
  const new({required this.articleId, super.key, this.viewModel});
  final int articleId;

  /// 可选注入点——只有测试会传值（说明见 `login_page.dart`）
  final ArticleViewModel? viewModel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    final vm = useMemoized(() => viewModel ?? getIt<ArticleViewModel>());

    useEffect(() {
      unawaited(vm.loadDetail(articleId));
      return vm.clearSelected;
    }, [articleId]);

    final AsyncState<Article?> async = useSignalValue(vm.selectedArticle);

    // 整页 loading 的形态，被 loading 与「未选中文章」两处复用
    Widget loadingScaffold() =>
        Scaffold(appBar: AppBar(), body: const LoadingIndicator());

    return AsyncView<Article?>(
      state: async,
      loading: loadingScaffold,
      error: (e, stackTrace) => Scaffold(
        appBar: AppBar(),
        body: ErrorText(error: e, onRetry: () => vm.loadDetail(articleId)),
      ),
      // null 按 loading 渲染：`clearSelected()` 写入的就是 `data(null)`，
      // 它同样走 data 分支，用 `!` 强解包会抛
      data: (article) {
        if (article == null) return loadingScaffold();
        return Scaffold(
          body: CustomScrollView(
            slivers: [
              // ── Sliver app bar ──
              SliverAppBar.large(
                title: Text(
                  article.title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                expandedHeight: 200,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          colorScheme.primaryContainer,
                          colorScheme.primaryContainer.withValues(alpha: 0.4),
                        ],
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.article_outlined,
                        size: 64,
                        color: colorScheme.primary.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                ),
              ),

              // ── Article body ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 32,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Meta info
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.tertiaryContainer,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              l10n.articleTag,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onTertiaryContainer,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            l10n.articleReadingTime(5),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Body text
                      Text(
                        article.body,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurface,
                          height: 1.8,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
