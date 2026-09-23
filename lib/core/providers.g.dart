// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 应用级基础设施单例的装配。
///
/// 这一层是 master（signals）分支上 `core/core_module.dart` 的 `@module` 注解的替代：
/// Riverpod 里「单例」就是一个 `keepAlive` 的 provider，不需要额外的注册表，
/// 也就不需要 `lib/di/`（见 BRANCH.md）。
///
/// **不得**在这里读取 `dotenv`：`NetworkConfig` 只有 `NetworkModule` 一个来源
/// （约定见 backend/network-guidelines.md）。
/// 用户偏好 / 令牌存储的底层存储。
///
/// **必须**由 `bootstrap()` 用 `overrides` 注入（`prefsProvider.overrideWithValue`）：
/// `SharedPreferences.getInstance()` 是异步的，而它的消费者
/// （`UserPreferences` / `AuthStorage`）都是同步构造的。用 `FutureProvider`
/// 会把 `AsyncValue` 一路传染到页面，等于让「启动期解析一次」变成「处处异步」。
///
/// 直接 `ref.watch` 它会抛异常——这是有意的：漏了 override 应该立刻炸，
/// 而不是拿到一个未初始化的实例。

@ProviderFor(prefs)
final prefsProvider = PrefsProvider._();

/// 应用级基础设施单例的装配。
///
/// 这一层是 master（signals）分支上 `core/core_module.dart` 的 `@module` 注解的替代：
/// Riverpod 里「单例」就是一个 `keepAlive` 的 provider，不需要额外的注册表，
/// 也就不需要 `lib/di/`（见 BRANCH.md）。
///
/// **不得**在这里读取 `dotenv`：`NetworkConfig` 只有 `NetworkModule` 一个来源
/// （约定见 backend/network-guidelines.md）。
/// 用户偏好 / 令牌存储的底层存储。
///
/// **必须**由 `bootstrap()` 用 `overrides` 注入（`prefsProvider.overrideWithValue`）：
/// `SharedPreferences.getInstance()` 是异步的，而它的消费者
/// （`UserPreferences` / `AuthStorage`）都是同步构造的。用 `FutureProvider`
/// 会把 `AsyncValue` 一路传染到页面，等于让「启动期解析一次」变成「处处异步」。
///
/// 直接 `ref.watch` 它会抛异常——这是有意的：漏了 override 应该立刻炸，
/// 而不是拿到一个未初始化的实例。

final class PrefsProvider
    extends
        $FunctionalProvider<
          SharedPreferences,
          SharedPreferences,
          SharedPreferences
        >
    with $Provider<SharedPreferences> {
  /// 应用级基础设施单例的装配。
  ///
  /// 这一层是 master（signals）分支上 `core/core_module.dart` 的 `@module` 注解的替代：
  /// Riverpod 里「单例」就是一个 `keepAlive` 的 provider，不需要额外的注册表，
  /// 也就不需要 `lib/di/`（见 BRANCH.md）。
  ///
  /// **不得**在这里读取 `dotenv`：`NetworkConfig` 只有 `NetworkModule` 一个来源
  /// （约定见 backend/network-guidelines.md）。
  /// 用户偏好 / 令牌存储的底层存储。
  ///
  /// **必须**由 `bootstrap()` 用 `overrides` 注入（`prefsProvider.overrideWithValue`）：
  /// `SharedPreferences.getInstance()` 是异步的，而它的消费者
  /// （`UserPreferences` / `AuthStorage`）都是同步构造的。用 `FutureProvider`
  /// 会把 `AsyncValue` 一路传染到页面，等于让「启动期解析一次」变成「处处异步」。
  ///
  /// 直接 `ref.watch` 它会抛异常——这是有意的：漏了 override 应该立刻炸，
  /// 而不是拿到一个未初始化的实例。
  PrefsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'prefsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$prefsHash();

  @$internal
  @override
  $ProviderElement<SharedPreferences> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SharedPreferences create(Ref ref) {
    return prefs(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SharedPreferences value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SharedPreferences>(value),
    );
  }
}

String _$prefsHash() => r'7bba4ee6a360f9e2d776ce6b4b5a6d95f802a0c8';

/// 敏感数据（访问令牌）的平台安全存储。
///
/// v11 的默认配置已经是安全的（Android: KeyStore 包装的 AES-GCM，API 23+；
/// iOS/macOS: Keychain），无需额外传 options。

@ProviderFor(secureStorage)
final secureStorageProvider = SecureStorageProvider._();

/// 敏感数据（访问令牌）的平台安全存储。
///
/// v11 的默认配置已经是安全的（Android: KeyStore 包装的 AES-GCM，API 23+；
/// iOS/macOS: Keychain），无需额外传 options。

final class SecureStorageProvider
    extends
        $FunctionalProvider<
          FlutterSecureStorage,
          FlutterSecureStorage,
          FlutterSecureStorage
        >
    with $Provider<FlutterSecureStorage> {
  /// 敏感数据（访问令牌）的平台安全存储。
  ///
  /// v11 的默认配置已经是安全的（Android: KeyStore 包装的 AES-GCM，API 23+；
  /// iOS/macOS: Keychain），无需额外传 options。
  SecureStorageProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'secureStorageProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$secureStorageHash();

  @$internal
  @override
  $ProviderElement<FlutterSecureStorage> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  FlutterSecureStorage create(Ref ref) {
    return secureStorage(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FlutterSecureStorage value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FlutterSecureStorage>(value),
    );
  }
}

String _$secureStorageHash() => r'0cd1b80f91784467390034386f925a0be155bfbd';

@ProviderFor(database)
final databaseProvider = DatabaseProvider._();

final class DatabaseProvider
    extends $FunctionalProvider<AppDatabase, AppDatabase, AppDatabase>
    with $Provider<AppDatabase> {
  DatabaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'databaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$databaseHash();

  @$internal
  @override
  $ProviderElement<AppDatabase> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppDatabase create(Ref ref) {
    return database(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppDatabase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppDatabase>(value),
    );
  }
}

String _$databaseHash() => r'd6e05638b723b0524e474cecb5226cbaac2e507a';

/// [FileStorage]（`core/data/storage/`）是纯 Dart 类，不带任何装配注解（本项目用
/// provider 装配，没有 injectable），所以在这里显式建成 provider。

@ProviderFor(fileStorage)
final fileStorageProvider = FileStorageProvider._();

/// [FileStorage]（`core/data/storage/`）是纯 Dart 类，不带任何装配注解（本项目用
/// provider 装配，没有 injectable），所以在这里显式建成 provider。

final class FileStorageProvider
    extends $FunctionalProvider<FileStorage, FileStorage, FileStorage>
    with $Provider<FileStorage> {
  /// [FileStorage]（`core/data/storage/`）是纯 Dart 类，不带任何装配注解（本项目用
  /// provider 装配，没有 injectable），所以在这里显式建成 provider。
  FileStorageProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'fileStorageProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$fileStorageHash();

  @$internal
  @override
  $ProviderElement<FileStorage> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  FileStorage create(Ref ref) {
    return fileStorage(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FileStorage value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FileStorage>(value),
    );
  }
}

String _$fileStorageHash() => r'ed75a44f7bb651a3292256a720a17f0a20d9ed71';

/// 用户偏好的持久化层（同步读）。
///
/// 页面要订阅的是它的**快照** `appSettingsProvider`，不是这一层：
/// 每次偏好变更都重建存储对象没有意义（见 core/config/app_settings.dart）。

@ProviderFor(userPreferences)
final userPreferencesProvider = UserPreferencesProvider._();

/// 用户偏好的持久化层（同步读）。
///
/// 页面要订阅的是它的**快照** `appSettingsProvider`，不是这一层：
/// 每次偏好变更都重建存储对象没有意义（见 core/config/app_settings.dart）。

final class UserPreferencesProvider
    extends
        $FunctionalProvider<UserPreferences, UserPreferences, UserPreferences>
    with $Provider<UserPreferences> {
  /// 用户偏好的持久化层（同步读）。
  ///
  /// 页面要订阅的是它的**快照** `appSettingsProvider`，不是这一层：
  /// 每次偏好变更都重建存储对象没有意义（见 core/config/app_settings.dart）。
  UserPreferencesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'userPreferencesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$userPreferencesHash();

  @$internal
  @override
  $ProviderElement<UserPreferences> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  UserPreferences create(Ref ref) {
    return userPreferences(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UserPreferences value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UserPreferences>(value),
    );
  }
}

String _$userPreferencesHash() => r'f6398449cab22aa2003fdf229ab484af5751e799';

/// 认证存储：实现 `core/data/network/token_store.dart` 的 `TokenStore`，令牌与用户都从这里进出。
///
/// 注意它与「登录态 provider」的分工：**真源在这里**（同步可读，路由守卫直接用），
/// 可订阅的镜像在 `core/auth/session.dart`。

@ProviderFor(authStorage)
final authStorageProvider = AuthStorageProvider._();

/// 认证存储：实现 `core/data/network/token_store.dart` 的 `TokenStore`，令牌与用户都从这里进出。
///
/// 注意它与「登录态 provider」的分工：**真源在这里**（同步可读，路由守卫直接用），
/// 可订阅的镜像在 `core/auth/session.dart`。

final class AuthStorageProvider
    extends $FunctionalProvider<AuthStorage, AuthStorage, AuthStorage>
    with $Provider<AuthStorage> {
  /// 认证存储：实现 `core/data/network/token_store.dart` 的 `TokenStore`，令牌与用户都从这里进出。
  ///
  /// 注意它与「登录态 provider」的分工：**真源在这里**（同步可读，路由守卫直接用），
  /// 可订阅的镜像在 `core/auth/session.dart`。
  AuthStorageProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'authStorageProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$authStorageHash();

  @$internal
  @override
  $ProviderElement<AuthStorage> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AuthStorage create(Ref ref) {
    return authStorage(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AuthStorage value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AuthStorage>(value),
    );
  }
}

String _$authStorageHash() => r'63b681d7e3e7c800186f404106939ec809e27958';
