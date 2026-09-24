import 'package:flutter/widgets.dart';
import 'package:my_app/app/routing/router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'providers.g.dart';

/// 应用组合根（FSD 的 app 层）的装配。

/// 应用路由。
///
/// `keepAlive` 是硬要求：重建路由器会丢掉整个导航栈。
///
/// 初始 location 在这里指到启动页：`routeInfoProvider` 是 memoized 的，**必须在
/// `config()` 之前设**（`app.dart` 的 build 就会调它）。取舍见
/// frontend/directory-structure.md「应用层」。
@Riverpod(keepAlive: true)
AppRouter router(Ref ref) {
  final appRouter = AppRouter();
  return appRouter..routeInfoProvider(
    initialRouteInformation: RouteInformation(uri: Uri.parse(splashRoutePath)),
  );
}
