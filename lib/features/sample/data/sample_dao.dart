import 'package:app_core/data/database/app_database.dart';

/// 示例条目的本地缓存读写（Drift 形态）。
///
/// 用的是 `app_core` 预置的通用示例表（`id` + `title` + `body`）。表必须与
/// `@DriftDatabase` 同 library，而共享包不认识业务，所以脚手架只留了这一张。
///
/// **不写 `@DriftAccessor(tables: [...])`**：`drift_dev` 解析不到另一个 package
/// 里的表（drift#3669），生成的 mixin 会是空的。所以这里直接持有 `AppDatabase`，
/// 用它的生成 getter（`dbArticles`）取表；接真实业务时照此写法加自己的表。
class SampleDao {
  new(this._db);
  final AppDatabase _db;

  /// 缓存整份列表（先清后写：列表是一份快照）
  ///
  /// **不要**用它写单条 —— 会把其余缓存一并清掉，单条请用 [cacheItem]。
  Future<void> cacheItems(List<DbArticle> items) async {
    await _db.batch((batch) {
      batch
        ..deleteAll(_db.dbArticles)
        ..insertAll(_db.dbArticles, items);
    });
  }

  /// 写入 / 更新单条，不影响其它缓存行
  Future<void> cacheItem(DbArticle item) =>
      _db.into(_db.dbArticles).insertOnConflictUpdate(item);

  Future<List<DbArticle>> getCachedItems() => _db.select(_db.dbArticles).get();

  Future<DbArticle?> getCachedItem(int id) async {
    final row = await (_db.select(
      _db.dbArticles,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row;
  }

  /// 插入示例数据（想在没有后端的情况下调试离线路径时调用）
  Future<void> seed() async {
    await cacheItems(const [
      DbArticle(id: 1, title: '示例条目一', body: '这是脚手架的金标准示例数据。'),
      DbArticle(id: 2, title: '示例条目二', body: '照它写新 feature 即可。'),
    ]);
  }

  Future<void> clearAll() async {
    await _db.delete(_db.dbArticles).go();
  }
}
