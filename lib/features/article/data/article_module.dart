import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import 'package:my_app/core/data/database/app_database.dart';
import 'package:my_app/features/article/data/article_api.dart';
import 'package:my_app/features/article/data/article_dao.dart';

@module
abstract class ArticleModule {
  @LazySingleton()
  ArticleApi articleApi(Dio dio) => ArticleApi(dio);

  /// DAO 由 feature 装配（不用 `@DriftDatabase(daos: [...])`，原因见 backend/database-guidelines.md）
  @LazySingleton()
  ArticleDao articleDao(AppDatabase db) => ArticleDao(db);
}
