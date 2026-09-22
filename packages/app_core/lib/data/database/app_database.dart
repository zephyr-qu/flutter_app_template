import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

// 表必须 part 进来（drift 要求表与数据库同 library；改 import 会让 DAO 生成失败）
part 'tables/db_articles.dart';

/// 应用数据库：连接 + schema（表、版本、迁移）。
@DriftDatabase(tables: [DbArticles])
class AppDatabase extends _$AppDatabase {
  new() : super(_openConnection());

  /// 注入自定义 [QueryExecutor]（主要用于测试）
  new connect(super.e);

  @override
  int get schemaVersion => 1;
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/app.db');
    return NativeDatabase(file);
  });
}
