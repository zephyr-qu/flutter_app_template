# 目录结构

---

## 概览

本项目按 **Feature-Sliced Design (FSD) 简化版** 组织：按业务功能划分目录，每个 feature 内部自包含三层：

```
lib/
├── main.dart                  # 程序入口
├── bootstrap.dart             # 启动初始化（环境 + ProviderScope + 异常兜底）
│
├── app/                       # 应用层（组合根：只做装配）
│   ├── app.dart               #   根组件：主题 / 路由装到一起
│   ├── providers.dart         #   组合根自己的 provider（AppRouter）
│   ├── routing/               #   路由：AppRouter（生成物同目录）
│   └── pages/                 #   全局页面：启动页、404（不属于任何 feature）
│
├── core/                      # 基础设施 + 状态耦合的适配层
│   ├── base/                  #   Failure / Result / runCatching
│   ├── config/                #   配置：偏好快照 + Notifier / 偏好的裸存储 / 网络配置
│   ├── data/                  #   数据基础设施
│   │   ├── database/          #     Drift 连接 + schema + 表
│   │   ├── network/           #     Dio 工厂 / 拦截器栈 / 应用侧装配
│   │   └── storage/           #     FileStorage
│   ├── logging/               #   日志封装 + 调试日志脱敏
│   ├── providers.dart         #   基础设施 provider（prefs / 数据库 / 文件）
│   ├── theme/                 #   色板 / ThemeData 组装 / 设计 token
│   └── ui/                    #   共享 UI：三态组件 + Failure 文案（本地常量表）
│
└── features/                  # 业务功能（主导航，每个自包含）
    └── {feature}/
        ├── api.dart           # 对外出口（可选）：只 re-export 对外的 provider 与模型
        ├── logic/             # Notifier（状态 + 业务逻辑）
        │   └── {feature}_notifier.dart
        ├── data/              # 数据层（各文件职责见下方「数据层的文件角色」）
        │   ├── models/        #   数据模型（@freezed，见 type-safety.md）
        │   ├── {feature}_api.dart         # Retrofit API（可选）
        │   ├── {feature}_dao.dart         # Drift 查询（按需）
        │   ├── {feature}_service.dart     # 业务实现
        │   ├── {feature}_providers.dart   # provider 装配（可选）
        │   └── {feature}_repository.dart  # 仓库抽象（按需，见 §4）
        └── page/              # UI 页面（ConsumerWidget / ConsumerStatefulWidget）
            └── {feature}_list_page.dart

#   现有 feature：home（首页 + 主框架）、profile（个人中心）、
#   sample（金标准示例 —— data 三形态 / logic / page / api.dart 出口的照抄对象）
```

> 快照（2026-10）：树里的「现有 feature」是当时的状态，`ls lib/features/` 可查当前值；增删 feature 时同步本节。

**不存在** `domain/`、`application/`、`usecase/`、`shared/`、`core/error/`、`core/local/` 这些目录（也不设 UseCase 层）。在别处看到对它们的引用，那处引用是过期的。

与状态管理无关的基础设施（Failure / Result / 日志 / 网络 / 数据库 / 主题 / 无文案 UI 组件）都放在 `lib/core/`。**单包结构**：app 代码不抽包，`packages/` 只放独立工具包。主题层的两条归属规则见 [component-guidelines.md](./ui/component-guidelines.md)「主题层」。

---

## 核心原则

### 1. 按功能切片，不按技术分层

✅ 好：修改「示例」功能时，所有相关代码都在同一个 `sample/` 文件夹里；❌ 避免 `models/`、`services/`、`screens/` 这种跨功能的目录

### 2. Feature 内部三层职责

| 层 | 目录 | 职责 | 典型内容 |
| --- | ------ | --------- | ---------------- |
| UI | `page/` | 页面组件（`ConsumerWidget` / `ConsumerStatefulWidget`） | `sample_list_page.dart` |
| Logic | `logic/` | Notifier + 状态（`@riverpod`） | `sample_list_notifier.dart` |
| Data | `data/` | 网络、本地、模型 | `sample_api.dart`, `sample_dao.dart`, `sample_service.dart`, `models/` |

`{feature}/api.dart` 是**可选**的第四种文件，放在 feature 根上：只有它允许被别的 feature 引用，里面只 re-export 对外的**只读 provider 与模型**（不放 Notifier 类、不放 `page/`）。想让别的 feature 用上本 feature 的 `logic/`，就在这里显式开出口 —— 不要为了「跨 feature 可引用」把业务计算挪进 `data/`。判据见 [cross-cutting.md](./cross-cutting.md)「架构边界与形态约定」。

### 3. 共享层（core/）严格克制

- 只放真正跨 feature 复用的基础设施（Dio 客户端、主题常量、本地存储）；**不要提前抽取不稳定的基类** —— 宁可重复写两次；一个文件被 2+ 个 feature 使用时才考虑提到 `core/`
- **模型放哪**：默认留在该 feature 的 `data/models/`（如 `SampleItem`）。满足**任一**条件才新建 `lib/core/models/`：① 被 2+ 个 feature 共享；② core 自己的代码要用它（core 不能反向依赖 feature）。当前仓库**没有** `lib/core/models/`，需要时再建
- 不要把 feature 私有的模型塞进 core，也不要让 core 反向 import feature
- core/ 不包含业务逻辑、不包含状态管理

### 3.1 应用层（app/）是组合层

`lib/app/` 是 FSD 的 app 层，负责装配：根组件（`app.dart`）、路由（`routing/`）与全局页面（`pages/`，即启动页与 404）。它们**不能**放在 `core/`（会形成 `core → features` 的反向依赖）。

- 依赖方向：`app → features → core`
- **组合根只做接线**：`lib/app/app.dart`（把主题 / 路由装到一起）与 `lib/bootstrap.dart`（环境加载、异常兜底、`ProviderScope` 装配）都是入口文件，具体定义一律写在各自文件里；`app.dart` 保持简短
- 全局页面放在 `lib/app/pages/`，可以直接 import `app/routing/router.dart` 用路由类导航（如 `context.router.replaceRoute(const MainRoute())`）
- `features/` 的页面可以 import `app/routing/router.dart` 使用路由类（如 `const SampleListRoute()`）以获得参数类型安全
- 路由 / 导航的**行为约定**（路由器 `keepAlive`、初始 location、`AutoTabsRouter` 标签、底部导航改动的测试同步）见 [ui/routing.md](./ui/routing.md)。

### 4. Repository 接口按需使用

- 有真实的多实现需求（mock / 线上切换）才写 repository 抽象
- 简单的 feature 直接调用 Service，不需要额外的接口层

### 5. Feature 间通信：core 的 provider，或对方的 `api.dart` 出口

✅ **core/ 层暴露的 provider** 是 feature 间通信的默认方式。
✅ 需要读别的 feature 自己的状态时，走对方根上的 `api.dart` 出口（只读 provider + 模型，见 §2 末）；**不要**为此把计算挪进 `data/`。
❌ 不使用事件总线。
❌ 不依赖路由重建。

```dart
// core/config/app_settings.dart —— 主题等偏好，跨 feature 可读；真源 core/config/user_preferences.dart
final themeMode = ref.watch(appSettingsProvider).themeMode; // Feature B 响应
```

`AppSettingsNotifier` 的完整写法（`keepAlive`、先改内存再落盘）见 [state-management.md](./ui/state-management.md)「三种 Provider 形态」。关键约束：

- 共享的 provider 必须是真正的跨 feature 数据。**一个状态只在一个 feature 内使用时，留在那个 feature 的 `logic/` 里。**
- core/ 状态与持久化存储保持**单向**（细节见 [state-management.md](./ui/state-management.md)「三种 Provider 形态」），**不要两边各写一次**。

### 6. 数据库：schema 在 core，查询在 feature

Drift 的表结构与 `AppDatabase` 都在 `lib/core/data/database/`（快照 2026-10：当前只有 `DbArticle` 这一张通用示例表，`ls lib/core/data/database/tables/` 可查）。类名前缀与「不要写注解」的约束见 [data/database-guidelines.md](./data/database-guidelines.md)「命名规范：加表就是加前缀」。

但**查询（DAO）属于 feature**：`features/{feature}/data/{feature}_dao.dart`（`@DriftAccessor` 声明见下方「数据层的文件角色」）。加表时把它加进 `AppDatabase` 的 `@DriftDatabase` 即可，drift 的 library 约束见 [data/database-guidelines.md](./data/database-guidelines.md)。

---

## Feature 目录模板

创建新 feature 时照 Overview 的目录树展开，`_api` / `_dao` / `_providers` / `_repository` 均为按需件；各文件职责与命名见下方「数据层的文件角色」与「命名约定」。

### 数据层的文件角色

层级依赖方向是 `page/ → logic/ → data/ → core/`（由 `packages/app_lints` 插件强制，见 [./cross-cutting.md](./cross-cutting.md)「架构边界与形态约定」）；数据在层间的流向见 [guides/cross-layer-thinking-guide.md](./guides/cross-layer-thinking-guide.md)。

| 文件 | 角色 | 备注 |
| --- | --- | --- |
| `{feature}_api.dart` | Retrofit 接口定义，只描述 HTTP 形状 | 不做错误映射，不碰缓存 |
| `{feature}_service.dart` | 业务实现：调用 API、映射错误、读写缓存 | 返回 `Result<T, Failure>` |
| `{feature}_repository.dart` | 抽象接口 | 按需，见「Repository 接口按需使用」（§4） |
| `{feature}_dao.dart` | Drift 查询 | 只碰行类 `DbArticle`，行↔模型转换留在 Service；用 `@DriftAccessor` 声明要访问的表（表与数据库同包，见 [./data/database-guidelines.md](./data/database-guidelines.md)「分工」） |
| `{feature}_providers.dart` | provider 装配 | 只提供依赖，不含业务逻辑 |
| `models/` | `@freezed` 数据模型 | 见 [./type-safety.md](./type-safety.md) |

完整范例见 `lib/features/sample/`（API + DAO + Service + Repository + Notifier + 页面）。

---

## 命名约定

**这张表是命名约定的唯一权威**。

| 元素 | 规范 | 示例 |
| --------- | ----------- | ------- |
| Feature 目录 | snake_case | `sample/`、`home/` |
| Dart 源文件 | snake_case | `sample_service.dart` |
| Repository 接口 | `{feature}_repository.dart` / `{Feature}Repository` | `sample_repository.dart` / `SampleRepository` |
| Service 实现 | `{feature}_service.dart` / `{Feature}Service` | `sample_service.dart` / `SampleService` |
| Retrofit API 定义 | `{feature}_api.dart` / `{Feature}Api` | `sample_api.dart` / `SampleApi` |
| Drift DAO（按需） | `{feature}_dao.dart` / `{Feature}Dao` | `sample_dao.dart` / `SampleDao` |
| provider 装配 | `{feature}_providers.dart` | `sample_providers.dart` |
| Notifier | `{feature}_notifier.dart` / `{Feature}Notifier` | `sample_list_notifier.dart` / `SampleListNotifier`（provider 名 `sampleListProvider`） |
| 页面文件 | `{feature}_page.dart` | `sample_list_page.dart` |
| 页面类 | `{Feature}Page` | `SampleListPage` |
| 数据模型 | PascalCase | `SampleItem` |
| Model 文件 | `{model}.dart` | `sample_item.dart` |
| 共享组件 | 描述性 PascalCase | `EmptyWidget`, `ErrorText` |

Service 与 Repository 接口的绑定在 `{feature}_providers.dart` 里（`SampleRepository` 的实现是 `SampleService`，provider 返回抽象类型）；简单 feature 可以不写接口，直接让 provider 暴露 Service（见本文件「Repository 接口按需使用」与 [state-management.md](./ui/state-management.md)「三种 Provider 形态」）。


