import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/data/database/app_database.dart';
import 'package:my_app/features/article/data/article_dao.dart';

/// 内存数据库供测试用，避免读写设备文件
AppDatabase createTestDb() {
  final db = AppDatabase.connect(NativeDatabase.memory());
  // 确保表已创建
  addTearDown(db.close);
  return db;
}

void main() {
  group('ArticleDao', () {
    late AppDatabase db;
    late ArticleDao dao;

    setUp(() async {
      db = createTestDb();
      // 等待表创建完成
      await db.customSelect('SELECT 1').get();
      dao = ArticleDao(db);
    });

    group('seed / read', () {
      test('seed 插入示例数据后可以读取', () async {
        await dao.seed();

        final articles = await dao.getCachedArticles();

        expect(articles, hasLength(2));
        expect(articles[0].title, 'Flutter 3.44 新特性解析');
        expect(articles[1].title, 'Dart 3.12 模式匹配实战');
      });

      test('可以读取单篇文章', () async {
        await dao.seed();

        final article = await dao.getCachedArticle(1);

        expect(article, isNotNull);
        expect(article!.title, 'Flutter 3.44 新特性解析');
        expect(article.body, startsWith('Flutter'));
      });

      test('读取不存在的 id 返回 null', () async {
        await dao.seed();

        final article = await dao.getCachedArticle(999);

        expect(article, isNull);
      });
    });

    group('cacheArticles', () {
      test('写入后可通过 getCachedArticles 读取', () async {
        final articles = [
          const DbArticle(id: 10, title: 'Test 1', body: 'Body 1'),
          const DbArticle(id: 20, title: 'Test 2', body: 'Body 2'),
        ];

        await dao.cacheArticles(articles);

        final cached = await dao.getCachedArticles();
        expect(cached, hasLength(2));
        expect(cached[0].id, 10);
        expect(cached[1].title, 'Test 2');
      });

      test('重复调用 cacheArticles 会覆盖旧数据', () async {
        await dao.cacheArticles([
          const DbArticle(id: 1, title: 'First', body: 'First body'),
        ]);
        await dao.cacheArticles([
          const DbArticle(id: 2, title: 'Second', body: 'Second body'),
        ]);

        final cached = await dao.getCachedArticles();
        expect(cached, hasLength(1));
        expect(cached[0].title, 'Second');
      });
    });

    group('cacheArticle（单篇 upsert）', () {
      test('写单篇不会清掉列表里的其它文章', () async {
        await dao.cacheArticles([
          const DbArticle(id: 1, title: 'A', body: 'a'),
          const DbArticle(id: 2, title: 'B', body: 'b'),
        ]);

        await dao.cacheArticle(const DbArticle(id: 3, title: 'C', body: 'c'));

        final cached = await dao.getCachedArticles();
        expect(cached.map((a) => a.id), containsAll(<int>[1, 2, 3]));
      });

      test('同 id 写入会覆盖', () async {
        await dao.cacheArticle(const DbArticle(id: 1, title: '旧', body: 'old'));
        await dao.cacheArticle(const DbArticle(id: 1, title: '新', body: 'new'));

        final cached = await dao.getCachedArticles();
        expect(cached, hasLength(1));
        expect(cached.single.title, '新');
      });
    });

    group('clearAll', () {
      test('清空后查询结果为空', () async {
        await dao.seed();
        await dao.clearAll();

        final articles = await dao.getCachedArticles();
        expect(articles, isEmpty);
      });
    });
  });
}
