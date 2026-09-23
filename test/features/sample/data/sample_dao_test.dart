import 'package:app_core/data/database/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/sample/data/sample_dao.dart';

/// 内存数据库供测试用，避免读写设备文件。
AppDatabase createTestDb() {
  final db = AppDatabase.connect(NativeDatabase.memory());
  addTearDown(db.close);
  return db;
}

void main() {
  group('SampleDao', () {
    late AppDatabase db;
    late SampleDao dao;

    setUp(() async {
      db = createTestDb();
      // 等待表创建完成
      await db.customSelect('SELECT 1').get();
      dao = SampleDao(db);
    });

    group('seed / read', () {
      test('seed 插入示例数据后可以读取', () async {
        await dao.seed();

        final items = await dao.getCachedItems();

        expect(items, hasLength(2));
        expect(items[0].title, '示例条目一');
        expect(items[1].title, '示例条目二');
      });

      test('可以读取单条', () async {
        await dao.seed();

        final item = await dao.getCachedItem(1);

        expect(item, isNotNull);
        expect(item!.title, '示例条目一');
        expect(item.body, contains('脚手架'));
      });

      test('读取不存在的 id 返回 null', () async {
        await dao.seed();

        expect(await dao.getCachedItem(999), isNull);
      });
    });

    group('cacheItems（整份快照）', () {
      test('写入后可通过 getCachedItems 读取', () async {
        await dao.cacheItems(const [
          DbArticle(id: 10, title: 'Test 1', body: 'Body 1'),
          DbArticle(id: 20, title: 'Test 2', body: 'Body 2'),
        ]);

        final cached = await dao.getCachedItems();
        expect(cached, hasLength(2));
        expect(cached[0].id, 10);
        expect(cached[1].title, 'Test 2');
      });

      test('重复调用会覆盖旧数据（先清后写）', () async {
        await dao.cacheItems(const [
          DbArticle(id: 1, title: 'First', body: 'First body'),
        ]);
        await dao.cacheItems(const [
          DbArticle(id: 2, title: 'Second', body: 'Second body'),
        ]);

        final cached = await dao.getCachedItems();
        expect(cached, hasLength(1));
        expect(cached.single.title, 'Second');
      });
    });

    group('cacheItem（单条 upsert）', () {
      test('写单条不会清掉列表里的其它行', () async {
        await dao.cacheItems(const [
          DbArticle(id: 1, title: 'A', body: 'a'),
          DbArticle(id: 2, title: 'B', body: 'b'),
        ]);

        await dao.cacheItem(const DbArticle(id: 3, title: 'C', body: 'c'));

        final cached = await dao.getCachedItems();
        expect(cached.map((item) => item.id), containsAll(<int>[1, 2, 3]));
      });

      test('同 id 写入会覆盖', () async {
        await dao.cacheItem(const DbArticle(id: 1, title: '旧', body: 'old'));
        await dao.cacheItem(const DbArticle(id: 1, title: '新', body: 'new'));

        final cached = await dao.getCachedItems();
        expect(cached, hasLength(1));
        expect(cached.single.title, '新');
      });
    });

    group('clearAll', () {
      test('清空后查询结果为空', () async {
        await dao.seed();
        await dao.clearAll();

        expect(await dao.getCachedItems(), isEmpty);
      });
    });
  });
}
