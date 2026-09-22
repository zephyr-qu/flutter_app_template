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

/// [FileStorage] 来自 `app_core`，包内不带任何装配注解（包不依赖状态管理），
/// 所以在这里显式建成 provider。

@ProviderFor(fileStorage)
final fileStorageProvider = FileStorageProvider._();

/// [FileStorage] 来自 `app_core`，包内不带任何装配注解（包不依赖状态管理），
/// 所以在这里显式建成 provider。

final class FileStorageProvider
    extends $FunctionalProvider<FileStorage, FileStorage, FileStorage>
    with $Provider<FileStorage> {
  /// [FileStorage] 来自 `app_core`，包内不带任何装配注解（包不依赖状态管理），
  /// 所以在这里显式建成 provider。
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
