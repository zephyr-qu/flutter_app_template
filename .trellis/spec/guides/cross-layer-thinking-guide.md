# 跨层思考指南

> **目的**：动手前先想清数据怎么跨层流动。

---

## 本项目有哪些层

层边界是 bug 的高发区。本项目的层（权威布局见 [../frontend/directory-structure.md](../frontend/directory-structure.md)）：

```
Page → Notifier → Repository (接口) → Service → Api (Retrofit) → Dio
                                      ↓ DAO / Drift（本地缓存）
```

---

## 动手前的三步

### 第 1 步：画数据流

画出数据怎么走：

```
API JSON → 模型(@freezed) → 业务逻辑 → drift 行类 ↔ 模型 → UI
```

对每个箭头问：这里的数据是什么类型（`Map<String, dynamic>` / `SampleItem` / `DbArticle`）？哪里可能出错？谁负责校验与转换？

### 第 2 步：找出边界

| 边界 | 常见问题 |
| --- | --- |
| API ↔ Service | 字段漏映射、可空性假设不一致 |
| Service ↔ DAO | 模型 ↔ drift 行类转换、`null` 处理 |
| core ↔ feature | 依赖方向搞反（`core` 不能 import feature，`packages/app_lints` 插件会拦） |
| Notifier ↔ Page | 状态类型（`AsyncValue`）与渲染分支不匹配（一律走 `AsyncView`） |

### 第 3 步：定契约

对每个边界明确：输入的确切类型（含可空性）、输出的确切类型、可能产生哪些失败。本项目已有的两个契约范例：`core/base/result.dart`（所有会失败的操作都返回 `Result`）与 `core/base/failure.dart` 的 `handleDioError()`（`DioException` 只在这里映射一次）。

---

## 常见跨层错误

### 错误 1：默认格式假设

**反例**：假定后端一定返回某个字段，不做空值处理 → **正例**：在边界处显式转换；模型字段要么 `required`，要么显式可空

### 错误 2：校验散落各处

**反例**：同一件事在 Notifier 和 Service 各校验一遍 → **正例**：入口处校验一次 —— 简单字段校验做成状态快照上的 getter（`canSubmit` 这种），复杂规则交给后端

### 错误 3：抽象泄漏

**反例**：让 `SampleItem` 模型知道 drift 的存在（例如给它加 `SampleItem.fromRow(DbArticle)`） → **正例**：模型不碰基础设施；行↔模型互转留在消费方（`SampleService` 的私有方法）。见 [../backend/database-guidelines.md](../backend/database-guidelines.md)「命名约定」。

### 错误 4：同一个错误在多层各映射一次

**反例**：每个 Service 各自把 `DioException` 转成 `Failure`，于是同一类超时在不同接口下错误码不同 → **正例**：`DioException → Failure` 只在 `handleDioError()` 一处发生（见 [../backend/error-handling.md](../backend/error-handling.md)）

---

## 跨层功能清单

动手前：

- [ ] 画完整条数据流
- [ ] 找出所有层边界
- [ ] 明确了每个边界的类型与可空性
- [ ] 定下校验发生在哪一层
- [ ] 确认没有违反依赖方向（`app → features → core`）

动手后：

- [ ] 用边界情况测过（null、空、非法值）
- [ ] 每个边界的错误处理都核过
- [ ] 数据能完整走一圈（网络 → 缓存 → 界面）
- [ ] 新增的 `FailureCode` 已在 `localizedMessage()` 的 `switch` 里补中文文案

---

## 什么时候写流程图文档

什么时候要写流程图文档：feature 跨 3+ 层、数据格式复杂、这个 feature 出过 bug。跨层链路若已在 `.trellis/spec/` 里写过，**不要另开文档**。代码里用注释指向 spec 即可，写法见 [./comment-guidelines.md](./comment-guidelines.md)。
