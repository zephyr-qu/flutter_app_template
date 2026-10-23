# 路由与导航

> 路由代码位置见 [directory-structure.md](../directory-structure.md)「应用层（app/）是组合层」：`lib/app/routing/` 是组合根的一部分（FSD 的 app 层负责装配）。本文件只讲**路由 / 导航的行为约定**，不重复目录结构。

---

## 路由器生命周期

- **不要随状态变化重建路由器**：`routerProvider` 是 `keepAlive`（由 `app/providers.dart` 持有单例）。
- **初始路由（`SplashPage`）不能有构造参数**：需要读什么就在页面里实时读，不要做成入参。

## 冷启动的初始 location

- 冷启动初始 location（`/splash`，常量 `splashRoutePath`）由 `app/providers.dart` 的 `routerProvider` 设置，**不是在路由表里标 `initial: true`** —— `AutoRoute(initial: true)` 只对**没写 `path`** 的路由生效。
- 该设置**必须在 `config()` 之前**（`routeInfoProvider` 是 memoized 的，`app.dart` 的 build 会调 `config()`）。
- 要「深链优先」，就在返回前判断 `platformDispatcher.defaultRouteName` 是否等于 `/`。

## 主框架标签（底部导航）

- 主框架（`features/home/page/main_page.dart`）的标签用 `AutoTabsRouter` 管理，**不要**自己在 `State` 里存 `_currentIndex`：高亮索引必须由路由栈推导。用默认的 IndexedStack 版本。
- **改动底部导航标签**（在 `MainPage._tabs` 增删 / 调序）时，必须同步更新 `test/routing/main_shell_test.dart`（宽屏 `NavigationRail` 分支同理）。这条**不在任何 lint / 门禁的拦截范围内**，靠人同步（见 [index.md](../index.md) 的完成前自检）。

---

相关：导航的状态渲染见 [state-management.md](./state-management.md)「渲染状态」；跨 feature 只共享 `data/` 与对方 `api.dart` 出口、`page/`/`logic/` 不互引见 [cross-cutting.md](../cross-cutting.md)「架构边界与形态约定」。
