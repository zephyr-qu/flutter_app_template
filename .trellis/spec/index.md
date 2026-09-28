# Spec 索引

> 分层规范总入口。每层的细则在其目录下的 `.md` 文件里；本文件只列入口与共享约定。

---

## 开工前必读

按你要动的东西选：

- [ ] 写页面 / provider / Notifier，或动 `core/` 的状态适配层 → [frontend/state-management.md](./frontend/state-management.md)
- [ ] 新增或改动 UI、组件、主题 → [frontend/component-guidelines.md](./frontend/component-guidelines.md)、[frontend/quality-guidelines.md](./frontend/quality-guidelines.md)
- [ ] 新建 feature、增删文件、判断某文件该放哪 → [frontend/directory-structure.md](./frontend/directory-structure.md)
- [ ] 动数据层（API / Service / DAO / Repository / 模型）→ [backend/database-guidelines.md](./backend/database-guidelines.md)、[backend/network-guidelines.md](./backend/network-guidelines.md)、[backend/error-handling.md](./backend/error-handling.md)
- [ ] 动门禁、codegen、集成测试、环境配置，或判断某写法算不算违规 → [cross-cutting.md](./cross-cutting.md)
- [ ] 动手前先把思路铺开（跨层 / 重复 / 注释）→ [guides/index.md](./guides/index.md)

## 完成前自检

- [ ] `just verify` 全绿（清单与先后顺序见根 `justfile`）
- [ ] 涉及注解（`@freezed` / `@RoutePage` / `@riverpod` / Drift 表）或增删文件 → 已跑 `just codegen`
- [ ] 架构边界没破（`core/` 不引上层、跨 feature 只共享 `data/`、`logic/` 不碰 material）
- [ ] 新增 `FailureCode` 已补 `localizedMessage()` 的文案，`test/core/ui/failure_message_test.dart` 能覆盖到
- [ ] 增删了 `lib/` 文件 → 同步了 [README](../../README.md) 与 [frontend/directory-structure.md](./frontend/directory-structure.md) 的目录树（**无门禁核对**，靠人）
- [ ] 改动触到 spec 描述的约定 → 同步更新对应 `.md`

---

## Frontend（页面 / 状态 / 组件 / 类型安全 / 文案）

| Guide | 内容 |
| ------- | ------------- |
| [Directory Structure](./frontend/directory-structure.md) | FSD 简化版布局（**canonical**）、命名约定与数据层文件角色 |
| [State Management](./frontend/state-management.md) | Riverpod provider、`AsyncView`、生命周期、Consumer 与页面写法 |
| [Component Guidelines](./frontend/component-guidelines.md) | 页面结构、主题层、共享组件 |
| [Type Safety](./frontend/type-safety.md) | sealed `Result` / `Failure`、`@freezed` 模型、实际启用的 lint |
| [Localization](./frontend/localization.md) | 单语言约定、文案写在哪、要加 l10n 时怎么做 |
| [Quality Guidelines](./frontend/quality-guidelines.md) | UI 层的禁止模式、Required Patterns、错误处理层级 |

## Backend（数据层 `features/*/data/` / 逻辑层 `features/*/logic/`）

| Guide | 内容 |
| ------- | ------------- |
| [Database Guidelines](./backend/database-guidelines.md) | SharedPreferences / Drift / FileStorage |
| [Network Guidelines](./backend/network-guidelines.md) | Dio 装配、拦截器顺序、Mock、配置 |
| [Error Handling](./backend/error-handling.md) | `Result` / `Failure`、状态码映射、`localizedMessage` |
| [Quality Guidelines](./backend/quality-guidelines.md) | 数据/逻辑层的禁止模式、Required Patterns、Code Review 清单 |
| [Logging Guidelines](./backend/logging-guidelines.md) | `Logging` 门面、日志级别、什么不该记 |

---

## 相关文档

- 跨层与门禁（架构边界、依赖声明、codegen 与生成物、`leak_tracker`、集成测试、环境配置）：[`./cross-cutting.md`](./cross-cutting.md)
- 通用思考方法与写文档的约定（语言政策、spec 引用写法、快照标注）：[`./guides/index.md`](./guides/index.md)、[`./guides/comment-guidelines.md`](./guides/comment-guidelines.md)
- 一次任务的工作流：[`../workflow.md`](../workflow.md)
