import 'package:drift/drift.dart';
import 'package:my_app/core/data/database/app_database.dart';

part 'sample_dao.g.dart';

/// 示例条目的本地缓存读写（Drift 形态）。
///
/// 表 `DbArticles` 与数据库 `AppDatabase` 同在 `lib/core/data/database/`，
/// 所以用 idiomatic 的 `@DriftAccessor` 声明本 DAO 要访问的表。
/// 接真实业务时照此写法：新表加进 `AppDatabase` 的 `@DriftDatabase`，DAO 用
/// `@DriftAccessor(tables: [...])` 声明。
@DriftAccessor(tables: [DbArticles])
class SampleDao extends DatabaseAccessor<AppDatabase> with _$SampleDaoMixin {
  new(super.attachedDatabase);

  /// 缓存整份列表（先清后写：列表是一份快照）
  ///
  /// **不要**用它写单条 —— 会把其余缓存一并清掉，单条请用 [cacheItem]。
  Future<void> cacheItems(List<DbArticle> items) async {
    await batch((batch) {
      batch
        ..deleteAll(dbArticles)
        ..insertAll(dbArticles, items);
    });
  }

  /// 写入 / 更新单条，不影响其它缓存行
  Future<void> cacheItem(DbArticle item) =>
      into(dbArticles).insertOnConflictUpdate(item);

  Future<List<DbArticle>> getCachedItems() => select(dbArticles).get();

  Future<DbArticle?> getCachedItem(int id) async {
    final row = await (select(
      dbArticles,
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
    await delete(dbArticles).go();
  }
}
