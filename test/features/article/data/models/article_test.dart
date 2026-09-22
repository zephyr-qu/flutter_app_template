import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/article/data/models/article.dart';

void main() {
  group('Article model', () {
    test('fromJson parses correctly', () {
      final json = {'id': 1, 'title': '测试标题', 'body': '测试内容'};
      final article = Article.fromJson(json);

      expect(article.id, equals(1));
      expect(article.title, equals('测试标题'));
      expect(article.body, equals('测试内容'));
    });

    test('toJson serializes correctly', () {
      const article = Article(id: 1, title: '测试标题', body: '测试内容');
      final json = article.toJson();

      expect(json['id'], equals(1));
      expect(json['title'], equals('测试标题'));
      expect(json['body'], equals('测试内容'));
    });

    test('toJson roundtrip produces same object', () {
      const original = Article(id: 42, title: '标题', body: '内容');
      final json = original.toJson();
      final restored = Article.fromJson(json);

      expect(restored.id, equals(original.id));
      expect(restored.title, equals(original.title));
      expect(restored.body, equals(original.body));
    });

    test('freezed copyWith works', () {
      const article = Article(id: 1, title: '原标题', body: '原内容');
      final updated = article.copyWith(title: '新标题');

      expect(updated.id, equals(1));
      expect(updated.title, equals('新标题'));
      expect(updated.body, equals('原内容'));
    });
  });
}
