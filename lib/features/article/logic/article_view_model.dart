import 'package:app_core/base/failure.dart';
import 'package:app_core/base/result.dart';
import 'package:injectable/injectable.dart';
import 'package:my_app/core/base/run_async.dart';
import 'package:my_app/features/article/data/article_repository.dart';
import 'package:my_app/features/article/data/models/article.dart';
import 'package:signals_flutter/signals_flutter.dart';

/// 文章 ViewModel
///
/// 信号私有持有、以 [ReadonlySignal] 对外暴露：UI 只能订阅，写入必须走方法。
@injectable
class ArticleViewModel {
  new(this._repo);
  final ArticleRepository _repo;

  final AsyncSignal<List<Article>> _articles = asyncSignal<List<Article>>(
    AsyncState.loading(),
    options: const AsyncSignalOptions<List<Article>>(
      name: 'articleViewModel.articles',
    ),
  );
  final AsyncSignal<Article?> _selectedArticle = asyncSignal<Article?>(
    AsyncState.loading(),
    options: const AsyncSignalOptions<Article?>(
      name: 'articleViewModel.selectedArticle',
    ),
  );

  /// 文章列表；UI 只读，写入走 [loadArticles]
  ReadonlySignal<AsyncState<List<Article>>> get articles => _articles;

  /// 当前选中的文章；UI 只读，写入走 [loadDetail] / [clearSelected]
  ReadonlySignal<AsyncState<Article?>> get selectedArticle => _selectedArticle;

  /// 返回 [Result] 供需要分支处理的调用方使用；页面直接渲染信号即可
  Future<Result<void, Failure>> loadArticles() =>
      runAsync(_articles, _repo.getArticles);

  Future<Result<void, Failure>> loadDetail(int id) =>
      runAsync(_selectedArticle, () => _repo.getArticle(id));

  void clearSelected() {
    _selectedArticle.value = AsyncState.data(null);
  }
}
