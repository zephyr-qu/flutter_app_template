# Frontend Development Guidelines

> 页面、状态、组件、类型安全与文案的约定。

---

## Guidelines Index

| Guide | 内容 |
| ------- | ------------- |
| [Directory Structure](./directory-structure.md) | FSD 简化版布局（**canonical**）与命名约定 |
| [State Management](./state-management.md) | Riverpod provider、`AsyncView`、生命周期、Consumer 与页面写法 |
| [Component Guidelines](./component-guidelines.md) | 页面结构、主题层、共享组件、三态渲染 |
| [Type Safety](./type-safety.md) | sealed `Result` / `Failure`、`@freezed` 模型、实际启用的 lint |
| [Localization](./localization.md) | 单语言约定、文案写在哪、要加 l10n 时怎么做 |
| [Quality Guidelines](./quality-guidelines.md) | UI 层的禁止模式、Required Patterns、错误处理层级 |

---

## 跨层与门禁

不属于单一层的约定在 [Cross-Cutting Concerns](../cross-cutting.md)：架构边界检查、覆盖率门禁、依赖声明检查、代码生成与生成物（提交策略、重新生成时机、CI 漂移检查）、`leak_tracker`、集成测试、环境配置与 release 构建。

---

## 相关目录

- 数据层与网络 / 错误：[`../backend/`](../backend/index.md)
- 通用思考方法：[`../guides/`](../guides/index.md)
- 一次任务的工作流：[`../../workflow.md`](../../workflow.md)

---

## 写文档时的约定

语言政策、spec 引用写法、快照标注、以及 spec 该怎么写，统一记在 [../guides/comment-guidelines.md](../guides/comment-guidelines.md) —— 本文件不重复。
