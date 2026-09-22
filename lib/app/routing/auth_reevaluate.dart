import 'package:flutter/foundation.dart';
import 'package:signals_flutter/signals_flutter.dart';

/// 把「是否已登录」信号桥接成 [Listenable]，交给 auto_route 的 `reevaluateListenable`。
///
/// 401 之后没人能跳转（拦截器没有 `BuildContext`），靠它让守卫重新评估路由；
/// 完整链路见 backend/error-handling.md「登出语义」。
class AuthReevaluateListenable extends ChangeNotifier {
  new(ReadonlySignal<bool> isLoggedIn) {
    _unsubscribe = isLoggedIn.subscribe((_) => notifyListeners());
  }

  late final void Function() _unsubscribe;

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }
}
