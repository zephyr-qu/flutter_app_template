import 'dart:async';

import 'package:my_app/core/data/storage/auth_storage.dart';
import 'package:my_app/core/models/user.dart';
import 'package:my_app/core/providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'session.g.dart';

/// 登录态（[User?]）的**可订阅镜像**，真源是 [AuthStorage]。
///
/// 为什么需要这一层，而不是让页面直接读 `authStorage.currentUser`：
/// 401 之后 `AuthInterceptor` 会调 `TokenStore.clearAuth()` —— 它属于 `core/data/network/`，
/// 不认识 Riverpod，也不该认识。所以「凭证被清了」这件事只能由存储对象广播出来
/// （[AuthStorage.userChanges]），再由本类转成 provider 状态，页面与守卫才有得订阅。
///
/// 路由守卫仍然直接读 `authStorage.isLoggedIn`：那是**同步**判断，用它做守卫不会
/// 出现「状态还没 emit、先判成未登录」的空窗；本 provider 管的是 UI。
@Riverpod(keepAlive: true)
class Session extends _$Session {
  @override
  User? build() {
    final storage = ref.watch(authStorageProvider);
    final subscription = storage.userChanges.listen((user) {
      if (!ref.mounted) return;
      state = user;
    });
    ref.onDispose(subscription.cancel);

    // 流的第一个事件就是当前值，这里同步读一次让首帧就有正确状态
    return storage.currentUser;
  }

  /// 是否已登录
  bool get isLoggedIn => state != null;

  /// 保存用户（登录流程用；令牌由 `AuthService` 自己写存储）
  ///
  /// 不在这里调 `state = user`：存储写完会经 [AuthStorage.userChanges] 回流，
  /// 一处通知比两处各写一次更不容易走岔。
  Future<void> saveUser(User user) =>
      ref.read(authStorageProvider).saveUser(user);

  /// 清凭证 + 清用户（本地登出；通知服务端由 `AuthService.logout()` 负责）
  Future<void> signOut() => ref.read(authStorageProvider).clearAuth();
}
