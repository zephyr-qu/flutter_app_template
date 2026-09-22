import 'package:flutter/material.dart';
import 'package:signals_flutter/signals_flutter.dart';

/// 把 [AsyncState] 渲染成 Widget 的类型安全入口。
///
/// 取代 `AsyncState.map`（它的回调签名运行期才校验，写错整页红屏）；
/// 用法与原因见 frontend/state-management.md「渲染状态」。
class AsyncView<T> extends StatelessWidget {
  /// [data] / [loading] / [error] 覆盖三种稳定状态；[refreshing] /
  /// [reloading] 用于「后台更新但屏幕上还留着旧内容」，不传就退回
  /// [data]（旧内容），出错时退回 [error]。
  const new({
    required this.state,
    required this.data,
    required this.loading,
    required this.error,
    this.refreshing,
    this.reloading,
    super.key,
  });

  /// 要渲染的状态，通常来自 `useSignalValue(vm.xxx)`。
  final AsyncState<T> state;

  /// 有数据时渲染。
  final Widget Function(T value) data;

  /// 纯加载态（首次加载、或出错后重试——此时没有旧数据可留）。
  final Widget Function() loading;

  /// 错误态。[StackTrace] 由 [AsyncState] 携带，可直接上报。
  final Widget Function(Object error, StackTrace stackTrace) error;

  /// 后台刷新（旧数据仍在屏幕上）。缺省时继续走 [data]。
  final Widget Function()? refreshing;

  /// 后台重载。缺省时走 [data]（无旧数据时为 [error]）。
  final Widget Function()? reloading;

  @override
  Widget build(BuildContext context) {
    // 顺序不能改：AsyncData* 同时实现了 AsyncLoading，压在它前面会被 loading 吞掉
    return switch (state) {
      AsyncDataRefreshing<T>(:final value) => refreshing?.call() ?? data(value),
      AsyncDataReloading<T>(:final value) => reloading?.call() ?? data(value),
      AsyncData<T>(:final value) => data(value),
      AsyncErrorRefreshing<T>(error: final e, stackTrace: final st) =>
        refreshing?.call() ?? error(e, st),
      AsyncErrorReloading<T>(error: final e, stackTrace: final st) =>
        reloading?.call() ?? error(e, st),
      AsyncError<T>(error: final e, stackTrace: final st) => error(e, st),
      AsyncLoading<T>() => loading(),
    };
  }
}
