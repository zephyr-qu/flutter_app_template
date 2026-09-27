import 'package:injectable/injectable.dart';
import 'package:my_app/core/base/failure.dart';
import 'package:my_app/core/base/result.dart';
import 'package:my_app/core/base/run_async.dart';
import 'package:my_app/core/models/user.dart';
import 'package:my_app/features/auth/data/auth_repository.dart';
import 'package:signals_flutter/signals_flutter.dart';

/// 认证 ViewModel
///
/// 信号私有持有、以 [ReadonlySignal] 对外暴露：UI 只能订阅，写入必须走方法。
@injectable
class AuthViewModel {
  new(this._repo);
  final AuthRepository _repo;

  // ========== 信号（私有可变，只有本类能写）==========
  // `name` 是 v7 的调试标签（DevTools 与超时/异常信息里用它标注信号）
  final AsyncSignal<User?> _user = asyncSignal<User?>(
    AsyncState.data(null),
    options: const AsyncSignalOptions<User?>(name: 'authViewModel.user'),
  );
  final FlutterSignal<String> _email = signal(
    '',
    options: const SignalOptions<String>(name: 'authViewModel.email'),
  );
  final FlutterSignal<String> _password = signal(
    '',
    options: const SignalOptions<String>(name: 'authViewModel.password'),
  );

  // ========== 计算信号（computed 天生只读，无需包一层）==========
  late final FlutterComputed<bool> canSubmit = computed(
    () => _email.value.isNotEmpty && _password.value.length >= 6,
    options: const ComputedOptions<bool>(name: 'authViewModel.canSubmit'),
  );

  // ========== 对外只读视图（UI 用 useSignalValue 订阅）==========

  /// 当前用户；UI 只读，写入走 [login] / [logout]
  ReadonlySignal<AsyncState<User?>> get user => _user;

  /// 登录邮箱输入；UI 只读，写入走 [updateEmail]
  ReadonlySignal<String> get email => _email;

  /// 登录密码输入；UI 只读，写入走 [updatePassword]
  ReadonlySignal<String> get password => _password;

  // ========== 方法 ==========

  /// 登录
  Future<Result<void, Failure>> login() =>
      runAsync(_user, () => _repo.login(_email.value, _password.value));

  /// 登出
  ///
  /// 登出只报成败、不产生值（`Result<void, _>`），所以走 [runAsyncVoid]：
  /// 成功时信号置为「已无用户」。
  Future<Result<void, Failure>> logout() =>
      runAsyncVoid(_user, _repo.logout, onSuccess: null);

  /// 两个输入框一次清空：`canSubmit` 只重算一次，页面只重建一趟
  void resetForm() {
    batch(() {
      _email.value = '';
      _password.value = '';
    });
  }

  // 写入必须走方法、不开 setter：信号私有持有，页面只订阅
  // （frontend/state-management.md「信号」）
  // ignore: use_setters_to_change_properties
  void updateEmail(String value) => _email.value = value;

  // 同上
  // ignore: use_setters_to_change_properties
  void updatePassword(String value) => _password.value = value;
}
