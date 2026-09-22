import 'package:app_core/base/failure.dart';
import 'package:app_core/base/result.dart';

import 'package:my_app/features/article/data/models/article.dart';

/// 文章仓库抽象：返回 `Result`，不抛异常。
abstract class ArticleRepository {
  Future<Result<List<Article>, Failure>> getArticles();

  Future<Result<Article, Failure>> getArticle(int id);
}
