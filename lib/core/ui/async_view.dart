import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 把 [AsyncValue] 渲染成 Widget 的类型安全入口。
///
/// 六种情形的判定顺序、以及「旧值为 null 视同没有数据」这条语义（master 的
/// `runAsync` 此时直接置 `loading` 而不是 `dataRefreshing`），见
/// frontend/state-management.md「渲染状态」。**判断顺序不能随便调**。
///
/// 刷新 / 重载时不传 [refreshing] / [reloading] 就退回 [data]（旧内容），
/// 旧内容不可用时退回 [loading]，出错时退回 [error]。
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

  /// 后台重载。缺省时走 [data]，旧内容不可用时退回 [loading] / [error]。
  final Widget Function()? reloading;

  @override
  Widget build(BuildContext context) {
    // 顺序不能改：刷新 / 重载期间 hasValue 或 hasError 仍为真，先判它们才能把
    // 「后台更新」与稳定态区分开；旧值不可用（null）时退回 loading。
    if (state.isRefreshing) {
      if (state.hasError) return refreshing?.call() ?? _error();
      if (!_hasUsableValue) return loading();
      return refreshing?.call() ?? data(state.requireValue);
    }
    if (state.isReloading) {
      if (state.hasError) return reloading?.call() ?? _error();
      if (!_hasUsableValue) return loading();
      return reloading?.call() ?? data(state.requireValue);
    }
    if (state.hasError) return _error();
    if (state.hasValue) return data(state.requireValue);
    return loading();
  }

  /// `hasValue` 只看「有没有那份记录」，`data(null)` 也算有值；这里要的是
  /// 「屏幕上真的有东西可渲染」，所以额外判一次 null。
  bool get _hasUsableValue => state.hasValue && state.value != null;

  Widget _error() => error(state.error!, state.stackTrace ?? StackTrace.empty);
}
