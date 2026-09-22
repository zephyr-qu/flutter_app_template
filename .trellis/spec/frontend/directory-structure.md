# Directory Structure

> How code is organized in this project.

---

## Overview

This project follows **Feature-Sliced Design (FSD) 简化版** — 按业务功能（auth, article, profile）划分目录，每个 feature 内部自包含三层：

```
lib/
├── main.dart                  # 程序入口
├── bootstrap.dart             # 启动初始化（环境 + DI + 异常兜底）
│
├── app/                       # 应用层（组合根：只做装配）
│   ├── app.dart               #   根组件：主题 / 路由 / l10n / DI 装到一起
│   ├── routing/               #   路由：AppRouter + AuthGuard + 登录态桥接（生成物同目录）
│   └── pages/                 #   全局页面：启动页、404（不属于任何 feature）
│
├── core/                      # 共享基础设施（严格克制）
│   ├── base/                  #   基础抽象：Failure, Result
│   ├── config/                #   配置：UserPreferences, NetworkConfig
│   ├── data/                  #   数据基础设施
│   │   ├── database/          #     Drift 连接 + schema（表结构放 tables/）
│   │   ├── network/           #     Dio 客户端 + Mock
│   │   └── storage/           #     本地持久化
│   ├── logging/               #   日志
│   ├── models/                #   跨 feature 共享的数据模型（如 User）
│   ├── ui/                    #   共享 UI：三态组件 + Failure 文案翻译（少用）
│   ├── theme/                 #   主题：色板 / ThemeData 组装 / 设计 token
│   └── core_module.dart       #   共享依赖的 DI 装配（@module）
│
├── features/                  # 业务功能（主导航，每个自包含）
│   └── {feature}/
│       ├── logic/             # ViewModel / 状态管理（signals）
│       │   └── {feature}_view_model.dart
│       ├── data/              # 数据层：API、DAO、Service、Repository、Model
│       │   ├── models/        #   数据模型（@freezed，见 type-safety.md）
│       │   ├── {feature}_api.dart         # Retrofit API 定义
│       │   ├── {feature}_dao.dart         # 本地库查询（Drift，按需）
│       │   ├── {feature}_service.dart     # 业务能力实现（API / 缓存 / 错误映射）
│       │   └── {feature}_repository.dart  # 仓库抽象（按需）
│       └── page/              # UI 页面
│           └── {feature}_list_page.dart
│
│   现有 feature：auth（认证）、article（文章）、home（首页 + 主框架）、
│   profile（个人中心）、demo（本地存储示例 —— 纯示例，可整目录删除）
│
├── l10n/                      # 国际化（见 localization.md）
│   ├── app_zh.arb             #   模板语言：中文
│   └── app_en.arb             #   第二语言：英文
│
└── di/                        # 依赖注入注册
    ├── service_locator.dart         # configureDependencies() 入口
    └── service_locator.config.dart  # 自动生成
```

**不存在** `domain/`、`application/`、`shared/`、`core/error/`、`core/local/` 这些目录 —— 它们属于本脚手架迁移走的旧 Clean Architecture 布局。若在别处看到对它们的引用，那处引用是过期的。

`core/theme/` 是「`core/` 保持浅」的唯一刻意例外，为的是让主题层的两条归属规则可以被强制（见 [component-guidelines.md](./component-guidelines.md)「Theme Layer」）。

---

## 核心原则

### 1. 按功能切片，不按技术分层

✅ 好：修改「阅读」功能时，所有相关代码在同一个 `article/` 文件夹里
❌ 避免：`models/`、`services/`、`screens/` 这种跨功能的目录

### 2. Feature 内部三层职责

| 层 | 目录 | 职责 | 典型内容 |
| --- | ------ | --------- | ---------------- |
| UI | `page/` | 页面组件（hooks + widgets） | `article_list_page.dart` |
| Logic | `logic/` | ViewModel + 状态（signals） | `article_view_model.dart` |
| Data | `data/` | 网络、本地、模型 | `api/*.dart`, `dao/*.dart`, `service/*.dart`, `models/*.dart` |

### 3. 共享层（core/）严格克制

- 只放真正跨 feature 复用的基础设施（Dio 客户端、主题常量、本地存储）
- **过早抽象是个人项目的头号杀手** — 宁可重复写两次，也不要提前抽取不稳定的基类
- 一个文件被 2+ 个 feature 使用时才考虑提到 core/
- **模型放哪**：满足下面**任一**条件就放 `core/models/`，否则留在该 feature 的 `data/models/`：
  1. 被 2+ 个 feature 共享 —— `User`（auth / home / profile 共用，并经 `AuthStorage.currentUser` 暴露）
  2. core 自己的代码要用它 —— `TokenSet`（`TokenRefresher` 解析它，而 core 不能反向依赖 feature）

  对照：`Article` 只有 article 用、core 也不碰它，所以留在 `features/article/data/models/`。
  不要把 feature 私有的模型塞进 core，也不要让 core 反向 import feature——依赖方向始终是 `features → core`
- core/ 不包含业务逻辑、不包含状态管理

### 3.1 应用层（app/）是组合层

`lib/app/` 是 FSD 的 app 层，负责装配：根组件（`app.dart`）、路由（`routing/`）与全局页面（`pages/`，即启动页与 404）。路由需要 import 每个 feature 的 `page/`，全局页面又被路由引用，因此它们**不能**放在 `core/`——否则会形成 `core → features` 的反向依赖。

- 依赖方向：`app → features → core`
- **组合根只做接线**：`lib/app/app.dart`（把主题 / 路由 / l10n / DI 装到一起）与
  `lib/bootstrap.dart`（环境加载、异常兜底、DI 初始化）都是入口文件，具体定义一律在各自
  文件里。保持 `app.dart` 简短是刻意的——它是最常被读的入口，应该让人一眼看懂 App 由什么
  组装而成，而不必先跳过上百行主题定义
- 全局页面放在 `lib/app/pages/`，可以直接 import `app/routing/router.dart` 用路由类导航（如 `context.router.replaceRoute(const MainRoute())`）——放在 `core/` 就只能退回 `context.router.replacePath('/')` 这类字符串 path
- `features/` 的页面可以 import `app/routing/router.dart` 使用路由类（如 `ArticleDetailRoute(articleId: id)`）以获得参数类型安全
- 登录态由 `AppRouter` 的 `AutoRouteGuard` 在每次导航时实时读取 `AuthStorage`，**不要**因为登录态变化而重建路由器（重建会丢弃导航栈）
- **初始路由（`SplashPage`）不能有构造参数**：声明式路由无法为它提供参数，会在启动时触发 `argsAs` 抛异常。需要判断登录态就地实时读 `AuthStorage`，不要做成入参
- 主框架（`features/home/page/main_page.dart`）的标签用 `AutoTabsRouter` 管理，**不要**自己在 `State` 里存 `_currentIndex`：高亮索引必须由路由栈推导，否则当标签是被别处切换的（首页快捷入口、深链、返回栈）时会与实际显示的页面错位。用默认的 IndexedStack 版本，切回来时各标签的状态还在

### 4. Repository 接口按需使用

- 有真实的多实现需求（mock / 线上切换）才写 repository 抽象
- 简单的 feature 直接调用 Service，不需要额外的接口层

### 5. Feature 间通信通过 core/ 信号

✅ **core/ 层全局信号** 是 feature 间通信的唯一方式。
❌ 不使用事件总线（调试黑盒，找不到谁在消费）。
❌ 不依赖路由重建（当前页面在栈中时无效）。

```dart
// core/models/user.dart —— 跨 feature 共享的模型
// core/data/storage/auth_storage.dart
import '../../models/user.dart';
final currentUser = signal<User?>(null);

// Feature A 写入
await authStorage.saveUser(updatedUser);

// Feature B 自动响应（通过 useSignalValue）
final name = useSignalValue(authStorage.currentUser)?.name;
```

关键约束：

- 共享信号必须是真正的跨 feature 数据。**如果一个状态只在一个 feature 内使用，留在 ViewModel 里。**
- core/ 里的信号跟持久化存储保持同步（如 `AuthStorage` 同时维护 `currentUser` 信号和 SharedPreferences / 安全存储）。

### 6. 数据库：schema 在 core，查询在 feature

Drift 的表结构必须放 core（`core/data/database/tables/`，用 `part` 与 `AppDatabase`
同属一个 library）——`@DriftDatabase` 得看得见所有表，而 core 不能 import feature。

表类名统一加 `Db` 前缀（`tables/db_articles.dart` → 类名 `DbArticles`）。行类
`DbArticle` 与 SQL 表名 `db_articles` 由 drift 自动派生，**不要写任何注解**。

但**查询（DAO）属于 feature**：`features/{feature}/data/{feature}_dao.dart`，
用 `@DriftAccessor` 并在这个 feature 的 module 里注册。理由同上——查询写进 core
就搬不出来了，只会随 feature 数量膨胀。

细节与 drift 的 library 约束见 [backend/database-guidelines.md](../backend/database-guidelines.md)。

---

## Feature 目录模板

创建一个新 feature 时的标准布局：

```
features/{feature}/
├── logic/
│   └── {feature}_view_model.dart
├── data/
│   ├── models/
│   │   └── {model}.dart
│   ├── {feature}_api.dart         # Retrofit（可选）
│   ├── {feature}_dao.dart         # 本地库查询（Drift，可选）
│   ├── {feature}_service.dart     # 业务实现
│   └── {feature}_repository.dart  # 抽象接口（按需）
└── page/
    └── {feature}_page.dart
```

---

## Naming Conventions

**这张表是命名约定的唯一权威**（`backend/directory-structure.md` 不再各存一份）。

| 元素 | 规范 | 示例 |
| --------- | ----------- | ------- |
| Feature 目录 | snake_case | `auth/`、`article/` |
| Dart 源文件 | snake_case | `auth_service.dart` |
| Repository 接口 | `{feature}_repository.dart` / `{Feature}Repository` | `auth_repository.dart` / `AuthRepository` |
| Service 实现 | `{feature}_service.dart` / `{Feature}Service` | `auth_service.dart` / `AuthService` |
| Retrofit API 定义 | `{feature}_api.dart` / `{Feature}Api` | `auth_api.dart` / `AuthApi` |
| Drift DAO（按需） | `{feature}_dao.dart` / `{Feature}Dao` | `article_dao.dart` / `ArticleDao` |
| DI module | `{feature}_module.dart` / `{Feature}Module` | `auth_module.dart` / `AuthModule` |
| ViewModel | `{feature}_view_model.dart` / `{Feature}ViewModel` | `auth_view_model.dart` / `AuthViewModel` |
| 页面文件 | `{feature}_page.dart` | `article_list_page.dart` |
| 页面类 | `{Feature}Page` | `ArticleListPage` |
| 数据模型 | PascalCase | `Article`, `User` |
| Model 文件 | `{model}.dart` | `article.dart` |
| 共享组件 | 描述性 PascalCase | `EmptyWidget`, `ErrorText` |

Service 与 Repository 接口的绑定用 `@LazySingleton(as: AuthRepository)`；简单 feature 可以不写接口，直接调 Service（见上文「Repository 接口按需使用」）。

---

## 与旧结构的区别

| 旧（Clean Architecture） | 新（FSD 简化版） |
| --- | --- |
| `application/` | `logic/` |
| `domain/` + `data/` | `data/`（合并） |
| `page/` | 不变 |
| 必须写 repository 接口 | 按需，简单 feature 可直接用 Service |
