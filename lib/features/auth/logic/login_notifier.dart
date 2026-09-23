import 'package:flutter/foundation.dart';
import 'package:my_app/core/base/failure.dart';
import 'package:my_app/core/base/result.dart';
import 'package:my_app/features/auth/data/auth_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'login_notifier.g.dart';

/// 登录表单的不可变快照。
@immutable
class LoginState {
  const new({this.email = '', this.password = '', this.isSubmitting = false});

  final String email;
  final String password;
  final bool isSubmitting;

  /// 提交按钮是否可用（判据与 master 的 `AuthViewModel.canSubmit` 一致）
  bool get canSubmit => email.isNotEmpty && password.length >= 6;

  LoginState copyWith({String? email, String? password, bool? isSubmitting}) =>
      LoginState(
        email: email ?? this.email,
        password: password ?? this.password,
        isSubmitting: isSubmitting ?? this.isSubmitting,
      );
}

/// 登录表单的状态与动作。
///
/// 默认 `autoDispose`：页面离开即释放，表单内容不跨页面残留 —— 与 master
/// 「`factory` 注册的 ViewModel、每页一个新实例」是同一生命周期。
///
/// 登录成功后**不在这里写登录态**：`AuthService.login` 会把令牌与用户写进
/// `AuthStorage`，UI 侧再经 `Session`（core/auth/session.dart）沿
/// `userChanges` 回流。一处通知比两处各写一次更不容易走岔。
@riverpod
class LoginNotifier extends _$LoginNotifier {
  @override
  LoginState build() => const LoginState();

  // 写入走方法、不开 setter：状态私有，页面只 ref.watch
  // （frontend/state-management.md「状态私有」）
  void updateEmail(String value) => state = state.copyWith(email: value);

  void updatePassword(String value) => state = state.copyWith(password: value);

  /// 一次清空两个输入框（同一个 state，页面只重建一趟）
  void resetForm() => state = const LoginState();

  /// 登录；返回 [Result] 供页面按成功 / 失败分支跳转或提示
  Future<Result<void, Failure>> login() async {
    state = state.copyWith(isSubmitting: true);

    final result = await ref
        .read(authRepositoryProvider)
        .login(state.email, state.password);

    // 页面在请求飞行中被 pop 时 provider 已释放，回写状态会抛
    if (ref.mounted) state = state.copyWith(isSubmitting: false);
    return result;
  }
}
