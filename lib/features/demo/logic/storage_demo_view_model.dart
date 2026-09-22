import 'package:app_core/data/storage/file_storage.dart';
import 'package:app_core/logging/logging.dart';
import 'package:injectable/injectable.dart';
import 'package:my_app/features/article/data/article_dao.dart';
import 'package:signals_flutter/signals_flutter.dart';

/// 本地存储示例的 ViewModel：演示 `FileStorage`（core）与 `ArticleDao`
/// （article 的 data 层，演示了跨 feature 共享 data 层）。
///
/// 信号私有持有、以 [ReadonlySignal] 对外暴露：UI 只能订阅，写入必须走方法。
@injectable
class StorageDemoViewModel {
  new(this._files, this._articleDao);
  static const String noteFileName = 'demo_note.txt';
  static const String tempFileName = 'demo_temp.txt';

  final FileStorage _files;
  final ArticleDao _articleDao;

  // ========== 信号（私有可变，只有本类能写）==========

  /// 输入框内容
  final FlutterSignal<String> _note = signal(
    '',
    options: const SignalOptions<String>(name: 'storageDemo.note'),
  );

  /// 应用目录里读到的内容；null 表示文件不存在
  final FlutterSignal<String?> _savedContent = signal<String?>(
    null,
    options: const SignalOptions<String?>(name: 'storageDemo.savedContent'),
  );

  /// 应用目录 + 临时目录的占用（KB）
  final FlutterSignal<int> _usageKb = signal(
    0,
    options: const SignalOptions<int>(name: 'storageDemo.usageKb'),
  );

  /// 数据库里缓存的文章数量
  final FlutterSignal<int> _cachedCount = signal(
    0,
    options: const SignalOptions<int>(name: 'storageDemo.cachedCount'),
  );

  /// 最近一次操作是否失败，页面据此提示
  final FlutterSignal<bool> _lastActionFailed = signal(
    false,
    options: const SignalOptions<bool>(name: 'storageDemo.lastActionFailed'),
  );

  // ========== 对外只读视图（UI 用 useSignalValue 订阅）==========

  /// 输入框内容；UI 只读，写入走 [updateNote]
  ReadonlySignal<String> get note => _note;

  /// 应用目录里读到的内容；UI 只读，由 [refresh] 更新
  ReadonlySignal<String?> get savedContent => _savedContent;

  /// 存储占用（KB）；UI 只读，由 [refresh] 更新
  ReadonlySignal<int> get usageKb => _usageKb;

  /// 数据库缓存的文章数量；UI 只读，由 [refresh] 更新
  ReadonlySignal<int> get cachedCount => _cachedCount;

  /// 最近一次操作是否失败；UI 只读，由 [_run] 更新
  ReadonlySignal<bool> get lastActionFailed => _lastActionFailed;

  // ========== 方法 ==========

  /// 读取当前状态：文件内容、占用空间、缓存条数（三个值用 `batch` 一次写入，
  /// 见 frontend/state-management.md）。
  Future<void> refresh() async {
    final content = await _files.readString(noteFileName);
    final usage = await _files.getUsage(includeTemp: true);
    final count = (await _articleDao.getCachedArticles()).length;

    batch(() {
      _savedContent.value = content;
      _usageKb.value = usage;
      _cachedCount.value = count;
    });
  }

  // 写入必须走方法、不开 setter：信号私有持有，页面只订阅
  // （frontend/state-management.md「信号」）
  // ignore: use_setters_to_change_properties
  void updateNote(String value) => _note.value = value;

  /// 保存到应用目录，同时在临时目录留一份（演示 `useTemp`）
  Future<void> saveNote() => _run(() async {
    final saved = await _files.saveString(noteFileName, _note.value);
    if (!saved) return false;
    return await _files.saveString(tempFileName, _note.value, useTemp: true);
  });

  Future<void> deleteNote() => _run(() async {
    await _files.delete(noteFileName);
    await _files.delete(tempFileName, useTemp: true);
    return true;
  });

  Future<void> clearTemp() => _run(_files.clearTemp);

  Future<void> seedCache() => _run(() async {
    await _articleDao.seed();
    return true;
  });

  Future<void> clearCache() => _run(() async {
    await _articleDao.clearAll();
    return true;
  });

  /// 统一处理「执行 → 记录结果 → 刷新状态」
  Future<void> _run(Future<bool> Function() action) async {
    _lastActionFailed.value = false;
    try {
      if (!await action()) _lastActionFailed.value = true;
    } catch (e) {
      Logging.warning('存储示例操作失败: $e');
      _lastActionFailed.value = true;
    }
    await refresh();
  }
}
