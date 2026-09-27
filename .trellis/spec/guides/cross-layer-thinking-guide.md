# Cross-Layer Thinking Guide

> **Purpose**: Think through data flow across layers before implementing.

---

## The Problem

**Most bugs happen at layer boundaries**, not within layers.

本项目的层（权威布局见 [../frontend/directory-structure.md](../frontend/directory-structure.md)）：

```
Page → ViewModel → Repository (接口) → Service → Api (Retrofit) → Dio
                                        ↓
                                    DAO / Drift（本地缓存）
```

典型跨层 bug：

- API 返回一种形状，Service 按另一种假设解析
- 缓存与网络两条路各写一遍转换，字段加一个漏一个
- 同一个错误在不同层被映射成不同的 `Failure`，错误码在传递中丢掉

---

## Before Implementing Cross-Layer Features

### Step 1: Map the Data Flow

画出数据怎么走：

```
API JSON → 模型(@freezed) → 业务逻辑 → drift 行类 ↔ 模型 → UI
```

对每个箭头问：

- 数据在这里是什么类型？（`Map<String, dynamic>` / `Article` / `DbArticle`）
- 哪里可能出错？
- 谁负责校验与转换？

### Step 2: Identify Boundaries

| 边界 | 常见问题 |
| --- | --- |
| API ↔ Service | 字段漏映射、可空性假设不一致 |
| Service ↔ DAO | 模型 ↔ drift 行类转换、`null` 处理 |
| core ↔ feature | 依赖方向搞反（`core` 不能 import feature，`no_upper_import_in_core` 会拦） |
| ViewModel ↔ Page | 状态类型（`AsyncState`）与渲染分支不匹配 |

### Step 3: Define Contracts

对每个边界明确：

- 输入的确切类型（含可空性）
- 输出的确切类型
- 可能产生哪些失败

本项目已有的两个契约范例：`core/base/result.dart`（所有会失败的操作都返回 `Result`）与 `core/base/failure.dart` 的 `handleDioError()`（`DioException` 只在这里映射一次）。

---

## Common Cross-Layer Mistakes

### Mistake 1: Implicit Format Assumptions

**Bad**：假定后端一定返回某个字段，不做空值处理

**Good**：在边界处显式转换；模型字段要么 `required`，要么显式可空

### Mistake 2: Scattered Validation

**Bad**：同一件事在 ViewModel 和 Service 各校验一遍

**Good**：入口处校验一次 —— 简单字段校验放 ViewModel 的 computed getter，复杂规则交给后端

### Mistake 3: Leaky Abstractions

**Bad**：让 `Article` 模型知道 drift 的存在（例如给它加 `Article.fromRow(DbArticle)`）

**Good**：模型不碰基础设施；行↔模型互转留在消费方（`ArticleService` 的私有方法）。理由见 [../backend/database-guidelines.md](../backend/database-guidelines.md)「命名规范」一节

### Mistake 4: 同一个错误在多层各映射一次

**Bad**：每个 Service 各自把 `DioException` 转成 `Failure`，于是同一类超时在不同接口下错误码不同

**Good**：`DioException → Failure` 只在 `handleDioError()` 一处发生（见 [../backend/error-handling.md](../backend/error-handling.md)）

---

## Checklist for Cross-Layer Features

Before implementation:

- [ ] Mapped the complete data flow
- [ ] Identified all layer boundaries
- [ ] 明确了每个边界的类型与可空性
- [ ] Decided where validation happens
- [ ] 确认没有违反依赖方向（`app → features → core`）

After implementation:

- [ ] Tested with edge cases (null, empty, invalid)
- [ ] Verified error handling at each boundary
- [ ] Checked data survives round-trip（网络 → 缓存 → 界面）
- [ ] 新增的 `FailureCode` 已补 ARB 文案（`localizedMessage` 的 `switch` 会编译报错提醒你）

---

## When to Create Flow Documentation

Create detailed flow docs when:

- Feature spans 3+ layers
- Data format is complex
- Feature has caused bugs before

跨层链路若已在 `.trellis/spec/` 里写过，**不要另开文档** —— 两处维护一定会漂。代码里用注释指向 spec 即可，写法见 [./comment-guidelines.md](./comment-guidelines.md)。
