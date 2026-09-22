import 'dart:io';
import 'dart:typed_data';

import 'package:app_core/logging/logging.dart';
import 'package:path_provider/path_provider.dart';

/// 文本 / 字节的文件读写。
///
/// 所有文件都落在**自己的子目录**里（见 [namespace]），不直接写根目录。临时目录是
/// 全 App 共用的，其他插件（图片缓存、下载、播放器…）也会往里放文件；没有一个自己
/// 的目录，就没法安全地「只清自己的」——见 [clearTemp]。
///
/// **不带 DI 注解**：本包不依赖 injectable / get_it / riverpod，注册由各分支的
/// 装配层负责（signals 分支见 `lib/core/core_module.dart`）。
class FileStorage {
  /// 应用目录 / 临时目录下用来存放本类文件的子目录名。
  ///
  /// 刻意与 App 名解耦：重命名模板不必跟着改，也不容易和别的插件撞名。
  static const String namespace = 'file_storage';

  Future<Directory>? _appDir;
  Future<Directory>? _tempDir;

  /// 本类的应用目录（`<documents>/file_storage`），用于长期数据
  Future<Directory> get appDirectory =>
      _appDir ??= _ownedDir(getApplicationDocumentsDirectory);

  /// 本类的临时目录（`<tmp>/file_storage`），用于缓存
  Future<Directory> get tempDirectory =>
      _tempDir ??= _ownedDir(getTemporaryDirectory);

  /// 在 [base] 下建（或复用）自己的子目录；路径可直接用，不必先 `create`
  Future<Directory> _ownedDir(Future<Directory> Function() base) async {
    final dir = Directory('${(await base()).path}/$namespace');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<String> _buildPath(String filename, {bool useTemp = false}) async {
    final dir = useTemp ? await tempDirectory : await appDirectory;
    return '${dir.path}/$filename';
  }

  Future<bool> saveString(
    String filename,
    String content, {
    bool useTemp = false,
  }) async {
    try {
      final path = await _buildPath(filename, useTemp: useTemp);
      final file = File(path);
      await file.writeAsString(content, flush: true);
      return true;
    } catch (e) {
      _logError('saveString failed: $e');
      return false;
    }
  }

  Future<String?> readString(String filename, {bool useTemp = false}) async {
    try {
      final path = await _buildPath(filename, useTemp: useTemp);
      final file = File(path);
      if (await file.exists()) {
        return await file.readAsString();
      }
      return null;
    } catch (e) {
      _logError('readString failed: $e');
      return null;
    }
  }

  Future<bool> saveBytes(
    String filename,
    Uint8List bytes, {
    bool useTemp = false,
  }) async {
    try {
      final path = await _buildPath(filename, useTemp: useTemp);
      final file = File(path);
      await file.writeAsBytes(bytes, flush: true);
      return true;
    } catch (e) {
      _logError('saveBytes failed: $e');
      return false;
    }
  }

  Future<Uint8List?> readBytes(String filename, {bool useTemp = false}) async {
    try {
      final path = await _buildPath(filename, useTemp: useTemp);
      final file = File(path);
      if (await file.exists()) {
        return await file.readAsBytes();
      }
      return null;
    } catch (e) {
      _logError('readBytes failed: $e');
      return null;
    }
  }

  Future<bool> exists(String filename, {bool useTemp = false}) async {
    final path = await _buildPath(filename, useTemp: useTemp);
    return await File(path).exists();
  }

  Future<bool> delete(String filename, {bool useTemp = false}) async {
    try {
      final path = await _buildPath(filename, useTemp: useTemp);
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      _logError('delete failed: $e');
      return false;
    }
  }

  /// 清空**本类自己的**临时目录（[namespace] 子目录）
  ///
  /// 只动自己的子目录：临时根目录是全 App 共用的，`listSync() + delete(recursive: true)`
  /// 那种「把根目录整个抹掉」的写法会连带删掉其他插件的缓存，是模板最容易传出去的坑。
  Future<bool> clearTemp() async {
    try {
      final dir = await tempDirectory;
      // 流式遍历而不是 listSync()：同步 IO 会阻塞 UI isolate
      await for (final entry in dir.list(followLinks: false)) {
        await entry.delete(recursive: true);
      }
      return true;
    } catch (e) {
      _logError('clearTemp failed: $e');
      return false;
    }
  }

  /// 本类文件占用（KB，向上取整）；[includeTemp] 为 true 时把临时目录也算进去
  Future<int> getUsage({bool includeTemp = false}) async {
    try {
      final usage = await _getDirSize(await appDirectory);
      if (!includeTemp) return usage;
      return usage + await _getDirSize(await tempDirectory);
    } catch (e) {
      _logError('getUsage failed: $e');
      return 0;
    }
  }

  /// 目录占用（KB，向上取整）
  Future<int> _getDirSize(Directory dir) async {
    var total = 0;
    // 流式遍历而不是 listSync()：后者把整棵树同步走完才返回，文件一多必然掉帧。
    // 逐个 await length() 比一次性铺开成千上万个 stat 慢，但占用统计不在热路径上，
    // 稳定优先。
    await for (final entry in dir.list(recursive: true, followLinks: false)) {
      if (entry is File) {
        total += await entry.length();
      }
    }
    return (total / 1024).ceil();
  }

  void _logError(String msg) {
    Logging.error(msg);
  }
}
