// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sample_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// sample 数据层的装配。
///
/// 三者都是无状态服务，所以 `keepAlive`：让它们随页面生灭只会把实例化成本
/// 挪到每次 `ref.read`。换实现（接真实后端、或在测试里塞 fake）一律走
/// `ProviderScope(overrides:)` —— 这就是本栈的注入点。

@ProviderFor(sampleApi)
final sampleApiProvider = SampleApiProvider._();

/// sample 数据层的装配。
///
/// 三者都是无状态服务，所以 `keepAlive`：让它们随页面生灭只会把实例化成本
/// 挪到每次 `ref.read`。换实现（接真实后端、或在测试里塞 fake）一律走
/// `ProviderScope(overrides:)` —— 这就是本栈的注入点。

final class SampleApiProvider
    extends $FunctionalProvider<SampleApi, SampleApi, SampleApi>
    with $Provider<SampleApi> {
  /// sample 数据层的装配。
  ///
  /// 三者都是无状态服务，所以 `keepAlive`：让它们随页面生灭只会把实例化成本
  /// 挪到每次 `ref.read`。换实现（接真实后端、或在测试里塞 fake）一律走
  /// `ProviderScope(overrides:)` —— 这就是本栈的注入点。
  SampleApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sampleApiProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sampleApiHash();

  @$internal
  @override
  $ProviderElement<SampleApi> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SampleApi create(Ref ref) {
    return sampleApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SampleApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SampleApi>(value),
    );
  }
}

String _$sampleApiHash() => r'8e55c069d1cbaea53e760b8a095c419f258a6b77';

@ProviderFor(sampleDao)
final sampleDaoProvider = SampleDaoProvider._();

final class SampleDaoProvider
    extends $FunctionalProvider<SampleDao, SampleDao, SampleDao>
    with $Provider<SampleDao> {
  SampleDaoProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sampleDaoProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sampleDaoHash();

  @$internal
  @override
  $ProviderElement<SampleDao> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SampleDao create(Ref ref) {
    return sampleDao(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SampleDao value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SampleDao>(value),
    );
  }
}

String _$sampleDaoHash() => r'4a3e22ff6e1785236aed26b3214903ba8e209f46';

@ProviderFor(sampleRepository)
final sampleRepositoryProvider = SampleRepositoryProvider._();

final class SampleRepositoryProvider
    extends
        $FunctionalProvider<
          SampleRepository,
          SampleRepository,
          SampleRepository
        >
    with $Provider<SampleRepository> {
  SampleRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sampleRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sampleRepositoryHash();

  @$internal
  @override
  $ProviderElement<SampleRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SampleRepository create(Ref ref) {
    return sampleRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SampleRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SampleRepository>(value),
    );
  }
}

String _$sampleRepositoryHash() => r'd27529f3e2c749388f3137ab32a167d392df3f1f';
