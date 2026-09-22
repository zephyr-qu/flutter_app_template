// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 应用组合根（FSD 的 app 层）的装配。
///
/// 这两个对象都必须是**长生命周期**的：一个是导航栈本身，一个是守卫的触发器。
/// 应用路由。
///
/// `keepAlive` 是硬要求：重建路由器会丢掉整个导航栈（master 用 `useMemoized`
/// 表达同一件事）。它的依赖 `authStorageProvider` 是 keepAlive 单例，
/// 所以正常情况下不会被重建。

@ProviderFor(router)
final routerProvider = RouterProvider._();

/// 应用组合根（FSD 的 app 层）的装配。
///
/// 这两个对象都必须是**长生命周期**的：一个是导航栈本身，一个是守卫的触发器。
/// 应用路由。
///
/// `keepAlive` 是硬要求：重建路由器会丢掉整个导航栈（master 用 `useMemoized`
/// 表达同一件事）。它的依赖 `authStorageProvider` 是 keepAlive 单例，
/// 所以正常情况下不会被重建。

final class RouterProvider
    extends $FunctionalProvider<AppRouter, AppRouter, AppRouter>
    with $Provider<AppRouter> {
  /// 应用组合根（FSD 的 app 层）的装配。
  ///
  /// 这两个对象都必须是**长生命周期**的：一个是导航栈本身，一个是守卫的触发器。
  /// 应用路由。
  ///
  /// `keepAlive` 是硬要求：重建路由器会丢掉整个导航栈（master 用 `useMemoized`
  /// 表达同一件事）。它的依赖 `authStorageProvider` 是 keepAlive 单例，
  /// 所以正常情况下不会被重建。
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

String _$routerHash() => r'85d61b924a8f5114dba7b0ce458428c585b93407';

/// 登录态 → auto_route 的重评估触发器（见 auth_reevaluate.dart）

@ProviderFor(authReevaluate)
final authReevaluateProvider = AuthReevaluateProvider._();

/// 登录态 → auto_route 的重评估触发器（见 auth_reevaluate.dart）

final class AuthReevaluateProvider
    extends
        $FunctionalProvider<
          AuthReevaluateListenable,
          AuthReevaluateListenable,
          AuthReevaluateListenable
        >
    with $Provider<AuthReevaluateListenable> {
  /// 登录态 → auto_route 的重评估触发器（见 auth_reevaluate.dart）
  AuthReevaluateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'authReevaluateProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$authReevaluateHash();

  @$internal
  @override
  $ProviderElement<AuthReevaluateListenable> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AuthReevaluateListenable create(Ref ref) {
    return authReevaluate(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AuthReevaluateListenable value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AuthReevaluateListenable>(value),
    );
  }
}

String _$authReevaluateHash() => r'ae1ea4080f8e46623a9f1ec1577a8c1924bc0145';
