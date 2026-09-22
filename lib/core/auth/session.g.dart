// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 登录态（[User?]）的**可订阅镜像**，真源是 [AuthStorage]。
///
/// 为什么需要这一层，而不是让页面直接读 `authStorage.currentUser`：
/// 401 之后 `AuthInterceptor` 会调 `TokenStore.clearAuth()` —— 它属于 `app_core`，
/// 不认识 Riverpod，也不该认识。所以「凭证被清了」这件事只能由存储对象广播出来
/// （[AuthStorage.userChanges]），再由本类转成 provider 状态，页面与守卫才有得订阅。
///
/// 路由守卫仍然直接读 `authStorage.isLoggedIn`：那是**同步**判断，用它做守卫不会
/// 出现「状态还没 emit、先判成未登录」的空窗；本 provider 管的是 UI。

@ProviderFor(Session)
final sessionProvider = SessionProvider._();

/// 登录态（[User?]）的**可订阅镜像**，真源是 [AuthStorage]。
///
/// 为什么需要这一层，而不是让页面直接读 `authStorage.currentUser`：
/// 401 之后 `AuthInterceptor` 会调 `TokenStore.clearAuth()` —— 它属于 `app_core`，
/// 不认识 Riverpod，也不该认识。所以「凭证被清了」这件事只能由存储对象广播出来
/// （[AuthStorage.userChanges]），再由本类转成 provider 状态，页面与守卫才有得订阅。
///
/// 路由守卫仍然直接读 `authStorage.isLoggedIn`：那是**同步**判断，用它做守卫不会
/// 出现「状态还没 emit、先判成未登录」的空窗；本 provider 管的是 UI。
final class SessionProvider extends $NotifierProvider<Session, User?> {
  /// 登录态（[User?]）的**可订阅镜像**，真源是 [AuthStorage]。
  ///
  /// 为什么需要这一层，而不是让页面直接读 `authStorage.currentUser`：
  /// 401 之后 `AuthInterceptor` 会调 `TokenStore.clearAuth()` —— 它属于 `app_core`，
  /// 不认识 Riverpod，也不该认识。所以「凭证被清了」这件事只能由存储对象广播出来
  /// （[AuthStorage.userChanges]），再由本类转成 provider 状态，页面与守卫才有得订阅。
  ///
  /// 路由守卫仍然直接读 `authStorage.isLoggedIn`：那是**同步**判断，用它做守卫不会
  /// 出现「状态还没 emit、先判成未登录」的空窗；本 provider 管的是 UI。
  SessionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sessionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sessionHash();

  @$internal
  @override
  Session create() => Session();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(User? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<User?>(value),
    );
  }
}

String _$sessionHash() => r'3d57bf5991394a97d4404d2ee65ac68e7ee9ca7e';

/// 登录态（[User?]）的**可订阅镜像**，真源是 [AuthStorage]。
///
/// 为什么需要这一层，而不是让页面直接读 `authStorage.currentUser`：
/// 401 之后 `AuthInterceptor` 会调 `TokenStore.clearAuth()` —— 它属于 `app_core`，
/// 不认识 Riverpod，也不该认识。所以「凭证被清了」这件事只能由存储对象广播出来
/// （[AuthStorage.userChanges]），再由本类转成 provider 状态，页面与守卫才有得订阅。
///
/// 路由守卫仍然直接读 `authStorage.isLoggedIn`：那是**同步**判断，用它做守卫不会
/// 出现「状态还没 emit、先判成未登录」的空窗；本 provider 管的是 UI。

abstract class _$Session extends $Notifier<User?> {
  User? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<User?, User?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<User?, User?>,
              User?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
