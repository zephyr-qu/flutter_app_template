// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sample_list_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 示例列表的状态。
///
/// 只做一件事：把仓库的 `Result` 翻译成 `AsyncValue`。首屏加载写成 `build()`，
/// 于是刷新与重试退回 Riverpod 原语（`ref.refresh` / `ref.invalidate`），
/// 不必自己维护 request token —— 竞态与「刷新时保留旧值」都是框架内建的。
///
/// 失败时抛出 [Failure] 本身（它 `implements Exception`）：`AsyncValue.error`
/// 允许携带任意对象，抛原样才能让 `AsyncView` / `ErrorText` 拿到错误码翻译文案。

@ProviderFor(SampleListNotifier)
final sampleListProvider = SampleListNotifierProvider._();

/// 示例列表的状态。
///
/// 只做一件事：把仓库的 `Result` 翻译成 `AsyncValue`。首屏加载写成 `build()`，
/// 于是刷新与重试退回 Riverpod 原语（`ref.refresh` / `ref.invalidate`），
/// 不必自己维护 request token —— 竞态与「刷新时保留旧值」都是框架内建的。
///
/// 失败时抛出 [Failure] 本身（它 `implements Exception`）：`AsyncValue.error`
/// 允许携带任意对象，抛原样才能让 `AsyncView` / `ErrorText` 拿到错误码翻译文案。
final class SampleListNotifierProvider
    extends $AsyncNotifierProvider<SampleListNotifier, List<SampleItem>> {
  /// 示例列表的状态。
  ///
  /// 只做一件事：把仓库的 `Result` 翻译成 `AsyncValue`。首屏加载写成 `build()`，
  /// 于是刷新与重试退回 Riverpod 原语（`ref.refresh` / `ref.invalidate`），
  /// 不必自己维护 request token —— 竞态与「刷新时保留旧值」都是框架内建的。
  ///
  /// 失败时抛出 [Failure] 本身（它 `implements Exception`）：`AsyncValue.error`
  /// 允许携带任意对象，抛原样才能让 `AsyncView` / `ErrorText` 拿到错误码翻译文案。
  SampleListNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sampleListProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sampleListNotifierHash();

  @$internal
  @override
  SampleListNotifier create() => SampleListNotifier();
}

String _$sampleListNotifierHash() =>
    r'97133b67b2ac6570fdc278c6e2bd95513864fe9a';

/// 示例列表的状态。
///
/// 只做一件事：把仓库的 `Result` 翻译成 `AsyncValue`。首屏加载写成 `build()`，
/// 于是刷新与重试退回 Riverpod 原语（`ref.refresh` / `ref.invalidate`），
/// 不必自己维护 request token —— 竞态与「刷新时保留旧值」都是框架内建的。
///
/// 失败时抛出 [Failure] 本身（它 `implements Exception`）：`AsyncValue.error`
/// 允许携带任意对象，抛原样才能让 `AsyncView` / `ErrorText` 拿到错误码翻译文案。

abstract class _$SampleListNotifier extends $AsyncNotifier<List<SampleItem>> {
  FutureOr<List<SampleItem>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<List<SampleItem>>, List<SampleItem>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<SampleItem>>, List<SampleItem>>,
              AsyncValue<List<SampleItem>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
