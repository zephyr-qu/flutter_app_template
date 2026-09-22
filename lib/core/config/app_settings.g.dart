// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_settings.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 偏好的可订阅状态：初值读一次存储，之后由本类负责通知与落盘。
///
/// **写入顺序是「先改内存再落盘」**：UI 立刻响应，落盘失败只记日志
/// （`SharedPreferences` 的写失败不影响本次会话，与 master 的行为一致）。

@ProviderFor(AppSettingsNotifier)
final appSettingsProvider = AppSettingsNotifierProvider._();

/// 偏好的可订阅状态：初值读一次存储，之后由本类负责通知与落盘。
///
/// **写入顺序是「先改内存再落盘」**：UI 立刻响应，落盘失败只记日志
/// （`SharedPreferences` 的写失败不影响本次会话，与 master 的行为一致）。
final class AppSettingsNotifierProvider
    extends $NotifierProvider<AppSettingsNotifier, AppSettings> {
  /// 偏好的可订阅状态：初值读一次存储，之后由本类负责通知与落盘。
  ///
  /// **写入顺序是「先改内存再落盘」**：UI 立刻响应，落盘失败只记日志
  /// （`SharedPreferences` 的写失败不影响本次会话，与 master 的行为一致）。
  AppSettingsNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appSettingsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appSettingsNotifierHash();

  @$internal
  @override
  AppSettingsNotifier create() => AppSettingsNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppSettings value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppSettings>(value),
    );
  }
}

String _$appSettingsNotifierHash() =>
    r'c83fd8226d55d238b491365986bbbc8b096140ab';

/// 偏好的可订阅状态：初值读一次存储，之后由本类负责通知与落盘。
///
/// **写入顺序是「先改内存再落盘」**：UI 立刻响应，落盘失败只记日志
/// （`SharedPreferences` 的写失败不影响本次会话，与 master 的行为一致）。

abstract class _$AppSettingsNotifier extends $Notifier<AppSettings> {
  AppSettings build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AppSettings, AppSettings>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AppSettings, AppSettings>,
              AppSettings,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
