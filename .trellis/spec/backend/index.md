# Backend Development Guidelines

> 数据层（`features/*/data/`）与逻辑层（`features/*/logic/`）的约定：存储、网络、错误处理、日志。

---

## Guidelines Index

| Guide | 内容 |
| ------- | ------------- |
| [Directory Structure](./directory-structure.md) | 数据层的文件与类名约定 |
| [Database Guidelines](./database-guidelines.md) | SharedPreferences / 安全存储 / Drift / FileStorage |
| [Network Guidelines](./network-guidelines.md) | Dio 装配、拦截器顺序、Mock、配置 |
| [Error Handling](./error-handling.md) | `Result` / `Failure`、401 与令牌刷新、登出语义 |
| [Quality Guidelines](./quality-guidelines.md) | 数据/逻辑层的禁止模式、Required Patterns、Code Review 清单 |
| [Logging Guidelines](./logging-guidelines.md) | `Logging` 门面、日志级别、什么不该记 |

---

## 跨层与门禁

不属于单一层的约定在 [Cross-Cutting Concerns](../cross-cutting.md)：架构边界检查、覆盖率门禁、依赖声明检查、`leak_tracker`、集成测试、环境配置与 release 构建。

---

## 相关目录

- 页面 / 状态 / 组件 / 类型安全：[`../frontend/`](../frontend/index.md)
- 通用思考方法：[`../guides/`](../guides/index.md)
- 一次任务的工作流：[`../../workflow.md`](../../workflow.md)

---

## 写文档时的约定

语言政策、spec 引用写法、快照标注、以及 spec 该怎么写，统一记在 [../guides/comment-guidelines.md](../guides/comment-guidelines.md) —— 本文件不重复。
