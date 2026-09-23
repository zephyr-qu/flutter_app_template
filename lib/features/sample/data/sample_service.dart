import 'package:app_core/base/failure.dart';
import 'package:app_core/base/result.dart';
import 'package:app_core/base/run_catching.dart';
import 'package:app_core/data/database/app_database.dart';
import 'package:app_core/logging/logging.dart';
import 'package:my_app/features/sample/data/models/sample_item.dart';
import 'package:my_app/features/sample/data/sample_api.dart';
import 'package:my_app/features/sample/data/sample_dao.dart';
import 'package:my_app/features/sample/data/sample_repository.dart';

/// 示例条目的数据实现：cache-aside —— 网络成功顺手刷新缓存，失败回退到缓存。
///
/// 这个类同时是「三种 data 形态」的交接点：Retrofit（[SampleApi]）→ Drift
/// （[SampleDao]）→ `Result` 包装。错误码保留与「缓存失败不影响请求结果」的
/// 约定见 backend/database-guidelines.md。
class SampleService implements SampleRepository {
  new(this._api, this._cache);
  final SampleApi _api;
  final SampleDao _cache;

  @override
  Future<Result<List<SampleItem>, Failure>> getItems() async {
    final result = await runCatching(_api.getItems);

    switch (result) {
      case Ok<List<SampleItem>, Failure>(:final data):
        await _ignoreCacheFailure(
          () => _cache.cacheItems(data.map(_toRow).toList()),
        );
        return Result.success(data);

      case Err<List<SampleItem>, Failure>(:final error):
        final cached = await _readCachedItems();
        if (cached.isNotEmpty) return Result.success(cached);
        return Result.failure(error);
    }
  }

  @override
  Future<Result<SampleItem, Failure>> getItem(int id) async {
    final result = await runCatching(() => _api.getItem(id));

    switch (result) {
      case Ok<SampleItem, Failure>(:final data):
        // 用 upsert：写单条不能把整个列表缓存清掉
        await _ignoreCacheFailure(() => _cache.cacheItem(_toRow(data)));
        return Result.success(data);

      case Err<SampleItem, Failure>(:final error):
        final cached = await _readCachedItem(id);
        if (cached != null) return Result.success(cached);
        return Result.failure(error);
    }
  }

  /// 读缓存列表；读失败按「未命中」处理
  Future<List<SampleItem>> _readCachedItems() async {
    try {
      final rows = await _cache.getCachedItems();
      return rows.map(_toModel).toList();
    } catch (e) {
      Logging.warning('读取示例缓存失败，按未命中处理: $e');
      return const [];
    }
  }

  /// 读缓存单条；读失败按「未命中」处理
  Future<SampleItem?> _readCachedItem(int id) async {
    try {
      final row = await _cache.getCachedItem(id);
      return row == null ? null : _toModel(row);
    } catch (e) {
      Logging.warning('读取示例缓存失败，按未命中处理: $e');
      return null;
    }
  }

  Future<void> _ignoreCacheFailure(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      Logging.warning('写入示例缓存失败: $e');
    }
  }

  SampleItem _toModel(DbArticle row) =>
      SampleItem(id: row.id, title: row.title, body: row.body);

  DbArticle _toRow(SampleItem model) =>
      DbArticle(id: model.id, title: model.title, body: model.body);
}
