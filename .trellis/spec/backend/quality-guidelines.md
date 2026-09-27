# 质量规范：数据与逻辑层

> 数据层与逻辑层的代码质量标准。

---

## 概览

本文件适用于 `lib/core/`（共享基础设施）、`lib/features/*/data/`（API、service、repository、models）与 `lib/features/*/logic/`（Notifier：状态 + 业务编排）。

**架构边界**（`core/` 不得 import/export 上层、跨 feature 只共享 `data/`、`logic/` 不得 import/export `package:flutter/material.dart`）以及所有门禁、测试基建与发布的约定，见 [../cross-cutting.md](../cross-cutting.md) —— 本文件不重复。

---

## 禁止模式

❌ **这些写法一律不要用**：

1. **公开 API 裸 `try/catch`、不给 `Result` 类型** — 所有可能失败的 repository / service 方法必须返回 `Result<T, Failure>`

   ```dart
   Future<List<SampleItem>> getItems() async { ... }                            // 反例
   Future<Result<List<SampleItem>, Failure>> getItems() async { ... }            // 正例
   ```

2. **生产代码里的 `print()`** — 用 `Logging` 门面（`Logging.info/debug/warning/error`）。（`avoid_print` 目前没在 `analysis_options.yaml` 里启用；这条是 review 约定，不是 lint error。）

3. **把裸 `DioException` 传到 Notifier** — 在 Service 层转成带类型的 `Failure`

   ```dart
   throw e;                                        // 反例 —— 让 DioException 逃出去
   return Result.failure(handleDioError(e));        // 正例
   ```

4. **feature 之间循环 import** — 一个 feature 永不 import 另一个 feature 的 `page/` 或 `logic/`

   ```dart
   // 反例 —— profile 伸手进 sample 的 UI / logic
   import 'package:my_app/features/sample/page/sample_list_page.dart';
   ```

5. **数据层里写业务逻辑** — 业务规则的**判断**（分支、阈值、策略）放 `logic/`；Service 只做转换与 I/O：调 API、读写缓存、把 `DioException` 映射成 `Failure`

6. **生产代码里用 `getOrThrow`** — 只给测试；穷尽匹配用 `when()`

---

## 必须遵守

✅ **这些写法一律照做**：

1. repository 接口与 service 实现里所有可能失败的操作都返回 **`Result<T, Failure>`**

2. **Service 与第三方 / API 依赖的绑定都在 provider 里** —— `{feature}_providers.dart` 让 provider 返回抽象类型：

   ```dart
   // features/sample/data/sample_providers.dart
   @Riverpod(keepAlive: true)
   SampleRepository sampleRepository(Ref ref) =>
       SampleService(ref.watch(sampleApiProvider), ref.watch(sampleDaoProvider));

   @Riverpod(keepAlive: true)
   SampleApi sampleApi(Ref ref) => SampleApi(ref.watch(dioProvider));
   ```

   （provider 本身就是注册表，见 [frontend/state-management.md](../frontend/state-management.md)「三种 Provider 形态」。）

3. **Repository 抽象按需** — 只有真有「多实现需求」（mock / 线上切换）才写 `{Feature}Repository`；简单 feature 直接调 Service。两者都存在时，接口是 `{feature}_repository.dart`、实现是 `{feature}_service.dart`，都放在该 feature 的 `data/` 层（没有 `domain/` 层）。

4. **sealed 的 `Failure` 子类**：直接实例化子类并给出 `FailureCode`（`const NetworkFailure(code: FailureCode.timeout)`）。`Failure` 不携带用户可见文案——文案由展示层翻译，见 [error-handling.md](./error-handling.md)

5. **私有字段加 `_` 前缀**

6. **公开 API 写文档注释**：repository / service 方法上加 `///`，说明它做什么、返回哪些 `Result` 变体

7. **模型**：用 `@freezed` 注解（值语义、`copyWith`、生成 `fromJson` / `toJson`）。脚手架里所有模型都是 freezed（`SampleItem` 是现存唯一一个）。**不要手改**生成的 `*.g.dart` / `*.freezed.dart`

---

## 测试要求

- **必须写单测的地方**：Notifier 的状态迁移（loading → data、loading → error）、Failure 路径（`Result.failure()` 打桩）、非平凡的 Repository / Service 错误映射
- **测试文件位置**：`test/features/{feature}/`
- **测试库**：`flutter_test`、`mocktail`；provider 测试用 `ProviderContainer` + `overrides`（模板：`test/features/sample/logic/sample_list_notifier_test.dart`）

---

## Code Review 清单

- [ ] 方法返回 `Result<T, Failure>` 而不是抛异常？
- [ ] 所有 `DioException` 都捕到并用 `handleDioError()` 转换了？
- [ ] `catch` 顺序对吗？（具体 → 通用）
- [ ] provider 装配对不对？（无状态服务带 `@Riverpod(keepAlive: true)`，provider 返回抽象类型）
- [ ] Notifier 的依赖从 `ref` 取（而不是自己 new 或建容器）？
- [ ] 改过模型 / 注解后重新生成了 `*.g.dart`？
- [ ] 没有 import 别的 feature 的 `page/` 或 `logic/`？
- [ ] Notifier 自己不做业务 I/O（都交给 Service / Repository）？
- [ ] 生产路径里没有调试打印？
