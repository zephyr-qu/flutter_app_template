import 'package:my_app/core/base/failure.dart';
import 'package:my_app/core/base/result.dart';
import 'package:my_app/features/sample/data/models/sample_item.dart';
import 'package:my_app/features/sample/data/sample_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'sample_list_notifier.g.dart';

/// 示例列表的状态。
///
/// 只做一件事：把仓库的 `Result` 翻译成 `AsyncValue`。首屏加载写成 `build()`，
/// 于是刷新与重试退回 Riverpod 原语（`ref.refresh` / `ref.invalidate`），
/// 不必自己维护 request token —— 竞态与「刷新时保留旧值」都是框架内建的。
///
/// 失败时抛出 [Failure] 本身（它 `implements Exception`）：`AsyncValue.error`
/// 允许携带任意对象，抛原样才能让 `AsyncView` / `ErrorText` 拿到错误码翻译文案。
@riverpod
class SampleListNotifier extends _$SampleListNotifier {
  @override
  Future<List<SampleItem>> build() async {
    final result = await ref.watch(sampleRepositoryProvider).getItems();

    return switch (result) {
      Ok<List<SampleItem>, Failure>(:final data) => data,
      Err<List<SampleItem>, Failure>(:final error) => throw error,
    };
  }
}
