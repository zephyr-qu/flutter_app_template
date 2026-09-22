import 'package:freezed_annotation/freezed_annotation.dart';

part 'article.freezed.dart';
part 'article.g.dart';

@freezed
sealed class Article with _$Article {
  const factory({
    required int id,
    required String title,
    required String body,
  }) = _Article;

  factory fromJson(Map<String, dynamic> json) => _$ArticleFromJson(json);
}
