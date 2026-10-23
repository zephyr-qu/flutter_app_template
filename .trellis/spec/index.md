# Spec 索引

> 总入口：本文件只列入口与共享约定，每层细则见各自目录下的 `.md`。

---

## 开工前必读

按你要动的东西选：

- [ ] 写页面 / provider / Notifier，或动 `core/` 的状态适配层 → [ui/state-management.md](./ui/state-management.md)
- [ ] 新增或改动 UI、组件、主题 → [ui/component-guidelines.md](./ui/component-guidelines.md)、[ui/quality-guidelines.md](./ui/quality-guidelines.md)
- [ ] 动路由 / 导航（router、初始路由、底部导航标签）→ [ui/routing.md](./ui/routing.md)
- [ ] 新建 feature、增删文件、判断某文件该放哪 → [directory-structure.md](./directory-structure.md)
- [ ] 动数据层（API / Service / DAO / Repository / 模型）→ [data/database-guidelines.md](./data/database-guidelines.md)、[data/network-guidelines.md](./data/network-guidelines.md)、[data/error-handling.md](./data/error-handling.md)
- [ ] 动门禁、codegen、集成测试、环境配置，或判断某写法算不算违规 → [cross-cutting.md](./cross-cutting.md)
- [ ] 动手前先把思路铺开（跨层 / 重复 / 注释）→ [guides/index.md](./guides/index.md)

## 完成前自检

- [ ] `just verify` 全绿（清单与先后顺序见根 `justfile`）
- [ ] 涉及注解（`@freezed` / `@RoutePage` / `@riverpod` / Drift 表）或增删文件 → 已跑 `just codegen`
- [ ] 架构边界没破（`core/` 不引上层、跨 feature 只共享 `data/` 或对方 `api.dart` 出口、`logic/` 不碰 material、`api.dart` 不漏 `page/`）
- [ ] 新增 `FailureCode` 已补 `localizedMessage()` 的文案，`test/core/ui/failure_message_test.dart` 能覆盖到
- [ ] 增删了 `lib/` 文件 → 同步了 [README](../../README.md) 与 [directory-structure.md](./directory-structure.md) 的目录树（**无门禁核对**，靠人）
- [ ] 改动触到 spec 描述的约定 → 同步更新对应 `.md`

---

## 工程结构

| Guide | 内容 |
| ------- | ------------- |
| [Directory Structure](./directory-structure.md) | FSD 简化版布局（**canonical**）、命名约定与数据层文件角色 |

## UI

| Guide | 内容 |
| ------- | ------------- |
| [State Management](./ui/state-management.md) | Riverpod provider、`AsyncView`、生命周期、Consumer 与页面写法 |
| [Component Guidelines](./ui/component-guidelines.md) | 页面结构、主题层、共享组件 |
| [Type Safety](./type-safety.md) | sealed `Result` / `Failure`、`@freezed` 模型、实际启用的 lint |
| [Localization](./ui/localization.md) | 单语言约定、文案写在哪、要加 l10n 时怎么做 |
| [Routing & Navigation](./ui/routing.md) | 路由器生命周期、初始 location、主框架标签、底部导航改动的测试同步 |
| [Quality Guidelines](./ui/quality-guidelines.md) | UI 层的禁止模式、Required Patterns、错误处理层级 |

## 数据层（`features/*/data/`、`features/*/logic/`）

| Guide | 内容 |
| ------- | ------------- |
| [Database Guidelines](./data/database-guidelines.md) | SharedPreferences / Drift / FileStorage |
| [Network Guidelines](./data/network-guidelines.md) | Dio 装配、拦截器顺序、Mock、配置 |
| [Error Handling](./data/error-handling.md) | `Result` / `Failure`、状态码映射、`localizedMessage` |
| [Quality Guidelines](./data/quality-guidelines.md) | 数据/逻辑层的禁止模式、Required Patterns、Code Review 清单 |
| [Logging Guidelines](./data/logging-guidelines.md) | `Logging` 门面、日志级别、什么不该记 |

---

## 相关文档

- 跨层与门禁（架构边界、依赖声明、codegen 与生成物、`leak_tracker`、集成测试、环境配置）：[`./cross-cutting.md`](./cross-cutting.md)
- 通用思考方法与写文档的约定（语言政策、spec 引用写法、快照标注）：[`./guides/index.md`](./guides/index.md)、[`./guides/comment-guidelines.md`](./guides/comment-guidelines.md)
- 一次任务的工作流：[`../workflow.md`](../workflow.md)
