# Directory Structure

> 数据层（`features/*/data/`）的角色与文件约定。

> **The canonical layout lives in [`../frontend/directory-structure.md`](../frontend/directory-structure.md).** `lib/` 的完整目录树、分层职责、命名约定表都在那里 —— 本文件**不重复**，只补数据层视角的两件事：数据怎么在层间走、数据层有哪几个文件角色。

> **Scaffold note**: This is a personal Flutter scaffold/template for medium-small apps. The structure is **Feature-Sliced Design (FSD) 简化版** — no Clean Architecture layers, no UseCase layer (over-engineering for this scope). Notifiers talk directly to a feature's Service/Repository.

---

## Data flow

```
Page → Notifier → Repository (接口) → Service (实现) → Api (Retrofit) → Dio
                                          ↓
                                     Dao (Drift)  ← 缓存旁路
```

- 依赖方向是 `page/ → logic/ → data/ → core/`，由 `packages/app_lints/` 插件强制（`core/` 不得 import/export 上层，跨 feature 只共享 `data/`）
- Notifier 拿到的是**装配好的 provider**（`ref.watch(sampleRepositoryProvider)`），装配本身在 `{feature}_providers.dart`
- `Dto / Model` 只在 `data/` 层转换：Retrofit 拿到 JSON → 模型（`@freezed`），Service 返回 `Result<T, Failure>`；**缓存旁路**是 Service 同时消费网络与 DAO —— 网络成功就刷新缓存，网络失败就回退到缓存，见 [database-guidelines.md](./database-guidelines.md) 的「Drift」一节

---

## 数据层的文件角色

文件名与类名的规则见 [../frontend/directory-structure.md](../frontend/directory-structure.md)「Naming Conventions」。这里只说各自**负责什么**：

| 文件 | 角色 | 备注 |
| ------- | ------ | ------ |
| `{feature}_api.dart` | Retrofit 接口定义，只描述 HTTP 形状 | 不做错误映射，不碰缓存 |
| `{feature}_service.dart` | 业务实现：调用 API、映射错误、读写缓存 | 返回 `Result<T, Failure>` |
| `{feature}_repository.dart` | 抽象接口 | **按需**：有真实多实现需求（mock / 线上切换）才写 |
| `{feature}_dao.dart` | Drift 查询 | 只碰行类 `DbArticle`，行↔模型转换留在 Service；**用 `@DriftAccessor`** 声明要访问的表（表与数据库同包，见 [database-guidelines.md](./database-guidelines.md)） |
| `{feature}_providers.dart` | provider 装配 | 只提供依赖，不含业务逻辑 |
| `models/` | `@freezed` 数据模型 | 见 [../frontend/type-safety.md](../frontend/type-safety.md) |

Repository 接口与 Service 实现并存时，用例见 `lib/features/sample/`（完整范例：API + DAO + Service + Repository + Notifier + 页面）。

---

## Generated Code

- `.g.dart` / `.freezed.dart` / `.gr.dart` 与源文件同目录，**never edited manually**；`@riverpod` 也生成 `.g.dart`（provider 声明本身）—— 改过注解或增删 provider 后跑 `just codegen`
- 本项目**没有** `*.config.dart`：不使用 `injectable`，没有 service locator 生成物
