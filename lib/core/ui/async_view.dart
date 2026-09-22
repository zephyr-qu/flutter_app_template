import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 把 [AsyncValue] 渲染成 Widget 的类型安全入口。
///
/// 上游是 Riverpod 的 `AsyncValue`，它用 `hasValue` / `hasError` / `isLoading`
/// 三个正交标志表达状态组合，本组件把它们收敛成与 master（signals）分支一致的
/// 六种情形，页面不必自己写 `if`：
///
/// | AsyncValue | 渲染 |
/// | --- | --- |
/// | 有值 + 后台刷新（`isRefreshing`） | [refreshing]，缺省退回 [data]（屏幕留在旧内容上） |
/// | 有值 + 依赖变化重载（`isReloading`） | [reloading]，缺省退回 [data] |
/// | 有值、稳定 | [data] |
/// | 出错 + 后台刷新 | [refreshing]，缺省退回 [error] |
/// | 出错 + 重载 | [reloading]，缺省退回 [error] |
/// | 出错、稳定 | [error] |
/// | 无值无错（首次加载） | [loading]（整屏 spinner） |
///
/// 两点与 Riverpod 默认行为有关的说明：
/// - **刷新时保留旧值是框架默认**（`AsyncValue.copyWithPrevious`），所以「下拉刷新
///   时列表留在屏幕上、只有首次加载才整屏 loading」这条语义天然成立。
/// - `AsyncValue` 允许「既 `hasValue` 又 `hasError`」（重载失败时旧数据还在），
///   所以**判断顺序不能随便调**：先看刷新 / 重载标志，再看值，最后才是错误。
class AsyncView<T> extends StatelessWidget {
  /// [data] / [loading] / [error] 覆盖三种稳定状态；[refreshing] / [reloading]
  /// 用于「后台更新但屏幕上还留着旧内容」，不传就退回 [data]（旧内容），
  /// 出错时退回 [error]。
  const new({
    required this.state,
    required this.data,
    required this.loading,
    required this.error,
    this.refreshing,
    this.reloading,
    super.key,
  });

  /// 要渲染的状态，通常来自 `ref.watch(xxxProvider)`。
  final AsyncValue<T> state;

  /// 有数据时渲染。
  final Widget Function(T value) data;

  /// 纯加载态（首次加载——此时没有旧数据可留）。
  final Widget Function() loading;

  /// 错误态。
  final Widget Function(Object error, StackTrace stackTrace) error;

  /// 后台刷新（旧数据仍在屏幕上）。缺省时继续走 [data]。
  final Widget Function()? refreshing;

  /// 后台重载。缺省时走 [data]（无旧数据时为 [error]）。
  final Widget Function()? reloading;

  @override
  Widget build(BuildContext context) {
    // 顺序不能改：isRefreshing / isReloading 期间 hasValue 或 hasError 仍为真，
    // 先判它们才能把「后台更新」与稳定态区分开
    if (state.isRefreshing) {
      return refreshing?.call() ??
          (state.hasError ? _error() : data(state.requireValue));
    }
    if (state.isReloading) {
      return reloading?.call() ??
          (state.hasError ? _error() : data(state.requireValue));
    }
    if (state.hasError) return _error();
    if (state.hasValue) return data(state.requireValue);
    return loading();
  }

  Widget _error() => error(state.error!, state.stackTrace ?? StackTrace.empty);
}
