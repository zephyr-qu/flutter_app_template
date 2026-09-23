// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'login_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 登录表单的状态与动作。
///
/// 默认 `autoDispose`：页面离开即释放，表单内容不跨页面残留 —— 与 master
/// 「`factory` 注册的 ViewModel、每页一个新实例」是同一生命周期。
///
/// 登录成功后**不在这里写登录态**：`AuthService.login` 会把令牌与用户写进
/// `AuthStorage`，UI 侧再经 `Session`（core/auth/session.dart）沿
/// `userChanges` 回流。一处通知比两处各写一次更不容易走岔。

@ProviderFor(LoginNotifier)
final loginProvider = LoginNotifierProvider._();

/// 登录表单的状态与动作。
///
/// 默认 `autoDispose`：页面离开即释放，表单内容不跨页面残留 —— 与 master
/// 「`factory` 注册的 ViewModel、每页一个新实例」是同一生命周期。
///
/// 登录成功后**不在这里写登录态**：`AuthService.login` 会把令牌与用户写进
/// `AuthStorage`，UI 侧再经 `Session`（core/auth/session.dart）沿
/// `userChanges` 回流。一处通知比两处各写一次更不容易走岔。
final class LoginNotifierProvider
    extends $NotifierProvider<LoginNotifier, LoginState> {
  /// 登录表单的状态与动作。
  ///
  /// 默认 `autoDispose`：页面离开即释放，表单内容不跨页面残留 —— 与 master
  /// 「`factory` 注册的 ViewModel、每页一个新实例」是同一生命周期。
  ///
  /// 登录成功后**不在这里写登录态**：`AuthService.login` 会把令牌与用户写进
  /// `AuthStorage`，UI 侧再经 `Session`（core/auth/session.dart）沿
  /// `userChanges` 回流。一处通知比两处各写一次更不容易走岔。
  LoginNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'loginProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$loginNotifierHash();

  @$internal
  @override
  LoginNotifier create() => LoginNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LoginState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LoginState>(value),
    );
  }
}

String _$loginNotifierHash() => r'e5a76e049c34b5b0800cb63c74381b930ac378fb';

/// 登录表单的状态与动作。
///
/// 默认 `autoDispose`：页面离开即释放，表单内容不跨页面残留 —— 与 master
/// 「`factory` 注册的 ViewModel、每页一个新实例」是同一生命周期。
///
/// 登录成功后**不在这里写登录态**：`AuthService.login` 会把令牌与用户写进
/// `AuthStorage`，UI 侧再经 `Session`（core/auth/session.dart）沿
/// `userChanges` 回流。一处通知比两处各写一次更不容易走岔。

abstract class _$LoginNotifier extends $Notifier<LoginState> {
  LoginState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<LoginState, LoginState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<LoginState, LoginState>,
              LoginState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
