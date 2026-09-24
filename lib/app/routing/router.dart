import 'package:auto_route/auto_route.dart';
import 'package:my_app/app/pages/not_found_page.dart';
import 'package:my_app/app/pages/splash_page.dart';
import 'package:my_app/features/home/page/home_page.dart';
import 'package:my_app/features/home/page/main_page.dart';
import 'package:my_app/features/profile/page/profile_page.dart';
import 'package:my_app/features/sample/page/sample_list_page.dart';

part 'router.gr.dart';

/// 启动页路径。
///
/// 冷启动的初始 location 由 `app/providers.dart` 指到这里 —— 两边共用这一份常量，
/// 写死两处迟早会漂移。
const String splashRoutePath = '/splash';

/// 应用路由表。
///
/// **没有登录守卫**：本分支已删除认证功能，所有路由都是公开的。
@AutoRouterConfig()
class AppRouter extends RootStackRouter {
  @override
  RouteType get defaultRouteType => const RouteType.material();

  @override
  List<AutoRoute> get routes => [
    // 启动页
    AutoRoute(path: splashRoutePath, page: SplashRoute.page),

    // 主框架（带底部导航）
    AutoRoute(
      path: '/',
      page: MainRoute.page,
      children: [
        AutoRoute(path: 'home', page: HomeRoute.page, initial: true),
        AutoRoute(path: 'sample', page: SampleListRoute.page),
        AutoRoute(path: 'profile', page: ProfileRoute.page),
      ],
    ),

    // 404
    AutoRoute(path: '*', page: NotFoundRoute.page),
  ];
}
