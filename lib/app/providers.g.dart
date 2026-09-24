// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 应用组合根（FSD 的 app 层）的装配。
/// 应用路由。
///
/// `keepAlive` 是硬要求：重建路由器会丢掉整个导航栈。
///
/// 初始 location 在这里指到启动页：`routeInfoProvider` 是 memoized 的，**必须在
/// `config()` 之前设**（`app.dart` 的 build 就会调它）。取舍见
/// frontend/directory-structure.md「应用层」。

@ProviderFor(router)
final routerProvider = RouterProvider._();

/// 应用组合根（FSD 的 app 层）的装配。
/// 应用路由。
///
/// `keepAlive` 是硬要求：重建路由器会丢掉整个导航栈。
///
/// 初始 location 在这里指到启动页：`routeInfoProvider` 是 memoized 的，**必须在
/// `config()` 之前设**（`app.dart` 的 build 就会调它）。取舍见
/// frontend/directory-structure.md「应用层」。

final class RouterProvider
    extends $FunctionalProvider<AppRouter, AppRouter, AppRouter>
    with $Provider<AppRouter> {
  /// 应用组合根（FSD 的 app 层）的装配。
  /// 应用路由。
  ///
  /// `keepAlive` 是硬要求：重建路由器会丢掉整个导航栈。
  ///
  /// 初始 location 在这里指到启动页：`routeInfoProvider` 是 memoized 的，**必须在
  /// `config()` 之前设**（`app.dart` 的 build 就会调它）。取舍见
  /// frontend/directory-structure.md「应用层」。
  RouterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'routerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$routerHash();

  @$internal
  @override
  $ProviderElement<AppRouter> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppRouter create(Ref ref) {
    return router(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppRouter value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppRouter>(value),
    );
  }
}

String _$routerHash() => r'e41e3e21ff8c64f964b13f8139d25a73e9f408fb';
