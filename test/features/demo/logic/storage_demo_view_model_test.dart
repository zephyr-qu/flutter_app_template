import 'dart:io';

import 'package:app_core/data/database/app_database.dart';
import 'package:app_core/data/storage/file_storage.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/article/data/article_dao.dart';
import 'package:my_app/features/demo/logic/storage_demo_view_model.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../support/fake_path_provider.dart';

/// 这里用**真实的** FileStorage + 内存数据库，跑在普通 `test()` 里。
///
/// 为什么不放在 widget 测试里：`testWidgets` 的 `pumpAndSettle` 走的是假时钟，
/// 真实的文件 / 数据库 I/O 不会在它推进的这段时间里完成——断言会假通过。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakePathProvider paths;
  late AppDatabase db;
  late StorageDemoViewModel vm;

  setUp(() async {
    paths = FakePathProvider.install();

    db = AppDatabase.connect(NativeDatabase.memory());
    addTearDown(db.close);
    // 等待表创建完成
    await db.customSelect('SELECT 1').get();

    vm = StorageDemoViewModel(FileStorage(), ArticleDao(db));
  });

  tearDown(() => paths.dispose());

  // FileStorage 只在自己的子目录里读写（不和别的插件抢临时目录根）
  File appFile(String name) =>
      File('${paths.appDir.path}/${FileStorage.namespace}/$name');
  File tempFile(String name) =>
      File('${paths.tempDir.path}/${FileStorage.namespace}/$name');

  group('StorageDemoViewModel — 初始状态', () {
    test('refresh 读到空文件与 0 条缓存', () async {
      await vm.refresh();

      expect(vm.savedContent.value, isNull);
      expect(vm.usageKb.value, 0);
      expect(vm.cachedCount.value, 0);
      expect(vm.lastActionFailed.value, isFalse);
    });
  });

  group('StorageDemoViewModel — 文件', () {
    test('saveNote 同时写应用目录与临时目录，并刷新出内容', () async {
      vm.updateNote('hello');

      await vm.saveNote();

      expect(vm.savedContent.value, 'hello');
      expect(vm.lastActionFailed.value, isFalse);
      expect(appFile(StorageDemoViewModel.noteFileName).existsSync(), isTrue);
      expect(tempFile(StorageDemoViewModel.tempFileName).existsSync(), isTrue);
    });

    test('saveNote 后占用不再是 0', () async {
      vm.updateNote('hello');

      await vm.saveNote();

      expect(vm.usageKb.value, greaterThan(0));
    });

    test('deleteNote 删掉两个文件并回到空状态', () async {
      vm.updateNote('hello');
      await vm.saveNote();

      await vm.deleteNote();

      expect(vm.savedContent.value, isNull);
      expect(appFile(StorageDemoViewModel.noteFileName).existsSync(), isFalse);
      expect(tempFile(StorageDemoViewModel.tempFileName).existsSync(), isFalse);
    });

    test('clearTemp 只清临时目录', () async {
      vm.updateNote('hello');
      await vm.saveNote();

      await vm.clearTemp();

      expect(vm.savedContent.value, 'hello');
      expect(tempFile(StorageDemoViewModel.tempFileName).existsSync(), isFalse);
    });
  });

  group('StorageDemoViewModel — 缓存', () {
    test('seedCache 填出 2 条示例数据', () async {
      await vm.seedCache();

      expect(vm.cachedCount.value, 2);
      expect(vm.lastActionFailed.value, isFalse);
    });

    test('clearCache 清空缓存', () async {
      await vm.seedCache();

      await vm.clearCache();

      expect(vm.cachedCount.value, 0);
    });
  });

  group('StorageDemoViewModel — 信号写入', () {
    test('refresh 的三个信号合成一次通知（batch）', () async {
      // 先让底层有数据：这样 refresh 时三个信号的值都会真的变化。
      // signal 只在值变化时通知，值没变的话根本观察不到 batch 的效果。
      final files = FileStorage();
      await files.saveString(StorageDemoViewModel.noteFileName, '磁盘上的内容');
      await ArticleDao(db).seed();

      // 一个 effect 同时依赖这三个信号：逐条赋值会跑三趟，batch 后只跑一趟
      var runs = 0;
      var lastSummary = '';
      final dispose = effect(() {
        lastSummary =
            '${vm.savedContent.value}/${vm.usageKb.value}/${vm.cachedCount.value}';
        runs++;
      });
      addTearDown(dispose);

      expect(runs, 1, reason: 'effect 创建时同步跑一趟');

      await vm.refresh();

      expect(runs, 2, reason: '三个信号合成一次通知；逐条赋值会变成 4 趟');
      expect(lastSummary, startsWith('磁盘上的内容/'));
    });
  });

  group('StorageDemoViewModel — 失败处理', () {
    test('底层不可用时把 lastActionFailed 置为 true，而不是抛出去', () async {
      // 卸载 path_provider 的 mock：拿不到目录，FileStorage 内部会返回 false
      paths.dispose();
      vm.updateNote('x');

      await vm.saveNote();

      expect(vm.lastActionFailed.value, isTrue);
      expect(vm.savedContent.value, isNull);
    });
  });
}
