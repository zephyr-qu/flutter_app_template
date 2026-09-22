import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:my_app/app/pages/not_found_page.dart';
import 'package:my_app/app/pages/splash_page.dart';
import 'package:my_app/core/data/storage/auth_storage.dart';
import 'package:my_app/features/article/page/article_detail_page.dart';
import 'package:my_app/features/article/page/article_list_page.dart';
import 'package:my_app/features/auth/page/login_page.dart';
import 'package:my_app/features/demo/page/storage_demo_page.dart';
import 'package:my_app/features/home/page/home_page.dart';
import 'package:my_app/features/home/page/main_page.dart';
import 'package:my_app/features/profile/page/profile_page.dart';

part 'router.gr.dart';

/// 应用路由表与登录守卫。
///
/// 登录态**不在构造时捕获**：由守卫在每次导航时实时读取 [AuthStorage]。
@AutoRouterConfig()
class AppRouter extends RootStackRouter {
  new(this.authStorage);

  /// 认证存储（守卫在导航时实时查询）
  final AuthStorage authStorage;

  @override
  RouteType get defaultRouteType => const RouteType.material();

  /// 认证守卫：未登录时中断当前导航并重定向到登录页
  void _checkAuth(NavigationResolver resolver, StackRouter router) {
    if (authStorage.isLoggedIn) {
      resolver.next();
    } else {
      resolver.redirectUntil(const LoginRoute());
    }
  }

  @override
  List<AutoRoute> get routes => [
    // 启动页（公开）
    AutoRoute(path: '/splash', page: SplashRoute.page),

    // 登录页（公开）
    AutoRoute(path: '/login', page: LoginRoute.page),

    // 主框架（带底部导航）—— 需登录
    AutoRoute(
      path: '/',
      page: MainRoute.page,
      guards: [AutoRouteGuard.simple(_checkAuth)],
      children: [
        AutoRoute(path: 'home', page: HomeRoute.page, initial: true),
        AutoRoute(path: 'articles', page: ArticleListRoute.page),
        AutoRoute(path: 'profile', page: ProfileRoute.page),
      ],
    ),

    // 文章详情（不经过底部导航）—— 需登录
    AutoRoute(
      path: '/articles/:id',
      page: ArticleDetailRoute.page,
      guards: [AutoRouteGuard.simple(_checkAuth)],
    ),

    // 本地存储示例（入口在「个人 → 设置」）—— 需登录
    AutoRoute(
      path: '/storage-demo',
      page: StorageDemoRoute.page,
      guards: [AutoRouteGuard.simple(_checkAuth)],
    ),

    // 404
    AutoRoute(path: '*', page: NotFoundRoute.page),
  ];
}
