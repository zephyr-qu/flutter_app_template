import 'package:app_core/base/failure.dart';
import 'package:app_core/base/result.dart';
import 'package:app_core/base/run_catching.dart';
import 'package:app_core/data/database/app_database.dart';
import 'package:app_core/logging/logging.dart';
import 'package:injectable/injectable.dart';
import 'package:my_app/features/article/data/article_api.dart';
import 'package:my_app/features/article/data/article_dao.dart';
import 'package:my_app/features/article/data/article_repository.dart';
import 'package:my_app/features/article/data/models/article.dart';

/// 文章服务：cache-aside —— 网络成功顺手刷新缓存，失败回退到缓存。
///
/// 错误码保留与「缓存失败不影响请求结果」的约定见 backend/database-guidelines.md。
@LazySingleton(as: ArticleRepository)
class ArticleService implements ArticleRepository {
  new(this._api, this._cache);
  final ArticleApi _api;
  final ArticleDao _cache;

  @override
  Future<Result<List<Article>, Failure>> getArticles() async {
    final result = await runCatching(_api.getArticles);

    switch (result) {
      case Ok<List<Article>, Failure>(:final data):
        await _ignoreCacheFailure(
          () => _cache.cacheArticles(data.map(_toRow).toList()),
        );
        return Result.success(data);

      case Err<List<Article>, Failure>(:final error):
        final cached = await _readCachedArticles();
        if (cached.isNotEmpty) return Result.success(cached);
        return Result.failure(error);
    }
  }

  @override
  Future<Result<Article, Failure>> getArticle(int id) async {
    final result = await runCatching(() => _api.getArticle(id));

    switch (result) {
      case Ok<Article, Failure>(:final data):
        // 用 upsert：写单篇不能把整个列表缓存清掉
        await _ignoreCacheFailure(() => _cache.cacheArticle(_toRow(data)));
        return Result.success(data);

      case Err<Article, Failure>(:final error):
        final cached = await _readCachedArticle(id);
        if (cached != null) return Result.success(cached);
        return Result.failure(error);
    }
  }

  /// 读缓存的文章列表；读失败按「未命中」处理
  Future<List<Article>> _readCachedArticles() async {
    try {
      final rows = await _cache.getCachedArticles();
      return rows.map(_toModel).toList();
    } catch (e) {
      Logging.warning('读取文章缓存失败，按未命中处理: $e');
      return const [];
    }
  }

  /// 读缓存的单篇文章；读失败按「未命中」处理
  Future<Article?> _readCachedArticle(int id) async {
    try {
      final row = await _cache.getCachedArticle(id);
      return row == null ? null : _toModel(row);
    } catch (e) {
      Logging.warning('读取文章缓存失败，按未命中处理: $e');
      return null;
    }
  }

  Future<void> _ignoreCacheFailure(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      Logging.warning('写入文章缓存失败: $e');
    }
  }

  Article _toModel(DbArticle row) =>
      Article(id: row.id, title: row.title, body: row.body);

  DbArticle _toRow(Article model) =>
      DbArticle(id: model.id, title: model.title, body: model.body);
}
