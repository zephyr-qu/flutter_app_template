# Frontend Development Guidelines

> 页面、状态、组件、类型安全与本地化的约定。

---

## Guidelines Index

| Guide | 内容 |
| ------- | ------------- |
| [Directory Structure](./directory-structure.md) | FSD 简化版布局（**canonical**）与命名约定 |
| [State Management](./state-management.md) | Signals + ViewModel、`runAsync`、`dispose` 边界 |
| [Component Guidelines](./component-guidelines.md) | 页面结构、主题层、共享组件、三态渲染 |
| [Hook Guidelines](./hook-guidelines.md) | `flutter_hooks` / `signals_hooks` 用法 |
| [Type Safety](./type-safety.md) | sealed `Result` / `Failure`、`@freezed` 模型、实际启用的 lint |
| [Localization](./localization.md) | l10n 配置、文案写法、语言设置 |
| [Quality Guidelines](./quality-guidelines.md) | UI 层的禁止模式、Required Patterns、错误处理层级 |

---

## 跨层与门禁

不属于单一层的约定在 [Cross-Cutting Concerns](../cross-cutting.md)：架构边界与代码形态（`packages/app_lints` 分析插件）、覆盖率（不设门禁）、依赖声明（`depend_on_referenced_packages`）、代码生成与生成物（生成物不入库、重新生成时机、CI 现场生成）、`leak_tracker`、集成测试、环境配置与 release 构建。

---

## 相关目录

- 数据层与网络 / 错误：[`../backend/`](../backend/index.md)
- 通用思考方法：[`../guides/`](../guides/index.md)
- 一次任务的工作流：[`../../workflow.md`](../../workflow.md)

---

## 写文档时的约定

语言政策、spec 引用写法、快照标注、以及 spec 该怎么写，统一记在 [../guides/comment-guidelines.md](../guides/comment-guidelines.md) —— 本文件不重复。
