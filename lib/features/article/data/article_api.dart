import 'package:dio/dio.dart';
import 'package:my_app/features/article/data/models/article.dart';
import 'package:retrofit/retrofit.dart';

part 'article_api.g.dart';

@RestApi()
abstract class ArticleApi {
  factory(Dio dio) = _ArticleApi;

  @GET('/articles')
  Future<List<Article>> getArticles();

  @GET('/articles/{id}')
  Future<Article> getArticle(@Path('id') int id);
}
