// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sample_dao.dart';

// ignore_for_file: type=lint
mixin _$SampleDaoMixin on DatabaseAccessor<AppDatabase> {
  $DbArticlesTable get dbArticles => attachedDatabase.dbArticles;
  SampleDaoManager get managers => SampleDaoManager(this);
}

class SampleDaoManager {
  final _$SampleDaoMixin _db;
  SampleDaoManager(this._db);
  $$DbArticlesTableTableManager get dbArticles =>
      $$DbArticlesTableTableManager(_db.attachedDatabase, _db.dbArticles);
}
