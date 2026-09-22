// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'article_dao.dart';

// ignore_for_file: type=lint
mixin _$ArticleDaoMixin on DatabaseAccessor<AppDatabase> {
  $DbArticlesTable get dbArticles => attachedDatabase.dbArticles;
  ArticleDaoManager get managers => ArticleDaoManager(this);
}

class ArticleDaoManager {
  final _$ArticleDaoMixin _db;
  ArticleDaoManager(this._db);
  $$DbArticlesTableTableManager get dbArticles =>
      $$DbArticlesTableTableManager(_db.attachedDatabase, _db.dbArticles);
}
