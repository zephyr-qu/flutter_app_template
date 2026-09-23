import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/data/storage/file_storage.dart';

import '../../support/fake_path_provider.dart';

/// 在真实文件系统上验证 —— 用内存假对象就测不出「路径拼错」「目录不存在」
/// 这类问题。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakePathProvider paths;
  late FileStorage storage;

  setUp(() {
    paths = FakePathProvider.install();
    storage = FileStorage();
  });

  tearDown(() => paths.dispose());

  group('FileStorage — 文本', () {
    test('saveString / readString 往返', () async {
      expect(await storage.saveString('note.txt', '你好'), isTrue);

      expect(await storage.readString('note.txt'), '你好');
      // 确认真的落到了 app 目录（本类自己的子目录里）
      expect(
        File('${(await storage.appDirectory).path}/note.txt').existsSync(),
        isTrue,
      );
    });

    test('useTemp 写到临时目录，与 app 目录互不影响', () async {
      await storage.saveString('t.txt', 'temp-content', useTemp: true);

      expect(
        File('${(await storage.tempDirectory).path}/t.txt').existsSync(),
        isTrue,
      );
      expect(
        File('${(await storage.appDirectory).path}/t.txt').existsSync(),
        isFalse,
      );
      expect(await storage.readString('t.txt'), isNull);
      expect(await storage.readString('t.txt', useTemp: true), 'temp-content');
    });

    test('文件不存在时 readString 返回 null', () async {
      expect(await storage.readString('nope.txt'), isNull);
    });

    test('写入失败时返回 false 而不是抛异常', () async {
      // 父目录不存在 → FileSystemException，应被吞掉并返回 false
      expect(await storage.saveString('missing_dir/a.txt', 'x'), isFalse);
    });
  });

  group('FileStorage — 二进制', () {
    test('saveBytes / readBytes 往返', () async {
      final bytes = Uint8List.fromList([1, 2, 3, 250]);

      expect(await storage.saveBytes('blob.bin', bytes), isTrue);

      expect(await storage.readBytes('blob.bin'), bytes);
    });

    test('文件不存在时 readBytes 返回 null', () async {
      expect(await storage.readBytes('nope.bin'), isNull);
    });
  });

  group('FileStorage — exists / delete', () {
    test('exists 反映真实状态', () async {
      expect(await storage.exists('a.txt'), isFalse);

      await storage.saveString('a.txt', 'x');

      expect(await storage.exists('a.txt'), isTrue);
    });

    test('delete 删除成功返回 true，重复删除返回 false', () async {
      await storage.saveString('a.txt', 'x');

      expect(await storage.delete('a.txt'), isTrue);
      expect(await storage.delete('a.txt'), isFalse);
    });
  });

  group('FileStorage — 只动自己的子目录', () {
    test('文件落在自己的子目录里，不写根目录', () async {
      await storage.saveString('a.txt', 'x');
      await storage.saveString('b.txt', 'x', useTemp: true);

      expect(File('${paths.appDir.path}/a.txt').existsSync(), isFalse);
      expect(File('${paths.tempDir.path}/b.txt').existsSync(), isFalse);
      expect(
        File('${(await storage.appDirectory).path}/a.txt').existsSync(),
        isTrue,
      );
      expect(
        File('${(await storage.tempDirectory).path}/b.txt').existsSync(),
        isTrue,
      );
    });

    test('clearTemp 不碰其他插件放在临时根目录里的文件', () async {
      // 其他插件往同一个临时根目录写的东西
      final foreignFile = File('${paths.tempDir.path}/other_plugin.tmp')
        ..writeAsStringSync('别人家的缓存');
      final foreignDir = Directory('${paths.tempDir.path}/plugin_cache')
        ..createSync();
      File('${foreignDir.path}/x.dat').writeAsStringSync('x');

      await storage.saveString('mine.txt', 'mine', useTemp: true);
      expect(await storage.clearTemp(), isTrue);

      // 自己的清掉了
      expect(await storage.readString('mine.txt', useTemp: true), isNull);
      // 别人的原样保留
      expect(foreignFile.existsSync(), isTrue);
      expect(File('${foreignDir.path}/x.dat').existsSync(), isTrue);
    });
  });

  group('FileStorage — clearTemp', () {
    test('清空临时目录但不影响 app 目录', () async {
      await storage.saveString('keep.txt', 'keep');
      await storage.saveString('drop.txt', 'drop', useTemp: true);

      expect(await storage.clearTemp(), isTrue);

      expect(await storage.readString('drop.txt', useTemp: true), isNull);
      expect(await storage.readString('keep.txt'), 'keep');
    });
  });

  group('FileStorage — getUsage', () {
    test('按 KB 向上取整统计 app 目录', () async {
      await storage.saveBytes('2kb.bin', Uint8List(2048));

      expect(await storage.getUsage(), 2);
    });

    test('includeTemp 时把临时目录也算进去', () async {
      await storage.saveBytes('2kb.bin', Uint8List(2048));
      await storage.saveBytes('1kb.bin', Uint8List(1024), useTemp: true);

      expect(await storage.getUsage(), 2);
      expect(await storage.getUsage(includeTemp: true), 3);
    });

    test('空目录返回 0', () async {
      expect(await storage.getUsage(), 0);
    });
  });
}
