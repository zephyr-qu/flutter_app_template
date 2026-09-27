import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/data/storage/file_storage.dart' show FileStorage;

/// 把 `path_provider` 的平台通道指向测试自己创建的临时目录。
///
/// [FileStorage] 与任何走 `getApplicationDocumentsDirectory()` /
/// `getTemporaryDirectory()` 的代码都靠它才能在没有设备的测试里跑起来。
/// 用真实目录而不是内存假对象：路径拼接、父目录不存在这类问题只有真写入才暴露。
///
/// 被 `test/core/data/{storage,database}/` 与 `test/features/demo/` 下的测试共用。
class FakePathProvider {
  /// 安装通道 mock 并创建两个空目录
  factory install() {
    final root = Directory.systemTemp.createTempSync('my_app_test');
    final appDir = Directory('${root.path}/app')..createSync(recursive: true);
    final tempDir = Directory('${root.path}/tmp')..createSync(recursive: true);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          return switch (call.method) {
            'getApplicationDocumentsDirectory' ||
            'getApplicationSupportDirectory' => appDir.path,
            'getTemporaryDirectory' => tempDir.path,
            _ => null,
          };
        });

    return FakePathProvider._(root, appDir, tempDir);
  }
  new _(this.root, this.appDir, this.tempDir);
  static const MethodChannel _channel = MethodChannel(
    'plugins.flutter.io/path_provider',
  );

  /// 本次测试的根目录
  final Directory root;

  /// 模拟的应用文档目录
  final Directory appDir;

  /// 模拟的临时目录
  final Directory tempDir;

  /// 卸载 mock 并删掉临时目录（在 tearDown 里调用）
  void dispose() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
    if (root.existsSync()) root.deleteSync(recursive: true);
  }
}
