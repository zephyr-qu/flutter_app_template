part of '../app_database.dart';

/// 文章缓存表（`Db` 前缀派生出行类 `DbArticle` / SQL 表名 `db_articles`）。
/// 命名与「行↔模型互转放 feature」的约定见 backend/database-guidelines.md。
class DbArticles extends Table {
  IntColumn get id => integer()();
  TextColumn get title => text()();
  TextColumn get body => text()();

  @override
  Set<Column> get primaryKey => {id};
}
