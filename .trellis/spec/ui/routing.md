# 路由与导航

> 路由代码在 `lib/app/routing/`（`AppRouter` + 生成的 `router.gr.dart`），属于组合根 ——
> 位置与分层理由见 [../directory-structure.md](../directory-structure.md)「应用层」。本文件只讲**行为约定**。

---

## 冷启动入口

- 根初始路由是 `AppRouter.routes` 列表里的**第一项**（当前 `path: '/splash'`）。
  要换冷启动落点就动这一项或 `SplashPage` 的分流，**不要**再叠一套初始路由机制。
- `SplashPage` 等动画之后 `context.replaceRoute(...)` 分流：已登录 → `MainRoute`，否则 → `LoginRoute`。
  登录态在**跳转那一刻**实时读（`getIt<AuthStorage>()`），不在启动时缓存 —— 否则会把冷启动期间翻转的登录态用错。
- `MainRoute` 的子路由 `home` 带 `initial: true`，那是**主框架的默认标签**，与冷启动入口无关。

## 登录守卫

- `MainRoute` 挂 `AutoRouteGuard.simple(_checkAuth)`，守卫在**每次导航时**实时读 `AuthStorage`，
  构造 `AppRouter` 时不捕获登录态。
- **不要因为登录态变化重建路由器** —— 重建会丢弃整个导航栈。登录态翻转后要让守卫重新评估，
  走 `lib/app/routing/auth_reevaluate.dart`（把 `isLoggedIn` 信号桥成 `Listenable` 交给 `reevaluateListenable`）；
  401 路径的完整链路见 [../data/error-handling.md](../data/error-handling.md)「登出语义」。
- 拦截器里**不要**做页面跳转：它没有 `BuildContext`，只清凭证，导航交给守卫。

## 主框架标签（底部导航）

- 标签由 `AutoTabsRouter` 管理（`features/home/page/main_page.dart` 的 `_tabs`）。
  **不要**在 `State` 里存 `_currentIndex`：高亮必须由路由栈推导，否则标签被别处切换（深链、返回栈）时会与
  实际显示的页面错位。
- `_tabs` 里带路由参数的项（如 `ArticleListRoute`）不是 `const`，整张表因此是 `static final`。
- **改动 `_tabs`（增删 / 调序）必须同步 `test/routing/main_shell_test.dart`**，宽屏的 `NavigationRail`
  分支同理。这条**不在任何 lint / 门禁的拦截范围内**，靠人同步（见 [../index.md](../index.md) 的完成前自检，
  以及 [../cross-cutting.md](../cross-cutting.md)「有意不设的项」）。

---

跳转一律用路由类（`context.replaceRoute(const MainRoute())`）而不是字符串 path —— 参数类型安全，
且不依赖路由表的 path 拼写（见 [../directory-structure.md](../directory-structure.md)「应用层」）。
