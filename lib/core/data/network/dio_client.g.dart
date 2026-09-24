// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dio_client.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Dio 与 NetworkConfig 的装配（master 分支上这里是 `@module` + `@lazySingleton`）。
///
/// 拦截器栈本身在 `dio_factory.dart` 的 [createDio] 里（与状态管理无关）；
/// 本层只做三件本应用专属的事：
/// 1. 从 `dotenv` 取配置（环境变量在 `bootstrap()` 之后才加载）
/// 2. 读 `UserPreferences` 决定要不要挂调试日志
/// 3. 注册本应用专属的 Mock 规则
/// 全项目唯一读 `dotenv` 的地方。
///
/// `keepAlive` = 只算一次：`NetworkConfig` 是「配置只有一个来源」这条约定的载体
/// （见 backend/network-guidelines.md「配置：dotenv 只读一次」）。

@ProviderFor(networkConfig)
final networkConfigProvider = NetworkConfigProvider._();

/// Dio 与 NetworkConfig 的装配（master 分支上这里是 `@module` + `@lazySingleton`）。
///
/// 拦截器栈本身在 `dio_factory.dart` 的 [createDio] 里（与状态管理无关）；
/// 本层只做三件本应用专属的事：
/// 1. 从 `dotenv` 取配置（环境变量在 `bootstrap()` 之后才加载）
/// 2. 读 `UserPreferences` 决定要不要挂调试日志
/// 3. 注册本应用专属的 Mock 规则
/// 全项目唯一读 `dotenv` 的地方。
///
/// `keepAlive` = 只算一次：`NetworkConfig` 是「配置只有一个来源」这条约定的载体
/// （见 backend/network-guidelines.md「配置：dotenv 只读一次」）。

final class NetworkConfigProvider
    extends $FunctionalProvider<NetworkConfig, NetworkConfig, NetworkConfig>
    with $Provider<NetworkConfig> {
  /// Dio 与 NetworkConfig 的装配（master 分支上这里是 `@module` + `@lazySingleton`）。
  ///
  /// 拦截器栈本身在 `dio_factory.dart` 的 [createDio] 里（与状态管理无关）；
  /// 本层只做三件本应用专属的事：
  /// 1. 从 `dotenv` 取配置（环境变量在 `bootstrap()` 之后才加载）
  /// 2. 读 `UserPreferences` 决定要不要挂调试日志
  /// 3. 注册本应用专属的 Mock 规则
  /// 全项目唯一读 `dotenv` 的地方。
  ///
  /// `keepAlive` = 只算一次：`NetworkConfig` 是「配置只有一个来源」这条约定的载体
  /// （见 backend/network-guidelines.md「配置：dotenv 只读一次」）。
  NetworkConfigProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'networkConfigProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$networkConfigHash();

  @$internal
  @override
  $ProviderElement<NetworkConfig> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  NetworkConfig create(Ref ref) {
    return networkConfig(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NetworkConfig value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NetworkConfig>(value),
    );
  }
}

String _$networkConfigHash() => r'787e658f26eff8400331e6165f3f634eca85deea';

/// 整个 App 共用一个 Dio（**必须单例**，理由见 backend/network-guidelines.md）。
///
/// 为什么读的是 `userPreferencesProvider` 而不是 `appSettingsProvider`：
/// 后者一变本 provider 就会被重建，而「Dio 必须单例」优先于「开关立刻生效」——
/// 重建会丢掉在飞请求、重放状态与 mock 注册。所以调试开关与 master 行为一致：
/// **下次创建 Dio（即重启 App）才生效**。

@ProviderFor(dio)
final dioProvider = DioProvider._();

/// 整个 App 共用一个 Dio（**必须单例**，理由见 backend/network-guidelines.md）。
///
/// 为什么读的是 `userPreferencesProvider` 而不是 `appSettingsProvider`：
/// 后者一变本 provider 就会被重建，而「Dio 必须单例」优先于「开关立刻生效」——
/// 重建会丢掉在飞请求、重放状态与 mock 注册。所以调试开关与 master 行为一致：
/// **下次创建 Dio（即重启 App）才生效**。

final class DioProvider extends $FunctionalProvider<Dio, Dio, Dio>
    with $Provider<Dio> {
  /// 整个 App 共用一个 Dio（**必须单例**，理由见 backend/network-guidelines.md）。
  ///
  /// 为什么读的是 `userPreferencesProvider` 而不是 `appSettingsProvider`：
  /// 后者一变本 provider 就会被重建，而「Dio 必须单例」优先于「开关立刻生效」——
  /// 重建会丢掉在飞请求、重放状态与 mock 注册。所以调试开关与 master 行为一致：
  /// **下次创建 Dio（即重启 App）才生效**。
  DioProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dioProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dioHash();

  @$internal
  @override
  $ProviderElement<Dio> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Dio create(Ref ref) {
    return dio(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Dio value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Dio>(value),
    );
  }
}

String _$dioHash() => r'e999e68f83998a30ee6ece96b67ab1677be4881b';
