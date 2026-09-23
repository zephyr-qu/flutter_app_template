import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:my_app/core/models/user.dart';

/// 把「登录态变化」桥接成 [Listenable]，交给 auto_route 的 `reevaluateListenable`。
///
/// 401 之后没人能跳转（拦截器没有 `BuildContext`），靠它让守卫重新评估路由；
/// 完整链路见 backend/error-handling.md「登出语义」。
///
/// 数据源与 `core/auth/session.dart` 的 `Session` 是**同一个流**
/// （`AuthStorage.userChanges`）：一个是导航侧的消费者，一个是 UI 侧的。
/// 两者都订阅广播流，谁先谁后不影响结果。
class AuthReevaluateListenable extends ChangeNotifier {
  new(Stream<User?> userChanges) {
    _subscription = userChanges.listen(_onUserChanged);
  }

  late final StreamSubscription<User?> _subscription;

  /// 流的第一个事件是**订阅时的当前值**，不代表状态变化。
  /// 放它过去会在启动首帧触发一次无意义的路由重评估（虽然结果等价），
  /// 所以这里丢掉第一个事件，只对真正的变化通知。
  bool _primed = false;

  void _onUserChanged(User? user) {
    if (!_primed) {
      _primed = true;
      return;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
