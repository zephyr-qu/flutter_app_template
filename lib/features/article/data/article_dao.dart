import 'package:app_core/data/database/app_database.dart';
import 'package:drift/drift.dart';

part 'article_dao.g.dart';

/// 文章缓存的读写（只碰行类 `DbArticle`，行↔模型转换在 `ArticleService`）。
///
/// 为什么在 feature 而不是 core，见 backend/database-guidelines.md「分工」。
@DriftAccessor(tables: [DbArticles])
class ArticleDao extends DatabaseAccessor<AppDatabase> with _$ArticleDaoMixin {
  new(super.attachedDatabase);

  /// 缓存整个文章列表（先清后写，列表是快照）。
  ///
  /// **不要**用它写单篇——会把其余缓存一并清掉，单篇请用 [cacheArticle]。
  Future<void> cacheArticles(List<DbArticle> items) async {
    await batch((batch) {
      batch
        ..deleteAll(dbArticles)
        ..insertAll(dbArticles, items);
    });
  }

  /// 写入 / 更新单篇文章，不影响其它缓存行
  Future<void> cacheArticle(DbArticle item) {
    return into(dbArticles).insertOnConflictUpdate(item);
  }

  /// 获取缓存的文章列表
  Future<List<DbArticle>> getCachedArticles() => select(dbArticles).get();

  /// 获取单篇缓存文章
  Future<DbArticle?> getCachedArticle(int id) async {
    final row = await (select(
      dbArticles,
    )..where((a) => a.id.equals(id))).getSingleOrNull();
    return row;
  }

  /// 插入示例数据（开发用：想在没有后端的情况下调试离线路径时调用）
  Future<void> seed() async {
    await cacheArticles(const [
      DbArticle(
        id: 1,
        title: 'Flutter 3.44 新特性解析',
        body: 'Flutter 3.44 引入了多项新特性和改进，包括更好的性能优化和新的 widget 组件。',
      ),
      DbArticle(
        id: 2,
        title: 'Dart 3.12 模式匹配实战',
        body: 'Dart 3.12 增强了模式匹配功能，使得代码更加简洁和表达力更强。',
      ),
    ]);
  }

  /// 清空文章缓存
  Future<void> clearAll() async {
    await delete(dbArticles).go();
  }
}
