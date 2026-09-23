// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// auth 数据层的装配：Retrofit 客户端与 `AuthRepository` 的实现绑定。
///
/// 两者都是无状态服务，所以 `keepAlive`：让它们随页面生灭只会把实例化成本
/// 挪到每次 `ref.read`，换不来任何隔离收益。替换实现一律走
/// `ProviderScope(overrides:)`。
///
/// 这里是 master 分支 `auth_module.dart`（`@module` / `@LazySingleton`）的替代。

@ProviderFor(authApi)
final authApiProvider = AuthApiProvider._();

/// auth 数据层的装配：Retrofit 客户端与 `AuthRepository` 的实现绑定。
///
/// 两者都是无状态服务，所以 `keepAlive`：让它们随页面生灭只会把实例化成本
/// 挪到每次 `ref.read`，换不来任何隔离收益。替换实现一律走
/// `ProviderScope(overrides:)`。
///
/// 这里是 master 分支 `auth_module.dart`（`@module` / `@LazySingleton`）的替代。

final class AuthApiProvider
    extends $FunctionalProvider<AuthApi, AuthApi, AuthApi>
    with $Provider<AuthApi> {
  /// auth 数据层的装配：Retrofit 客户端与 `AuthRepository` 的实现绑定。
  ///
  /// 两者都是无状态服务，所以 `keepAlive`：让它们随页面生灭只会把实例化成本
  /// 挪到每次 `ref.read`，换不来任何隔离收益。替换实现一律走
  /// `ProviderScope(overrides:)`。
  ///
  /// 这里是 master 分支 `auth_module.dart`（`@module` / `@LazySingleton`）的替代。
  AuthApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'authApiProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$authApiHash();

  @$internal
  @override
  $ProviderElement<AuthApi> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AuthApi create(Ref ref) {
    return authApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AuthApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AuthApi>(value),
    );
  }
}

String _$authApiHash() => r'7f8f3295d155d64a23d89a39198a1a3354c334e6';

@ProviderFor(authRepository)
final authRepositoryProvider = AuthRepositoryProvider._();

final class AuthRepositoryProvider
    extends $FunctionalProvider<AuthRepository, AuthRepository, AuthRepository>
    with $Provider<AuthRepository> {
  AuthRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'authRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$authRepositoryHash();

  @$internal
  @override
  $ProviderElement<AuthRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AuthRepository create(Ref ref) {
    return authRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AuthRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AuthRepository>(value),
    );
  }
}

String _$authRepositoryHash() => r'0b08e12291c033607a2c04bc2f7897bc3df49cda';
