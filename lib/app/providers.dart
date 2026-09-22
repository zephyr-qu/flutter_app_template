import 'package:my_app/app/routing/auth_reevaluate.dart';
import 'package:my_app/app/routing/router.dart';
import 'package:my_app/core/providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'providers.g.dart';

/// 应用组合根（FSD 的 app 层）的装配。
///
/// 这两个对象都必须是**长生命周期**的：一个是导航栈本身，一个是守卫的触发器。

/// 应用路由。
///
/// `keepAlive` 是硬要求：重建路由器会丢掉整个导航栈（master 用 `useMemoized`
/// 表达同一件事）。它的依赖 `authStorageProvider` 是 keepAlive 单例，
/// 所以正常情况下不会被重建。
@Riverpod(keepAlive: true)
AppRouter router(Ref ref) => AppRouter(ref.watch(authStorageProvider));

/// 登录态 → auto_route 的重评估触发器（见 auth_reevaluate.dart）
@Riverpod(keepAlive: true)
AuthReevaluateListenable authReevaluate(Ref ref) {
  final listenable = AuthReevaluateListenable(
    ref.watch(authStorageProvider).userChanges,
  );
  ref.onDispose(listenable.dispose);
  return listenable;
}
