import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/data/database/app_database.dart';

import '../../support/fake_path_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// 内存库：表结构与真实库完全一致，但不落盘
  AppDatabase createInMemoryDb() {
    final db = AppDatabase.connect(NativeDatabase.memory());
    addTearDown(db.close);
    return db;
  }

  test('schemaVersion 与表结构一致', () {
    expect(createInMemoryDb().schemaVersion, 1);
  });

  test('建表后可以写入并读回行', () async {
    final db = createInMemoryDb();

    await db
        .into(db.dbArticles)
        .insert(
          const DbArticlesCompanion(
            id: Value(1),
            title: Value('标题'),
            body: Value('正文'),
          ),
        );

    final rows = await db.select(db.dbArticles).get();

    expect(rows, hasLength(1));
    expect(rows.single, isA<DbArticle>());
    expect(rows.single.id, 1);
    expect(rows.single.title, '标题');
    expect(rows.single.body, '正文');
  });

  test('id 是主键：同 id 再写一次会冲突而不是插出两行', () async {
    final db = createInMemoryDb();
    const row = DbArticlesCompanion(
      id: Value(7),
      title: Value('A'),
      body: Value('a'),
    );

    await db.into(db.dbArticles).insert(row);

    await expectLater(
      db.into(db.dbArticles).insert(row),
      throwsA(isA<SqliteException>()),
    );
    expect(await db.select(db.dbArticles).get(), hasLength(1));
  });

  test('默认构造器走 path_provider 提供的目录并建库文件', () async {
    final fake = FakePathProvider.install();
    addTearDown(fake.dispose);

    final db = AppDatabase();
    addTearDown(db.close);

    // 触发 LazyDatabase 真正打开（懒连接：不查询就不会创建文件）
    await db.customSelect('SELECT 1').get();

    expect(File('${fake.appDir.path}/app.db').existsSync(), isTrue);
  });
}
